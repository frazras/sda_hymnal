import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sdahymnal/services/hymn_recordings.dart';

/// An entire edition's verified instrumental audio, separate from the evictable cache.
class RecordingPack {
  RecordingPack({required this.book, required List<HymnRecording> recordings})
      : recordings = List.unmodifiable(recordings) {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(book) || recordings.isEmpty) {
      throw ArgumentError('Invalid recording pack');
    }
    final numbers = <int>{};
    for (final recording in recordings) {
      if (recording.book != book ||
          recording.bytes < 12 ||
          !RegExp(r'^[0-9a-f]{40}$').hasMatch(recording.blobHash) ||
          !numbers.add(recording.number)) {
        throw ArgumentError('Invalid recording pack entry');
      }
    }
    if (numbers.length != recordings.length ||
        !List.generate(recordings.length, (i) => i + 1)
            .every(numbers.contains)) {
      throw ArgumentError('Recording pack numbering must be complete');
    }
  }

  final String book;
  final List<HymnRecording> recordings;
  int get bytes => recordings.fold(0, (total, entry) => total + entry.bytes);
  String get revision => sha256
      .convert(utf8.encode(jsonEncode([
        for (final r in recordings) [r.number, r.bytes, r.blobHash],
      ])))
      .toString();
}

class PackDownloadCancelled implements Exception {
  const PackDownloadCancelled();
}

class PackDownloadControl {
  bool cancelled = false;
  void cancel() => cancelled = true;
  void check() {
    if (cancelled) throw const PackDownloadCancelled();
  }
}

/// Stage every file, validate it, then atomically replace a small active pointer.
/// A failed update never changes the active revision. Mutations are serialized.
class RecordingPackStore {
  RecordingPackStore(this.directory, {required this.download});
  final Directory directory;
  final Future<Uint8List> Function(HymnRecording) download;
  Future<void> _mutations = Future.value();

  Future<void> _serialize(Future<void> Function() operation) {
    final result = _mutations.then((_) => operation());
    _mutations = result.catchError((Object _) {});
    return result;
  }

  File _pointer(String book) => File('${directory.path}/$book.json');

  Future<Directory?> _active(String book) async {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(book)) return null;
    try {
      final value = jsonDecode(await _pointer(book).readAsString());
      if (value is! Map ||
          value['book'] != book ||
          value['folder'] is! String ||
          !RegExp(r'^pack-[a-zA-Z0-9_-]+$').hasMatch(value['folder'])) {
        return null;
      }
      final active = Directory('${directory.path}/${value['folder']}');
      if (await FileSystemEntity.type(active.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return null;
      }
      return active;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<File?> file(HymnRecording recording) async {
    if (recording.number < 1 ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(recording.blobHash)) {
      return null;
    }
    final active = await _active(recording.book);
    if (active == null) return null;
    final file = File('${active.path}/${recording.filename}');
    try {
      recording.validate(await file.readAsBytes());
      return file;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> install(
    RecordingPack pack, {
    PackDownloadControl? control,
    void Function(int completed, int total, int bytes)? onProgress,
  }) =>
      _serialize(() async {
        final cancellation = control ?? PackDownloadControl();
        cancellation.check();
        await directory.create(recursive: true);
        final staging = await directory.createTemp('pack-');
        var activated = false;

        try {
          var completed = 0, downloadedBytes = 0;
          for (final recording in pack.recordings) {
            cancellation.check();
            final bytes = await download(recording);
            cancellation.check();
            recording.validate(bytes);
            await File('${staging.path}/${recording.filename}')
                .writeAsBytes(bytes, flush: true);
            downloadedBytes += bytes.length;
            onProgress?.call(
                ++completed, pack.recordings.length, downloadedBytes);
          }
          cancellation.check();
          // Manifest and files are durable before the pointer becomes visible.
          final manifest = {
            'book': pack.book,
            'revision': pack.revision,
            'folder': staging.uri.pathSegments.where((s) => s.isNotEmpty).last,
            'count': pack.recordings.length,
            'bytes': pack.bytes
          };
          await File('${staging.path}/manifest.json')
              .writeAsString(jsonEncode(manifest), flush: true);
          final pointerTemp = File('${staging.path}/active.json');
          await pointerTemp.writeAsString(jsonEncode(manifest), flush: true);
          cancellation.check();
          await pointerTemp.rename(_pointer(pack.book).path);
          activated = true;
        } finally {
          if (!activated && await staging.exists()) {
            await staging.delete(recursive: true);
          }
        }
      });

  /// Removing audio does not touch book text, favorites, settings or the cache.
  Future<void> remove(String book) => _serialize(() async {
        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(book)) return;
        // Deactivate first, so lookups cannot observe partial removal.
        final pointer = _pointer(book);
        if (await pointer.exists()) await pointer.delete();
        if (!await directory.exists()) return;
        // Include older revisions, while retaining every other edition.
        await for (final entry in directory.list(followLinks: false)) {
          if (entry is! Directory) continue;
          try {
            final manifest = jsonDecode(
                await File('${entry.path}/manifest.json').readAsString());
            if (manifest is Map && manifest['book'] == book) {
              await entry.delete(recursive: true);
            }
          } on FileSystemException {
            continue;
          } on FormatException {
            continue;
          }
        }
      });
}
