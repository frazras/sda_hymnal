import 'dart:convert';

import 'package:crypto/crypto.dart';

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

/// A source-order snapshot, with repeated service entries kept as occurrences.
class ServicePresentation {
  ServicePresentation._(this.name, Iterable<PresentationSlide> slides)
      : slides = List.unmodifiable(slides);
  final String name;
  final List<PresentationSlide> slides;

  factory ServicePresentation.build(
      ServicePlaylist service, HymnalRepository repository,
      {int linesPerSlide = 6}) {
    if (linesPerSlide < 1 || linesPerSlide > 20) {
      throw ArgumentError.value(linesPerSlide, 'linesPerSlide');
    }
    final slides = <PresentationSlide>[];
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
      final blocks = hymn != null
          ? HymnTextExport(hymn)
              .sections
              .map((s) => (text: s.text, role: null as String?))
              .toList()
          : reading!.segments
              .map((s) => (text: s.text, role: s.role as String?))
              .toList();
      final before = slides.length;
      for (final block in blocks) {
        final text = block.text.trim();
        if (text.isEmpty) {
          throw FormatException('Empty service block: ${entry.id}');
        }
        final lines = text.split('\n');
        for (var start = 0; start < lines.length; start += linesPerSlide) {
          final end = (start + linesPerSlide).clamp(0, lines.length);
          slides.add(PresentationSlide(
              occurrenceId: entry.id,
              ref: entry.ref,
              title: title,
              bookLabel: book,
              text: lines.sublist(start, end).join('\n'),
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
    return ServicePresentation._(service.name, slides);
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
