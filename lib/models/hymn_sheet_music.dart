import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:sdahymnal/models/hymn_ref.dart';

class HymnScorePage {
  final String asset;
  final int width;
  final int height;

  final int bytes;
  final String checksum;

  const HymnScorePage(this.asset, this.width, this.height,
      {required this.bytes, required this.checksum});

  /// Verify a downloaded page against the trusted catalog before activation.
  void validate(Uint8List data) {
    if (data.length != bytes ||
        data.length < 33 ||
        sha256.convert(data).toString() != checksum) {
      throw const FormatException('Score page checksum mismatch');
    }
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i++) {
      if (data[i] != signature[i])
        throw const FormatException('Invalid score PNG');
    }
    final header = ByteData.sublistView(data);
    if (header.getUint32(8) != 13 ||
        ascii.decode(data.sublist(12, 16)) != 'IHDR' ||
        header.getUint32(16) != width ||
        header.getUint32(20) != height) {
      throw const FormatException('Score page dimensions mismatch');
    }
  }
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
    final seenAssets = <String>{};
    for (final book in (data['books'] as Map<String, dynamic>).entries) {
      if (!RegExp(r'^sda-[a-z]{2,3}-[a-z0-9-]+$').hasMatch(book.key)) {
        throw const FormatException('Invalid score book identity');
      }
      final directory = book.key.substring(4).replaceAll('-', '_');
      final hymns = <int, List<HymnScorePage>>{};
      for (final hymn
          in (book.value['hymns'] as Map<String, dynamic>).entries) {
        if (!RegExp(r'^[1-9][0-9]*$').hasMatch(hymn.key) ||
            (hymn.value as List<dynamic>).isEmpty) {
          throw const FormatException('Invalid score hymn');
        }
        final pages = <HymnScorePage>[];
        for (final page in hymn.value as List<dynamic>) {
          final asset = page['asset'] as String;
          final width = page['width'] as int;
          final height = page['height'] as int;
          final bytes = page['bytes'] as int;
          final checksum = page['sha256'] as String;
          if (!RegExp(r'^assets/sheet_music/[a-z0-9_]+/[a-z0-9_]+\.png$')
                  .hasMatch(asset) ||
              !asset.startsWith('assets/sheet_music/$directory/') ||
              !seenAssets.add(asset) ||
              width <= 0 ||
              width > 16384 ||
              height <= 0 ||
              height > 16384 ||
              bytes < 33 ||
              bytes > 16 * 1024 * 1024 ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum)) {
            throw const FormatException('Invalid score page');
          }
          pages.add(HymnScorePage(asset, width, height,
              bytes: bytes, checksum: checksum));
        }
        hymns[int.parse(hymn.key)] = List.unmodifiable(pages);
      }
      if (hymns.isEmpty) throw const FormatException('Empty score book');
      books[book.key] = Map.unmodifiable(hymns);
    }
    if (books.isEmpty) throw const FormatException('Empty score catalog');
    return HymnSheetMusicCatalog(Map.unmodifiable(books));
  }

  List<HymnScorePage> forHymn(String version, int number) {
    final book = canonicalBookId(version);
    return books[book]?[number] ?? const [];
  }
}
