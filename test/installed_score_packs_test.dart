import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn_sheet_music.dart';
import 'package:sdahymnal/services/installed_score_packs.dart';
import 'package:sdahymnal/services/score_pack_store.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

void main() {
  test('viewer source uses verified local edition and retains bundled fallback',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('installed-scores-');
    addTearDown(() => directory.delete(recursive: true));
    var requests = 0;
    final store = ScorePackStore(directory, download: (_, page, __) async {
      requests++;
      return File(page.asset).readAsBytes();
    });
    final bundle = FilePackBundle();
    final bundled = HymnSheetMusicCatalog.fromJson(
        await bundle.loadString('assets/sheet_music/catalog.json'));
    final initial = await loadScoreViewSource(bundle, 'new', store: store);
    expect(initial.installed, isNull);
    expect(initial.catalog.forHymn('new', 4).length, 2);
    expect(requests, 0);
    await store.install(ScorePackDownload(
        'sda-en-1985',
        HymnSheetMusicCatalog({
          'sda-en-1985': {4: bundled.forHymn('new', 4)}
        }),
        Uri.parse(
            'https://raw.githubusercontent.com/frazras/sda_hymnal/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/')));
    final downloaded = await loadScoreViewSource(bundle, 'new', store: store);
    expect(downloaded.installed, isNotNull);
    expect(downloaded.catalog.forHymn('new', 1), isNotEmpty);
    expect(
        downloaded.fileFor(downloaded.catalog.forHymn('new', 1).first), isNull);
    expect(
        downloaded
            .fileFor(downloaded.catalog.forHymn('new', 4).first)!
            .existsSync(),
        isTrue);
    final spanish =
        await loadScoreViewSource(bundle, 'sda-es-2009', store: store);
    expect(spanish.installed, isNull);
    expect(spanish.catalog.forHymn('sda-es-2009', 4).length, 1);
    expect(requests, 2);
    await downloaded
        .fileFor(downloaded.catalog.forHymn('new', 4).first)!
        .writeAsBytes([0]);
    final corrupt = await loadScoreViewSource(bundle, 'new', store: store);
    expect(corrupt.installed, isNull);
    expect(corrupt.catalog.forHymn('new', 4).length, 2);
    await store.remove('sda-en-1985');
    expect((await loadScoreViewSource(bundle, 'new', store: store)).installed,
        isNull);
    expect(requests, 2);
  });
}
