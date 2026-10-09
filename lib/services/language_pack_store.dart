import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import '../models/hymnal_pack.dart';

/// Reviewed catalog metadata for one text pack. Audio is never included.
class LanguagePackDownload {
  LanguagePackDownload({
    required this.bookId,
    required this.url,
    required this.bytes,
    required this.checksum,
    required this.hymnCount,
    required this.topicCount,
  }) {
    if (!RegExp(r'^sda-[a-z0-9-]+$').hasMatch(bookId) ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        bytes < 1 ||
        bytes > 16 * 1024 * 1024 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum) ||
        hymnCount < 1 ||
        topicCount < 0) {
      throw ArgumentError('Invalid language pack download');
    }
  }

  final String bookId;
  final Uri url;
  final int bytes;
  final String checksum;
  final int hymnCount;
  final int topicCount;

  HymnalPack validate(Uint8List data) {
    if (data.length != bytes || sha256.convert(data).toString() != checksum) {
      throw const FormatException('Language pack checksum mismatch');
    }
    final pack = HymnalPack.fromJson(utf8.decode(data));
    if (pack.edition.id != bookId ||
        pack.hymns.length != hymnCount ||
        pack.topics.length != topicCount) {
      throw const FormatException('Language pack catalog mismatch');
    }
    return pack;
  }

  Map<String, Object> get metadata => {
        'bookId': bookId,
        'url': url.toString(),
        'bytes': bytes,
        'sha256': checksum,
        'hymnCount': hymnCount,
        'topicCount': topicCount,
      };

  factory LanguagePackDownload.fromJson(Map<String, dynamic> value) =>
      LanguagePackDownload(
          bookId: value['bookId'] as String,
          url: Uri.parse(value['url'] as String),
          bytes: value['bytes'] as int,
          checksum: value['sha256'] as String,
          hymnCount: value['hymnCount'] as int,
          topicCount: value['topicCount'] as int);
}

class LanguagePackCancelled implements Exception {
  const LanguagePackCancelled();
}

class LanguagePackCancellation {
  bool _cancelled = false;
  void cancel() => _cancelled = true;
  void check() {
    if (_cancelled) throw const LanguagePackCancelled();
  }
}

/// Downloaded text overrides live separately from bundled fallback books.
/// Activation is an atomic pointer replacement after complete validation.
class LanguagePackStore {
  LanguagePackStore(this.directory, {required this.download});
  final Directory directory;
  final Future<Uint8List> Function(LanguagePackDownload) download;
  Future<void> _mutations = Future.value();

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _mutations.then((_) => operation());
    _mutations = result.catchError((Object _) {});
    return result;
  }

  bool _validBook(String id) => RegExp(r'^sda-[a-z0-9-]+$').hasMatch(id);
  File _pointer(String book) => File('${directory.path}/$book.json');

  /// Invalid local content is ignored so the caller can retain bundled content.
  Future<HymnalPack?> load(String book) async {
    if (!_validBook(book)) return null;
    try {
      final pointer = _pointer(book);
      if (await FileSystemEntity.type(pointer.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return null;
      }
      final value =
          jsonDecode(await pointer.readAsString()) as Map<String, dynamic>;
      final folder = value['folder'] as String;
      if (!RegExp(r'^text-[a-zA-Z0-9_-]+$').hasMatch(folder)) return null;
      final packDirectory = Directory('${directory.path}/$folder');
      if (await FileSystemEntity.type(packDirectory.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return null;
      }
      final file = File('${packDirectory.path}/pack.json');
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return null;
      }
      final descriptor = LanguagePackDownload.fromJson(value);
      if (descriptor.bookId != book ||
          await file.length() != descriptor.bytes) {
        return null;
      }
      return descriptor.validate(await file.readAsBytes());
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

  Future<void> install(LanguagePackDownload descriptor,
          {LanguagePackCancellation? cancellation}) =>
      _serialize(() async {
        cancellation?.check();
        // Validate before writing or replacing any active content.
        final data = Uint8List.fromList(await download(descriptor));
        cancellation?.check();
        descriptor.validate(data);
        await directory.create(recursive: true);
        final staging = await directory.createTemp('text-');
        var activated = false;
        try {
          await File('${staging.path}/pack.json')
              .writeAsBytes(data, flush: true);
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
          } on FileSystemException {
            // A cleanup failure does not undo the already committed activation.
          }
        } finally {
          if (!activated && await staging.exists()) {
            await staging.delete(recursive: true);
          }
        }
      });

  /// Deactivate downloaded text only. The caller retains bundled content and refs.
  Future<void> remove(String book) => _serialize(() async {
        if (!_validBook(book)) return;
        final pointer = _pointer(book);
        if (await pointer.exists()) await pointer.delete();
        await _clean(book);
      });

  Future<void> _clean(String book, {String? keep}) async {
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! Directory ||
          !RegExp(r'^text-[a-zA-Z0-9_-]+$').hasMatch(
              entry.uri.pathSegments.where((s) => s.isNotEmpty).last) ||
          entry.uri.pathSegments.where((s) => s.isNotEmpty).last == keep) {
        continue;
      }
      try {
        final value = jsonDecode(
            await File('${entry.path}/manifest.json').readAsString());
        if (value is Map && value['bookId'] == book) {
          await entry.delete(recursive: true);
        }
      } on FileSystemException {
        // Cleanup failure must not invalidate a successfully activated pack.
      } on FormatException {
        // Leave unknown directories untouched.
      }
    }
  }
}
