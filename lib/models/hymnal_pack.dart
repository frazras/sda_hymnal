import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';

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
        year: book['year'] as int);
    if (!RegExp(r'^sda-(es|pt|ru)-\d{4}$').hasMatch(edition.id)) {
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
          title.trim().isEmpty) {
        throw const FormatException('Duplicate or invalid hymn.');
      }
      final body = StringBuffer();
      for (final block in item['blocks'] as List<dynamic>) {
        final text = block['text'] as String;
        if (text.trim().isEmpty ||
            !['verse', 'refrain'].contains(block['kind'])) {
          throw const FormatException('Invalid lyric block.');
        }
        if (body.isNotEmpty) body.write('<br><br>');
        final label = block['label'] as String?;
        if (label != null && label.isNotEmpty) {
          body.write('<b>${escaped(label)}</b><br>');
        }
        body.write(escaped(text));
      }
      if (body.isEmpty) throw const FormatException('Empty hymn lyrics.');
      final hymn = Hymn(
          number: number,
          title: title,
          body: body.toString(),
          version: edition.id,
          bookTitle: edition.displayName,
          languageTag: edition.languageTag,
          credits: item['credits'] as String?);
      hymns.add(hymn);
      byId[id] = hymn;
    }
    hymns.sort((a, b) => a.number.compareTo(b.number));
    final topics = <HymnalTopic>[];
    final topicIds = <String>{};
    for (final topic in data['topics'] as List<dynamic>) {
      final id = topic['id'] as String;
      final ids = (topic['itemIds'] as List<dynamic>).cast<String>();
      if (!topicIds.add(id) ||
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
        !RegExp(r'^sda-(es|pt|ru)-\d{4}$').hasMatch(id) ||
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
