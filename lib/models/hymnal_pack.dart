import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_book.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';

bool _supportedImportedBook(String id) =>
    RegExp(r'^sda-(es|pt|ru)-\d{4}$').hasMatch(id) ||
    const {
      'sda-fr-hymnes-et-louanges',
      'sda-sw-nyimbo-za-kristo',
      'sda-ny-khristu-mu-nyimbo'
    }.contains(id);

typedef LyricBlock = ({bool refrain, String label, String text});

/// The reader's copy of an imported hymn, marked up like the English books
/// so verse numbers and refrain labels share one style. When the source
/// prints a single refrain after the first verse, it is repeated after every
/// later verse and the hymn ends on it — the order a congregation sings.
/// Source order stays untouched in the hymn body for search, share and export.
String lyricReadingHtml(
    List<LyricBlock> blocks, String Function(String) escaped) {
  final numeric = RegExp(r'^(\d+)[.)]?$');
  String render(LyricBlock block) {
    final text = escaped(block.text);
    if (block.refrain) {
      final name = block.label.replaceFirst(RegExp(r'[:：]\s*$'), '').trim();
      return name.isEmpty
          ? '<i>$text</i>'
          : '<i><b><font color="#CD9B1D">${escaped(name)}:</font></b><br>$text</i>';
    }
    final number = numeric.firstMatch(block.label)?.group(1);
    if (number != null) {
      return '<font color="#0B6138"><b>$number</b></font><br>$text';
    }
    return block.label.isEmpty
        ? text
        : '<b>${escaped(block.label)}</b><br>$text';
  }

  var order = [for (var i = 0; i < blocks.length; i++) i];
  final refrains = [
    for (var i = 0; i < blocks.length; i++)
      if (blocks[i].refrain) i
  ];
  if (refrains.length == 1 &&
      refrains.single == 1 &&
      blocks.length > 2 &&
      !blocks.first.refrain) {
    order = [0, 1];
    for (var i = 2; i < blocks.length; i++) {
      order
        ..add(i)
        ..add(1);
    }
  }
  return order.map((i) => render(blocks[i])).join('<br><br>');
}

class HymnalTopic {
  final String id;
  final String group;
  final String title;
  final List<Hymn> hymns;
  const HymnalTopic(this.id, this.group, this.title, this.hymns);
}

class HymnalPack {
  final HymnalEdition edition;
  final List<Hymn> hymns;
  final List<HymnalTopic> topics;
  const HymnalPack(this.edition, this.hymns, this.topics);

  factory HymnalPack.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Unsupported hymnal pack.');
    }
    final book = data['book'] as Map<String, dynamic>;
    final edition = HymnalEdition(
        id: book['id'] as String,
        languageTag: book['languageTag'] as String,
        displayName: book['displayName'] as String,
        year: book['year'] as int?);
    if (!_supportedImportedBook(edition.id) ||
        edition.displayName.trim().isEmpty ||
        edition.languageTag.split('-').first != edition.id.split('-')[1]) {
      throw const FormatException('Unknown imported book.');
    }
    const escape = HtmlEscape();
    String escaped(String value) =>
        escape.convert(value).replaceAll('\n', '<br>');
    final hymns = <Hymn>[];
    final byId = <String, Hymn>{};
    for (final item in data['items'] as List<dynamic>) {
      final number = item['number'] as int;
      final id = item['id'] as String;
      final title = item['title'] as String;
      if (number < 1 ||
          '$number' != id ||
          byId.containsKey(id) ||
          title.trim().isEmpty ||
          title.contains('\uFFFD')) {
        throw const FormatException('Duplicate or invalid hymn.');
      }
      final body = StringBuffer();
      final blocks = <LyricBlock>[];
      for (final block in item['blocks'] as List<dynamic>) {
        final text = block['text'] as String;
        if (text.trim().isEmpty ||
            text.contains('\uFFFD') ||
            !['verse', 'refrain'].contains(block['kind'])) {
          throw const FormatException('Invalid lyric block.');
        }
        if (body.isNotEmpty) body.write('<br><br>');
        final label = block['label'] as String?;
        if (label != null && label.isNotEmpty) {
          body.write('<b>${escaped(label)}</b><br>');
        }
        body.write(escaped(text));
        blocks.add((
          refrain: block['kind'] == 'refrain',
          label: label?.trim() ?? '',
          text: text
        ));
      }
      if (body.isEmpty) throw const FormatException('Empty hymn lyrics.');
      final hymn = Hymn(
          number: number,
          title: title,
          body: body.toString(),
          version: edition.id,
          bookTitle: editionShortLabel(edition.id, edition.displayName),
          languageTag: edition.languageTag,
          credits: item['credits'] as String?,
          readingHtml: lyricReadingHtml(blocks, escaped));
      hymns.add(hymn);
      byId[id] = hymn;
    }
    if (hymns.isEmpty) throw const FormatException('Empty hymnal pack.');
    hymns.sort((a, b) => a.number.compareTo(b.number));
    final topics = <HymnalTopic>[];
    final topicIds = <String>{};
    for (final topic in data['topics'] as List<dynamic>) {
      final id = topic['id'] as String;
      final ids = (topic['itemIds'] as List<dynamic>).cast<String>();
      if (id.trim().isEmpty ||
          (topic['group'] as String).trim().isEmpty ||
          (topic['title'] as String).trim().isEmpty ||
          !topicIds.add(id) ||
          ids.toSet().length != ids.length ||
          ids.isEmpty ||
          ids.any((id) => !byId.containsKey(id))) {
        throw const FormatException('Invalid topic references.');
      }
      topics.add(HymnalTopic(
          id,
          topic['group'] as String,
          topic['title'] as String,
          List.unmodifiable(ids.map((id) => byId[id]!))));
    }
    return HymnalPack(
        edition, List.unmodifiable(hymns), List.unmodifiable(topics));
  }
}

/// Verify bundled bytes before parsing. Optional media is never inferred from
/// the number of a hymn in a different book.
Future<List<HymnalPack>> loadHymnalPacks(AssetBundle bundle) async {
  final catalog =
      jsonDecode(await bundle.loadString('assets/hymnals/catalog.json'))
          as Map<String, dynamic>;
  if (catalog['schemaVersion'] != 1) {
    throw const FormatException('Unsupported hymnal catalog.');
  }
  final result = <HymnalPack>[];
  final ids = <String>{};
  for (final book in catalog['books'] as List<dynamic>) {
    final id = book['id'] as String;
    final asset = book['asset'] as String;
    if (!ids.add(id) ||
        !_supportedImportedBook(id) ||
        asset != 'assets/hymnals/$id.json') {
      throw const FormatException('Invalid catalog book.');
    }
    final data = await bundle.load(asset);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (bytes.length != book['bytes'] ||
        sha256.convert(bytes).toString() != book['sha256']) {
      throw const FormatException('Hymnal pack checksum mismatch.');
    }
    final pack = HymnalPack.fromJson(utf8.decode(bytes));
    if (pack.edition.id != id ||
        pack.hymns.length != book['hymnCount'] ||
        pack.topics.length != book['topicCount']) {
      throw const FormatException('Hymnal pack catalog mismatch.');
    }
    result.add(pack);
  }
  return List.unmodifiable(result);
}
