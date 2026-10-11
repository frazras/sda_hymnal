import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn_sheet_music.dart';
import 'package:sdahymnal/services/language_pack_store.dart';
import 'package:sdahymnal/services/score_pack_store.dart';

void main() {
  final catalog = HymnSheetMusicCatalog.fromJson(
      File('assets/sheet_music/catalog.json').readAsStringSync());
  final base = Uri.parse(
      'https://raw.githubusercontent.com/frazras/sda_hymnal/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/');
  ScorePackDownload descriptor(int number) => ScorePackDownload(
      'sda-en-1985',
      HymnSheetMusicCatalog({
        'sda-en-1985': {number: catalog.forHymn('new', number)}
      }),
      base);
  late Directory directory;
  setUp(() async =>
      directory = await Directory.systemTemp.createTemp('score-packs-'));
  tearDown(() async => directory.delete(recursive: true));
  Future<Uint8List> fetch(ScorePackDownload _, HymnScorePage page,
          LanguagePackCancellation? cancellation) async =>
      File(page.asset).readAsBytes();

  test('complete collection activates offline and reports total bytes',
      () async {
    final pack = descriptor(4);
    final progress = <int>[];
    final store = ScorePackStore(directory, download: fetch);
    await store.install(pack, onProgress: (received, total) {
      expect(total, pack.bytes);
      progress.add(received);
    });
    expect(progress.length, 2);
    expect(progress.last, pack.bytes);
    final offline = ScorePackStore(directory,
        download: (_, __, ___) async => throw StateError('offline'));
    final installed = (await offline.load(pack.bookId))!;
    expect(installed.download.pages.length, 2);
    for (final page in installed.download.pages) {
      page.validate(await installed.fileFor(page).readAsBytes());
    }
    expect(await offline.load('sda-es-2009'), isNull);
    await offline.remove(pack.bookId);
    expect(await offline.load(pack.bookId), isNull);
    expect(await directory.list().toList(), isEmpty);
  });

  test(
      'bad page and cancellation preserve prior active collection and clean staging',
      () async {
    final store = ScorePackStore(directory, download: fetch);
    await store.install(descriptor(1));
    final original =
        await File('${directory.path}/sda-en-1985.json').readAsString();
    var request = 0;
    final bad = ScorePackStore(directory, download: (pack, page, token) async {
      request++;
      return request == 2 ? Uint8List(0) : await fetch(pack, page, token);
    });
    await expectLater(bad.install(descriptor(4)), throwsFormatException);
    final token = LanguagePackCancellation();
    await expectLater(
        store.install(descriptor(4),
            cancellation: token, onProgress: (_, __) => token.cancel()),
        throwsA(isA<LanguagePackCancelled>()));
    expect(await File('${directory.path}/sda-en-1985.json').readAsString(),
        original);
    expect((await store.load('sda-en-1985'))!.download.pages.length, 1);
    expect((await directory.list().toList()).whereType<Directory>().length, 1);
    await store.install(descriptor(4));
    expect((await directory.list().toList()).whereType<Directory>().length, 1);
    expect((await store.load('sda-en-1985'))!.download.pages.length, 2);
  });

  test('corrupt or linked local pages fall back without deleting other data',
      () async {
    final store = ScorePackStore(directory, download: fetch);
    await store.install(descriptor(1));
    final installed = (await store.load('sda-en-1985'))!;
    final page = installed.fileFor(installed.download.pages.single);
    await page.writeAsBytes([0]);
    expect(await store.load('sda-en-1985'), isNull);
    await page.delete();
    await Link(page.path)
        .create(File(catalog.forHymn('new', 1).single.asset).absolute.path);
    expect(await store.load('sda-en-1985'), isNull);
    final unrelated = File('${directory.path}/unrelated.txt');
    await unrelated.writeAsString('keep');
    await store.remove('sda-en-1985');
    expect(await unrelated.readAsString(), 'keep');
    await File('${directory.path}/sda-en-1985.json')
        .writeAsString(jsonEncode({'folder': '../escape'}));
    expect(await store.load('sda-en-1985'), isNull);
  });

  test(
      'unpinned URLs and collections containing multiple editions are rejected',
      () {
    expect(
        () => ScorePackDownload(
            'sda-en-1985',
            descriptor(1).catalog,
            Uri.parse(
                'https://raw.githubusercontent.com/frazras/sda_hymnal/main/')),
        throwsArgumentError);
    expect(() => ScorePackDownload('sda-en-1985', catalog, base),
        throwsArgumentError);
  });
}
