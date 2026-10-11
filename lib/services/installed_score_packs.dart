import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hymn_ref.dart';
import '../models/hymn_sheet_music.dart';
import 'score_pack_download.dart';
import 'score_pack_store.dart';

ScorePackStore? _store;
Future<ScorePackStore> get scorePackStore async {
  final existing = _store;
  if (existing != null) return existing;
  final support = await getApplicationSupportDirectory();
  return _store ??= ScorePackStore(Directory('${support.path}/score_packs'),
      download: downloadScorePage);
}

class ScoreViewSource {
  const ScoreViewSource(this.catalog, {this.installed});
  final HymnSheetMusicCatalog catalog;
  final InstalledScorePack? installed;
  File? fileFor(HymnScorePage page) {
    final pack = installed;
    if (pack == null ||
        !pack.download.pages.any((p) => p.asset == page.asset)) {
      return null;
    }
    return pack.fileFor(page);
  }
}

/// Opening a score never starts a download. Invalid local copies retain assets.
Future<ScoreViewSource> loadScoreViewSource(AssetBundle bundle, String book,
    {ScorePackStore? store}) async {
  final bundled = HymnSheetMusicCatalog.fromJson(
      await bundle.loadString('assets/sheet_music/catalog.json'));
  try {
    final installed =
        await (store ?? await scorePackStore).load(canonicalBookId(book));
    if (installed != null) {
      return ScoreViewSource(
          HymnSheetMusicCatalog(Map.unmodifiable({
            ...bundled.books,
            installed.download.bookId:
                Map<int, List<HymnScorePage>>.unmodifiable({
              ...?bundled.books[installed.download.bookId],
              ...installed.download.catalog.books[installed.download.bookId]!,
            }),
          })),
          installed: installed);
    }
  } catch (_) {
    // Storage unavailability must not hide bundled offline scores.
  }
  return ScoreViewSource(bundled);
}
