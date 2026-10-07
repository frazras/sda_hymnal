import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Edition-specific instrumental recordings, pinned to an audited source revision.
class HymnRecording {
  HymnRecording(this.book, this.number, this.url, this.bytes, this.blobHash);
  final String book;
  final int number;
  final Uri url;
  final int bytes;
  final String blobHash;
  String get filename => '$book-$number-$blobHash.m4a';

  void validate(Uint8List data) {
    final header = utf8.encode('blob ${data.length}\u0000');
    if (data.length != bytes ||
        data.length < 12 ||
        ascii.decode(data.sublist(4, 8), allowInvalid: true) != 'ftyp' ||
        sha1.convert([...header, ...data]).toString() != blobHash) {
      throw const FormatException('Recording failed integrity check');
    }
  }
}

class HymnRecordings {
  static bool contains(String book, int number) =>
      number >= 1 &&
      ((book == 'sda-es-2009' && number <= 614) ||
          (book == 'sda-es-1962' && number <= 527));

  static Future<Map<(String, int), HymnRecording>>? _catalog;
  static Future<HymnRecording> lookup(String book, int number) async {
    final catalog = await (_catalog ??= _load());
    return catalog[(book, number)] ??
        (throw ArgumentError('No recording for $book:$number'));
  }

  static Future<Map<(String, int), HymnRecording>> _load() async {
    final json = jsonDecode(await rootBundle
        .loadString('assets/hymnals/spanish_recordings.json')) as Map;
    final result = <(String, int), HymnRecording>{};
    for (final book in json['books'] as List) {
      for (final item in book['items'] as List) {
        final id = book['bookId'] as String;
        final n = int.parse(item['itemId'] as String);
        final uri = Uri.https('raw.githubusercontent.com',
            '/${json['repository']}/${json['revision']}/${item['path']}');
        result[(id, n)] = HymnRecording(
            id, n, uri, item['bytes'] as int, item['gitBlobSha1'] as String);
      }
    }
    return result;
  }

  static final Future<RecordingCache> _cache = getTemporaryDirectory()
      .then((d) => RecordingCache(Directory('${d.path}/hymn_recordings')));
  static Future<File> file(String book, int number) async =>
      (await _cache).get(await lookup(book, number));
}

/// Bounded, verified on-demand cache. Never stores an incomplete download as audio.
class RecordingCache {
  RecordingCache(this.directory,
      {this.download, this.maxBytes = 128 * 1024 * 1024});
  final Directory directory;
  final Future<Uint8List> Function(HymnRecording)? download;
  final int maxBytes;
  final _pending = <String, Future<File>>{};

  Future<File> get(HymnRecording recording) =>
      _pending.putIfAbsent(recording.filename, () async {
        try {
          return await _get(recording);
        } finally {
          _pending.remove(recording.filename);
        }
      });

  Future<File> _get(HymnRecording recording) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/${recording.filename}');
    if (await file.exists()) {
      try {
        recording.validate(await file.readAsBytes());
        await file.setLastModified(DateTime.now());
        return file;
      } on FormatException {
        await file.delete();
      }
    }
    final bytes = await (download ?? _download)(recording);
    recording.validate(bytes);
    final staging = await directory.createTemp('.download-');
    try {
      final temp = File('${staging.path}/audio.m4a');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } finally {
      await staging.delete(recursive: true);
    }
    await _trim(file);
    return file;
  }

  Future<void> _trim(File keep) async {
    final files = await directory
        .list()
        .where((f) => f is File && f.path.endsWith('.m4a'))
        .cast<File>()
        .toList();
    final stats = <String, FileStat>{};
    for (final f in files) {
      stats[f.path] = await f.stat();
    }
    files.sort(
        (a, b) => stats[a.path]!.modified.compareTo(stats[b.path]!.modified));
    var total = stats.values.fold(0, (int n, s) => n + s.size);
    for (final f in files) {
      if (total <= maxBytes) break;
      if (f.path == keep.path) continue;
      await f.delete();
      total -= stats[f.path]!.size;
    }
  }

  static Future<Uint8List> _download(HymnRecording recording) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(recording.url);
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('Recording unavailable', uri: recording.url);
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        bytes.add(chunk);
        if (bytes.length > recording.bytes) {
          throw const FormatException('Recording exceeds expected size');
        }
      }
      return bytes.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}
