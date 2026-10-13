import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';

import 'package:sdahymnal/models/hymn_ref.dart';
import 'package:sdahymnal/models/service_playlist.dart';
import 'hymn_text_export.dart';
import 'hymnal_repository.dart';

class PresentationSlide {
  const PresentationSlide(
      {required this.occurrenceId,
      required this.ref,
      required this.title,
      required this.bookLabel,
      required this.text,
      this.role});
  final String occurrenceId;
  final HymnRef ref;
  final String title;
  final String bookLabel;
  final String text;
  final String? role;
}

/// One whole stanza, refrain or reading segment of a service occurrence.
/// Presentation programs page stanzas themselves, so exports keep them whole.
class PresentationStanza {
  const PresentationStanza(
      {required this.occurrenceId,
      required this.title,
      required this.text,
      this.verse,
      this.refrain = false,
      this.role});
  final String occurrenceId;
  final String title;

  /// Lyrics without the printed verse number or refrain label line.
  final String text;
  final int? verse;
  final bool refrain;
  final String? role;
}

/// A source-order snapshot, with repeated service entries kept as occurrences.
class ServicePresentation {
  ServicePresentation._(this.name, Iterable<PresentationSlide> slides,
      [Iterable<PresentationStanza> stanzas = const []])
      : slides = List.unmodifiable(slides),
        stanzas = List.unmodifiable(stanzas);
  final String name;
  final List<PresentationSlide> slides;
  final List<PresentationStanza> stanzas;

  factory ServicePresentation.build(
      ServicePlaylist service, HymnalRepository repository,
      {int linesPerSlide = 6}) {
    if (linesPerSlide < 1 || linesPerSlide > 20) {
      throw ArgumentError.value(linesPerSlide, 'linesPerSlide');
    }
    final slides = <PresentationSlide>[];
    final stanzas = <PresentationStanza>[];
    for (final entry in service.entries) {
      final hymn = repository.hymn(entry.ref);
      final reading = repository.reading(entry.ref);
      if (hymn == null && reading == null) {
        throw FormatException('Unavailable service entry: ${entry.id}');
      }
      final title = hymn == null
          ? '${reading!.number} · ${reading.title}'
          : '${hymn.number} · ${hymn.title}';
      final book = repository.edition(entry.ref.bookId)!.displayName;
      if (hymn != null) {
        for (final section in HymnTextExport(hymn).sections) {
          final lines = section.text.trim().split('\n');
          // Section text repeats its printed label as the first line.
          final labelled = !section.generatedLabel && lines.length > 1;
          final text = (labelled ? lines.skip(1) : lines).join('\n').trim();
          if (text.isEmpty) continue;
          stanzas.add(PresentationStanza(
              occurrenceId: entry.id,
              title: title,
              text: text,
              verse: section.verseNumber == null
                  ? null
                  : int.tryParse(
                      section.verseNumber!.replaceAll(RegExp(r'[^0-9]'), '')),
              refrain: !section.generatedLabel && section.verseNumber == null));
        }
      } else {
        for (final segment in reading!.segments) {
          if (segment.text.trim().isEmpty) continue;
          stanzas.add(PresentationStanza(
              occurrenceId: entry.id,
              title: title,
              text: segment.text.trim(),
              role: segment.role));
        }
      }
      final blocks = hymn != null
          ? HymnTextExport(hymn)
              .sections
              .map((s) => (
                    text: s.text,
                    role: null as String?,
                    labelled: !s.generatedLabel
                  ))
              .toList()
          : reading!.segments
              .map((s) =>
                  (text: s.text, role: s.role as String?, labelled: false))
              .toList();
      final before = slides.length;
      for (final block in blocks) {
        final text = block.text.trim();
        if (text.isEmpty) {
          throw FormatException('Empty service block: ${entry.id}');
        }
        final lines = text.split('\n');
        // A printed verse number or refrain name rides with the first lines
        // and never counts toward the limit. Long blocks divide evenly, so a
        // slide is never left holding one orphaned line.
        final label = block.labelled && lines.length > 1 ? lines.first : null;
        final body = label == null ? lines : lines.sublist(1);
        final pieces = (body.length / linesPerSlide).ceil();
        final size = (body.length / pieces).ceil();
        for (var start = 0; start < body.length; start += size) {
          final end = (start + size).clamp(0, body.length);
          slides.add(PresentationSlide(
              occurrenceId: entry.id,
              ref: entry.ref,
              title: title,
              bookLabel: book,
              text: [
                if (start == 0 && label != null) label,
                ...body.sublist(start, end)
              ].join('\n'),
              role: block.role));
        }
      }
      if (slides.length == before) {
        throw FormatException('Empty service entry: ${entry.id}');
      }
    }
    if (slides.isEmpty) {
      throw const FormatException('Empty service presentation');
    }
    return ServicePresentation._(service.name, slides, stanzas);
  }

