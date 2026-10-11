import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/hymn_sheet_music.dart';
import 'language_pack_store.dart';

/// A pinned score collection; page integrity comes from its reviewed catalog.
class ScorePackDownload {
  ScorePackDownload(this.bookId, HymnSheetMusicCatalog source, this.baseUrl)
      : catalog = HymnSheetMusicCatalog(
            Map<String, Map<int, List<HymnScorePage>>>.unmodifiable({
          for (final book in source.books.entries)
            book.key: Map<int, List<HymnScorePage>>.unmodifiable({
              for (final hymn in book.value.entries)
                hymn.key: List<HymnScorePage>.unmodifiable(hymn.value),
            }),
        })) {
    if (catalog.books.length != 1 ||
        !catalog.books.containsKey(bookId) ||
        baseUrl.scheme != 'https' ||
        baseUrl.host != 'raw.githubusercontent.com' ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        !RegExp(r'^/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/[0-9a-f]{40}/$')
            .hasMatch(baseUrl.path) ||
        pages.isEmpty ||
        pages.length > 5000 ||
        bytes > 256 * 1024 * 1024) {
      throw ArgumentError('Invalid score download');
    }
    // Even manually constructed models must pass the shared catalog validator.
    HymnSheetMusicCatalog.fromJson(jsonEncode(metadata['catalog']));
  }

  final String bookId;
  final HymnSheetMusicCatalog catalog;
  final Uri baseUrl;
  List<HymnScorePage> get pages =>
      catalog.books[bookId]!.values.expand((p) => p).toList();
  int get bytes => pages.fold(0, (n, p) => n + p.bytes);
  Uri urlFor(HymnScorePage page) => baseUrl.resolve(page.asset);

  Map<String, dynamic> get metadata => {
        'bookId': bookId,
        'baseUrl': baseUrl.toString(),
        'catalog': {
          'schemaVersion': 1,
          'books': {
            bookId: {
              'hymns': {
                for (final entry in catalog.books[bookId]!.entries)
                  entry.key.toString(): [
                    for (final page in entry.value)
                      {
                        'asset': page.asset,
                        'width': page.width,
                        'height': page.height,
                        'bytes': page.bytes,
                        'sha256': page.checksum,
                      }
                  ],
              }
            },
          }
        },
      };

  factory ScorePackDownload.fromJson(Map<String, dynamic> value) =>
      ScorePackDownload(
          value['bookId'] as String,
          HymnSheetMusicCatalog.fromJson(jsonEncode(value['catalog'])),
          Uri.parse(value['baseUrl'] as String));
}

class InstalledScorePack {
  const InstalledScorePack(this.download, this.directory);
  final ScorePackDownload download;
  final Directory directory;
  File fileFor(HymnScorePage page) =>
      File('${directory.path}/${page.asset.split('/').last}');
}

/// Stage a whole collection separately, then atomically activate its pointer.
class ScorePackStore {
  ScorePackStore(this.directory, {required this.download});
  final Directory directory;
  final Future<Uint8List> Function(
      ScorePackDownload, HymnScorePage, LanguagePackCancellation?) download;
  Future<void> _mutations = Future.value();
  bool _validBook(String book) =>
      RegExp(r'^sda-[a-z]{2,3}-[a-z0-9-]+$').hasMatch(book);
  File _pointer(String book) => File('${directory.path}/$book.json');

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _mutations.then((_) => operation());
    _mutations = result.catchError((Object _) {});
    return result;
  }

  Future<InstalledScorePack?> load(String book) async {
    if (!_validBook(book)) {
      return null;
    }
    try {
      final pointer = _pointer(book);
      if (await FileSystemEntity.type(pointer.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return null;
      }
      final metadata =
          jsonDecode(await pointer.readAsString()) as Map<String, dynamic>;
      final folder = metadata['folder'] as String;
      if (!RegExp(r'^scores-[a-zA-Z0-9_-]+$').hasMatch(folder)) {
        return null;
      }
      final packDirectory = Directory('${directory.path}/$folder');
      if (await FileSystemEntity.type(packDirectory.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return null;
      }
      final descriptor = ScorePackDownload.fromJson(metadata);
      if (descriptor.bookId != book) {
        return null;
      }
      final installed = InstalledScorePack(descriptor, packDirectory);
      for (final page in descriptor.pages) {
        final file = installed.fileFor(page);
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await file.length() != page.bytes) {
          return null;
        }
        page.validate(await file.readAsBytes());
      }
      return installed;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<void> install(ScorePackDownload descriptor,
          {LanguagePackCancellation? cancellation,
          void Function(int received, int total)? onProgress}) =>
      _serialize(() async {
        cancellation?.check();
        await directory.create(recursive: true);
        final staging = await directory.createTemp('scores-');
        var activated = false;
        try {
          var received = 0;
          final pack = InstalledScorePack(descriptor, staging);
          for (final page in descriptor.pages) {
            cancellation?.check();
            final data = await download(descriptor, page, cancellation);
            cancellation?.check();
            page.validate(data);
            await pack.fileFor(page).writeAsBytes(data, flush: true);
            received += data.length;
            onProgress?.call(received, descriptor.bytes);
          }
          final metadata = {
            ...descriptor.metadata,
            'folder': staging.uri.pathSegments.where((s) => s.isNotEmpty).last
          };
          await File('${staging.path}/manifest.json')
              .writeAsString(jsonEncode(metadata), flush: true);
          final pointer = File('${staging.path}/active.json');
          await pointer.writeAsString(jsonEncode(metadata), flush: true);
          cancellation?.check();
          await pointer.rename(_pointer(descriptor.bookId).path);
          activated = true;
          try {
            await _clean(descriptor.bookId, keep: metadata['folder'] as String);
          } on FileSystemException {/* Activation already succeeded. */}
        } finally {
          if (!activated && await staging.exists()) {
            await staging.delete(recursive: true);
          }
        }
      });

  Future<void> remove(String book) => _serialize(() async {
        if (!_validBook(book)) return;
        if (await _pointer(book).exists()) await _pointer(book).delete();
        await _clean(book);
      });

  Future<void> _clean(String book, {String? keep}) async {
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entry is! Directory ||
          !RegExp(r'^scores-[a-zA-Z0-9_-]+$').hasMatch(name) ||
          name == keep) {
        continue;
      }
      try {
        final metadata = jsonDecode(
            await File('${entry.path}/manifest.json').readAsString());
        if (metadata is Map && metadata['bookId'] == book) {
          await entry.delete(recursive: true);
        }
      } on FileSystemException {
        /* Leave unrelated or unreadable data alone. */
      } on FormatException {/* Leave unrelated or unreadable data alone. */}
    }
  }
}
