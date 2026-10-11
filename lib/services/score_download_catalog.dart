import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../models/hymn_sheet_music.dart';
import 'score_pack_store.dart';

/// Compact trusted metadata reuses the reviewed page catalog without duplicating it.
Future<List<ScorePackDownload>> loadScorePackDownloads(
    AssetBundle bundle) async {
  final metadata =
      jsonDecode(await bundle.loadString('assets/sheet_music/downloads.json'))
          as Map<String, dynamic>;
  final source = metadata['source'] as Map<String, dynamic>;
  final repository = source['repository'] as String;
  final revision = source['revision'] as String;
  if (metadata['schemaVersion'] != 1 ||
      !RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repository) ||
      !RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
    throw const FormatException('Unpinned score download catalog');
  }
  final data = await bundle.load('assets/sheet_music/catalog.json');
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  if (sha256.convert(bytes).toString() != metadata['catalogSha256']) {
    throw const FormatException('Score catalog checksum mismatch');
  }
  final catalog = HymnSheetMusicCatalog.fromJson(utf8.decode(bytes));
  final seen = <String>{};
  final result = <ScorePackDownload>[];
  for (final entry in metadata['books'] as List<dynamic>) {
    final book = entry['bookId'] as String;
    if (!seen.add(book) || !catalog.books.containsKey(book)) {
      throw const FormatException('Unknown or repeated score collection');
    }
    final descriptor = ScorePackDownload(
        book,
        HymnSheetMusicCatalog({book: catalog.books[book]!}),
        Uri.https('raw.githubusercontent.com', '/$repository/$revision/'));
    if (entry['bytes'] != descriptor.bytes ||
        entry['pageCount'] != descriptor.pages.length ||
        entry['hymnCount'] != descriptor.catalog.books[book]!.length ||
        entry['bundled'] is! bool ||
        entry['displayName'] is! String ||
        (entry['displayName'] as String).trim().isEmpty) {
      throw const FormatException('Score coverage metadata mismatch');
    }
    result.add(descriptor);
  }
  if (seen.length != catalog.books.length) {
    throw const FormatException('Incomplete score download catalog');
  }
  return List.unmodifiable(result);
}