  /// A VideoPsalm songbook package (`.vpc`): a zip holding one songbook in
  /// the unquoted-key notation VideoPsalm writes when it exports songbooks
  /// (checked against a published `.vpc` from rejnac/chichewa-hymnal at
  /// 690b953). Each service occurrence becomes a song in service order;
  /// numbered stanzas keep their verse ID and refrains carry VideoPsalm's
  /// chorus tag (Tag 1, ID 0). Reading roles prefix their segment.
  List<int> videoPsalmPackage({String Function(String)? roleLabel}) {
    String guid(String identity) => base64
        .encode(sha256.convert(utf8.encode(identity)).bytes.take(16).toList())
        .replaceAll('=', '');
    final order = <String>[];
    for (final stanza in stanzas) {
      if (!order.contains(stanza.occurrenceId)) order.add(stanza.occurrenceId);
    }
    final identity = jsonEncode([name, ...order]);
    final songbook = <String, Object>{
      'Abbreviation': 'SDA',
      'Description': name,
      'Songs': [
        for (final (index, occurrence) in order.indexed)
          {
            'ID': index + 1,
            'Guid': guid('sdahymnal:vpc-song:$identity:$occurrence'),
            'Verses': [
              for (final stanza
                  in stanzas.where((s) => s.occurrenceId == occurrence))
                {
                  if (stanza.refrain) 'Tag': 1,
                  if (stanza.refrain) 'ID': 0,
                  if (!stanza.refrain && stanza.verse != null)
                    'ID': stanza.verse!,
                  'Text': stanza.role == null
                      ? stanza.text
                      : '${roleLabel?.call(stanza.role!) ?? stanza.role!}\n${stanza.text}',
                }
            ],
            'Text':
                stanzas.firstWhere((s) => s.occurrenceId == occurrence).title,
          }
      ],
      'Guid': guid('sdahymnal:vpc-songbook:$identity'),
      'Text': name,
    };
    final bytes = utf8.encode(videoPsalmNotation(songbook));
    final archive = Archive()
      ..addFile(
          ArchiveFile('${exportFileStem(name)}.json', bytes.length, bytes));
    return ZipEncoder().encode(archive);
  }

  /// VideoPsalm songbook JSON. This is not a native service agenda file.
  /// Each service occurrence gets a distinct song, retaining the chosen order.
  String videoPsalmSongbook({String Function(String)? roleLabel}) {
    String guid(String identity) => base64
        .encode(sha256.convert(utf8.encode(identity)).bytes.take(16).toList())
        .replaceAll('=', '');
    final occurrences = <String, List<PresentationSlide>>{};
    for (final slide in slides) {
      occurrences.putIfAbsent(slide.occurrenceId, () => []).add(slide);
    }
    // Keep exported identities separate from installed/source songbook GUIDs.
    final identity = jsonEncode([
      name,
      for (final group in occurrences.values)
        [
          group.first.occurrenceId,
          group.first.ref.bookId,
          group.first.ref.itemId
        ]
    ]);
    return const JsonEncoder.withIndent('  ').convert({
      'Text': name,
      'Abbreviation': 'SDA',
      'Guid': guid('sdahymnal:service-songbook:$identity'),
      'Songs': [
        for (final entry in occurrences.entries)
          {
            'ID': occurrences.keys.toList().indexOf(entry.key) + 1,
            'Guid': guid('sdahymnal:service-song:$identity:${entry.key}'),
            'Text': entry.value.first.title,
            'Verses': [
              for (final slide in entry.value)
                {
                  'Text': slide.role == null
                      ? slide.text
                      : '${roleLabel?.call(slide.role!) ?? slide.role!}\n${slide.text}',
                }
            ],
          }
      ],
    });
  }

