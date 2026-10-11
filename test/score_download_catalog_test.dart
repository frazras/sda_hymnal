import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/score_download_catalog.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

void main() {
  test('three score collections pin every page to reviewed published assets',
      () async {
    final downloads = await loadScorePackDownloads(FilePackBundle());
    expect(downloads.map((d) => d.pages.length), [723, 614, 506]);
    expect(downloads.map((d) => d.catalog.books[d.bookId]!.length),
        [695, 614, 384]);
    for (final download in downloads) {
      for (final page in download.pages) {
        expect(download.urlFor(page).toString(),
            'https://raw.githubusercontent.com/frazras/sda_hymnal/c8501b78b5b5329979eceb0eef8950dd242ab7af/${page.asset}');
        page.validate(File(page.asset).readAsBytesSync());
      }
    }
  });
  test('mutable, tampered and ambiguous metadata never creates downloads',
      () async {
    final source = File('assets/sheet_music/downloads.json').readAsStringSync();
    for (final change in <void Function(Map<String, dynamic>)>[
      (d) => d['source']['revision'] = 'main',
      (d) => d['catalogSha256'] = '0' * 64,
      (d) => d['books'][0]['bytes'] = 1,
      (d) => d['books'][0]['pageCount'] = 1,
      (d) => d['books'][0]['hymnCount'] = 1,
      (d) => d['books'].add(d['books'][0]),
      (d) => d['books'].removeLast(),
      (d) => d['books'][0]['bookId'] = 'sda-en-1941',
    ]) {
      final data = jsonDecode(source) as Map<String, dynamic>;
      change(data);
      await expectLater(
          loadScorePackDownloads(FilePackBundle({
            'assets/sheet_music/downloads.json':
                Uint8List.fromList(utf8.encode(jsonEncode(data))),
          })),
          throwsFormatException);
    }
  });
}
