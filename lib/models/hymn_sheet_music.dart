import 'dart:convert';

class HymnScorePage {
  final String asset;
  final int width;
  final int height;

  const HymnScorePage(this.asset, this.width, this.height);
}

/// Score assets are indexed by edition, never inferred from a hymn number.
class HymnSheetMusicCatalog {
  final Map<String, Map<int, List<HymnScorePage>>> books;

  const HymnSheetMusicCatalog(this.books);

  factory HymnSheetMusicCatalog.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Unsupported sheet music catalog');
    }
    final books = <String, Map<int, List<HymnScorePage>>>{};
    for (final book in (data['books'] as Map<String, dynamic>).entries) {
      final hymns = <int, List<HymnScorePage>>{};
      for (final hymn
          in (book.value['hymns'] as Map<String, dynamic>).entries) {
        final pages = <HymnScorePage>[];
        for (final page in hymn.value as List<dynamic>) {
          final asset = page['asset'] as String;
          final width = page['width'] as int;
          final height = page['height'] as int;
          if (!RegExp(r'^assets/sheet_music/[a-z0-9_]+/[a-z0-9_]+\.png$')
                  .hasMatch(asset) ||
              width <= 0 ||
              height <= 0) {
            throw const FormatException('Invalid score page');
          }
          pages.add(HymnScorePage(asset, width, height));
        }
        hymns[int.parse(hymn.key)] = List.unmodifiable(pages);
      }
      books[book.key] = Map.unmodifiable(hymns);
    }
    return HymnSheetMusicCatalog(Map.unmodifiable(books));
  }

  List<HymnScorePage> forHymn(String version, int number) {
    // Legacy aliases remain confined to this boundary until the full catalog
    // migration. An unknown edition must never borrow an English score.
    final book = switch (version) {
      'new' => 'sda-en-1985',
      'old' => 'sda-en-1941',
      _ => version,
    };
    return books[book]?[number] ?? const [];
  }
}