  /// Experimental `.vpagd` container, pending native VideoPsalm validation.
  /// Anchor entries are inserted in service order, never sorted by hymn number.
  List<int> videoPsalmAgenda({String Function(String)? roleLabel}) {
    final book = jsonDecode(videoPsalmSongbook(roleLabel: roleLabel))
        as Map<String, dynamic>;
    final songs = book.remove('Songs') as List<dynamic>;
    final archive = Archive();
    void add(String name, Object value) {
      final bytes = utf8.encode(jsonEncode(value));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('Version.json', 2);
    for (var index = 0; index < songs.length; index++) {
      add('Song_$index.json', songs[index]);
      add('SongBook_$index.json', book);
    }
    add('AgendaItemProperties.json', {
      'Items': [
        for (var index = 0; index < songs.length; index++)
          {
            'FlowType': 0,
            'AutoAdvance': 0,
            'Interval': 5000,
            'VerseOrderIndex': -1,
            'HiddenSlides': <int>[],
          }
      ],
    });
    return ZipEncoder().encode(archive);
  }

  /// No remote fonts, media, scripts, or assets. Source text is always escaped.
  String html(
      {required String previousLabel,
      required String nextLabel,
      String Function(String)? roleLabel}) {
    const escape = HtmlEscape();
    String escaped(String text) => escape.convert(text);
    return '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escaped(name)}</title><style>
*{box-sizing:border-box}body{margin:0;background:#101510;color:#fff;font-family:system-ui,sans-serif}
.slide{display:none;height:calc(100vh - 64px);overflow:auto;padding:4vh 6vw}.slide.active{display:flex;flex-direction:column}
h1{font-size:clamp(20px,3vw,42px);margin:0 0 2vh}pre{font-family:inherit;white-space:pre-wrap;overflow-wrap:anywhere;font-size:clamp(24px,4vw,64px);line-height:1.3;margin:0;flex:1}
footer{font-size:clamp(14px,1.5vw,24px);padding-top:2vh;color:#bec9be}nav{height:64px;display:flex;align-items:center;justify-content:center;gap:20px}button{padding:10px 18px;font:inherit}button:disabled{opacity:.45}
</style></head><body>
${[
      for (var i = 0; i < slides.length; i++)
        '''<section class="slide${i == 0 ? ' active' : ''}" aria-hidden="${i != 0}"><h1>${escaped(slides[i].title)}</h1><pre>${escaped(slides[i].text)}</pre><footer>${escaped(slides[i].bookLabel)}${slides[i].role == null ? '' : ' · ${escaped(roleLabel?.call(slides[i].role!) ?? slides[i].role!)}'}</footer></section>'''
    ].join('\n')}
<nav><button id="previous">${escaped(previousLabel)}</button><span id="position" aria-live="polite"></span><button id="next">${escaped(nextLabel)}</button></nav>
<script>
const slides=Array.from(document.querySelectorAll('.slide'));let index=0;
const previous=document.getElementById('previous'),next=document.getElementById('next');
function show(value){index=Math.max(0,Math.min(slides.length-1,value));slides.forEach((s,i)=>{s.classList.toggle('active',i===index);s.setAttribute('aria-hidden',i!==index);});previous.disabled=index===0;next.disabled=index===slides.length-1;document.getElementById('position').textContent=(index+1)+' / '+slides.length;}
previous.onclick=()=>show(index-1);next.onclick=()=>show(index+1);
document.addEventListener('keydown',e=>{if(e.key==='ArrowRight'||e.key==='PageDown'){e.preventDefault();show(index+1);}if(e.key==='ArrowLeft'||e.key==='PageUp'){e.preventDefault();show(index-1);}});show(0);
</script></body></html>''';
  }
}

/// A file name stem without separators or reserved characters.
String exportFileStem(String name) {
  final stem = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return stem.isEmpty ? 'service' : stem;
}

/// VideoPsalm's object notation: JSON values with unquoted member names.
String videoPsalmNotation(Object? value) {
  if (value is Map) {
    return '{${value.entries.map((e) {
      final key = e.key as String;
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
        throw ArgumentError.value(key, 'key');
      }
      return '$key:${videoPsalmNotation(e.value)}';
    }).join(',')}}';
  }
  if (value is List) return '[${value.map(videoPsalmNotation).join(',')}]';
  return jsonEncode(value);
}
