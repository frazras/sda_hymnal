import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/installed_language_packs.dart';
import 'package:sdahymnal/services/language_pack_store.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

void main() {
  late Directory directory;
  setUp(() async =>
      directory = await Directory.systemTemp.createTemp('installed-text-'));
  tearDown(() async => directory.delete(recursive: true));
  Uint8List corrected() {
    final data =
        jsonDecode(File('assets/hymnals/sda-es-2009.json').readAsStringSync());
    data['items'][0]['title'] = 'Título revisado';
    return Uint8List.fromList(utf8.encode(jsonEncode(data)));
  }

  LanguagePackDownload descriptor(Uint8List bytes) => LanguagePackDownload(
      bookId: 'sda-es-2009',
      url: Uri.parse('https://example.com/reviewed.json'),
      bytes: bytes.length,
      checksum: sha256.convert(bytes).toString(),
      hymnCount: 614,
      topicCount: 47);

  test('download catalog pins six exact edition objects', () async {
    final downloads = await loadLanguagePackDownloads(FilePackBundle());
    expect(downloads.length, 6);
    expect(downloads.first.bookId, 'sda-es-2009');
    expect(downloads.first.hymnCount, 614);
    expect(downloads.first.topicCount, 47);
    expect(() => downloads.clear(), throwsUnsupportedError);
    for (final download in downloads) {
      final source =
          File('assets/hymnals/${download.bookId}.json').readAsBytesSync();
      expect(download.validate(source).edition.id, download.bookId);
    }
  });

  test('download catalog rejects redirects, duplicate books and mutable refs',
      () async {
    final original = File('assets/hymnals/downloads.json').readAsStringSync();
    for (final change in <void Function(Map<String, dynamic>)>[
      (value) => value['source']['revision'] = 'main',
      (value) =>
          value['books'][0]['url'] = 'https://example.com/unreviewed.json',
      (value) => value['books'].add(value['books'][0]),
      (value) => value['books'] = [],
    ]) {
      final catalog = jsonDecode(original) as Map<String, dynamic>;
      change(catalog);
      final bundle = FilePackBundle({
        'assets/hymnals/downloads.json':
            Uint8List.fromList(utf8.encode(jsonEncode(catalog)))
      });
      await expectLater(
          loadLanguagePackDownloads(bundle), throwsFormatException);
    }
  });

  test('offline updated text replaces only its edition in the shared loader',
      () async {
    final bytes = corrected();
    final store = LanguagePackStore(directory, download: (_) async => bytes);
    await store.install(descriptor(bytes));
    final packs =
        await loadInstalledLanguagePacks(FilePackBundle(), store: store);
    expect(packs.map((p) => p.edition.id), [
      'sda-es-2009',
      'sda-es-1962',
      'sda-pt-1996',
      'sda-ru-1997',
      'sda-fr-hymnes-et-louanges',
      'sda-sw-nyimbo-za-kristo'
    ]);
    expect(packs.first.hymns.first.title, 'Título revisado');
    expect(packs.first.hymns.first.ref.bookId, 'sda-es-2009');
    expect(packs.first.hymns.first.ref.itemId, '1');
    expect(packs.map((p) => p.hymns.length), [614, 527, 610, 385, 520, 220]);
    expect(packs[1].hymns.first.title, isNot('Título revisado'));
    expect(() => packs.clear(), throwsUnsupportedError);
    await store.remove('sda-es-2009');
    final restored =
        await loadInstalledLanguagePacks(FilePackBundle(), store: store);
    expect(restored.first.hymns.first.title, isNot('Título revisado'));
    expect(restored.first.hymns.first.ref, packs.first.hymns.first.ref);
  });

  test('damaged downloaded text falls back without losing the other books',
      () async {
    final bytes = corrected();
    final store = LanguagePackStore(directory, download: (_) async => bytes);
    await store.install(descriptor(bytes));
    final pointer = jsonDecode(
        await File('${directory.path}/sda-es-2009.json').readAsString());
    await File('${directory.path}/${pointer['folder']}/pack.json')
        .writeAsString('{}');
    final packs =
        await loadInstalledLanguagePacks(FilePackBundle(), store: store);
    expect(packs.length, 6);
    expect(packs.first.hymns.first.title, isNot('Título revisado'));
    expect(packs.first.hymns.length, 614);
    expect(packs.last.hymns.length, 220);
  });
}
