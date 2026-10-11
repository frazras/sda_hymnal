import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sdahymnal/models/hymn_sheet_music.dart';
import 'package:sdahymnal/services/language_pack_store.dart';
import 'package:sdahymnal/services/score_pack_store.dart';
import 'package:sdahymnal/services/score_pack_download.dart';

void main() {
  final catalog = HymnSheetMusicCatalog.fromJson(
      File('assets/sheet_music/catalog.json').readAsStringSync());
  final page = catalog.forHymn('new', 1).single;
  final data = File(page.asset).readAsBytesSync();
  final pack = ScorePackDownload(
      'sda-en-1985',
      HymnSheetMusicCatalog({
        'sda-en-1985': {
          1: [page]
        }
      }),
      Uri.parse(
          'https://raw.githubusercontent.com/frazras/sda_hymnal/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/'));

  test('verified page uses exact pinned URL and preserves caller client',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url, pack.urlFor(page));
      expect(request.followRedirects, isFalse);
      return http.Response.bytes(data, 200);
    });
    expect(await downloadScorePage(pack, page, null, client: client), data);
    expect(await downloadScorePage(pack, page, null, client: client), data);
    expect(calls, 2);
    client.close();
  });

  test('failed, redirected, changed and oversized responses are rejected',
      () async {
    for (final response in [
      http.Response('', 404),
      http.Response('', 302),
      http.Response.bytes(data.sublist(1), 200),
      http.Response.bytes([...data, 0], 200),
      http.Response.bytes(
          [...data.sublist(0, data.length - 1), data.last ^ 1], 200)
    ]) {
      final client = MockClient((_) async => response);
      await expectLater(downloadScorePage(pack, page, null, client: client),
          throwsFormatException);
      client.close();
    }
  });

  test('cancel before request performs no network work', () async {
    var calls = 0;
    final token = LanguagePackCancellation()..cancel();
    final client = MockClient((_) async {
      calls++;
      return http.Response.bytes(data, 200);
    });
    await expectLater(downloadScorePage(pack, page, token, client: client),
        throwsA(isA<LanguagePackCancelled>()));
    expect(calls, 0);
    client.close();
  });
}
