import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/hymn_recordings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every Spanish item has a pinned edition-specific recording', () async {
    for (final (book, count, year) in [
      ('sda-es-2009', 614, '2009'),
      ('sda-es-1962', 527, '1962')
    ]) {
      for (var n = 1; n <= count; n++) {
        expect(HymnRecordings.contains(book, n), isTrue);
        final r = await HymnRecordings.lookup(book, n);
        expect(Uri.decodeFull(r.url.path),
            contains('/spanish/$year version/instrumental/'));
        expect(r.url.path, endsWith('/${n.toString().padLeft(3, '0')}.m4a'));
        expect(r.blobHash, matches(RegExp(r'^[a-f0-9]{40}$')));
        expect(r.bytes, greaterThan(1000));
      }
      expect(HymnRecordings.contains(book, 0), isFalse);
      expect(HymnRecordings.contains(book, count + 1), isFalse);
    }
    expect(HymnRecordings.contains('new', 1), isFalse);
    expect(HymnRecordings.contains('sda-fr-hymnes-et-louanges', 1), isFalse);
  });

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recording-test-');
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  final bytes = Uint8List.fromList(
      [0, 0, 0, 20, ...ascii.encode('ftypM4A '), 0, 0, 0, 0]);
  HymnRecording recording(int n) => HymnRecording(
      'sda-es-2009',
      n,
      Uri.parse('https://example.com/$n.m4a'),
      bytes.length,
      sha1.convert(
          [...utf8.encode('blob ${bytes.length}\u0000'), ...bytes]).toString());

  test('cache reuses checked bytes offline and repairs corruption', () async {
    var downloads = 0;
    final cache = RecordingCache(dir, download: (_) async {
      downloads++;
      return bytes;
    });
    final r = recording(1);
    final files = await Future.wait([cache.get(r), cache.get(r)]);
    expect(downloads, 1);
    expect(files.first.path, files.last.path);
    await cache.get(r);
    expect(downloads, 1);
    await files.first.writeAsString('<html>not audio</html>');
    await cache.get(r);
    expect(downloads, 2);
    expect(await files.first.readAsBytes(), bytes);
  });

  test('rejects HTML, truncated and wrong-revision audio without caching',
      () async {
    for (final invalid in [
      Uint8List.fromList(utf8.encode('<html>challenge</html>')),
      Uint8List(4),
      Uint8List.fromList([...bytes]..[15] = 1)
    ]) {
      final cache = RecordingCache(dir, download: (_) async => invalid);
      await expectLater(cache.get(recording(1)), throwsFormatException);
      expect(await dir.list().toList(), isEmpty);
    }
  });

  test('bounded cache evicts old recordings, preserving the new one', () async {
    final cache = RecordingCache(dir,
        maxBytes: bytes.length, download: (_) async => bytes);
    final old = await cache.get(recording(1));
    final latest = await cache.get(recording(2));
    expect(await old.exists(), isFalse);
    expect(await latest.exists(), isTrue);
  });
}
