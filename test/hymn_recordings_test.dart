import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/hymn_recordings.dart';

const instrumental = RecordingKind.instrumental, sung = RecordingKind.sung;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every catalog file is pinned to its exact book, item and kind',
      () async {
    final catalog = jsonDecode(
        await rootBundle.loadString('assets/hymnals/recordings.json')) as Map;
    expect(catalog['schemaVersion'], 2);
    final counts = <(String, RecordingKind), int>{};
    for (final collection in catalog['collections'] as List) {
      final book = collection['bookId'] as String;
      final kind = RecordingKind.fromMedium(collection['medium'] as String);
      final directory = collection['directory'] as String;
      expect(directory, endsWith(kind == sung ? '/sung' : '/instrumental'));
      for (final item in collection['items'] as List) {
        final n = int.parse(item['itemId'] as String);
        expect(HymnRecordings.contains(book, n, kind: kind), isTrue);
        final r = await HymnRecordings.lookup(book, n, kind: kind);
        expect((r.book, r.number, r.kind), (book, n, kind));
        expect(Uri.decodeFull(r.url.path), contains('/$directory/'));
        expect(r.url.path, endsWith('/${n.toString().padLeft(3, '0')}.m4a'));
        expect(r.url.path, contains('/${catalog['revision']}/'));
        expect(r.blobHash, matches(RegExp(r'^[a-f0-9]{40}$')));
        expect(r.bytes, greaterThan(1000));
        counts[(book, kind)] = (counts[(book, kind)] ?? 0) + 1;
      }
    }
    expect(counts, {
      ('sda-es-2009', instrumental): 614,
      ('sda-es-1962', instrumental): 527,
    });
  });

  test('generated availability table matches the bundled catalog exactly',
      () async {
    final catalog = jsonDecode(
        await rootBundle.loadString('assets/hymnals/recordings.json')) as Map;
    final fromAsset = <(String, RecordingKind, int)>{
      for (final collection in catalog['collections'] as List)
        for (final item in collection['items'] as List)
          (
            collection['bookId'] as String,
            RecordingKind.fromMedium(collection['medium'] as String),
            int.parse(item['itemId'] as String)
          ),
    };
    final fromTable = <(String, RecordingKind, int)>{
      for (final MapEntry(key: book, value: kinds)
          in recordingAvailability.entries)
        for (final MapEntry(key: kind, value: ranges) in kinds.entries)
          for (final (first, last) in ranges)
            for (var n = first; n <= last; n++) (book, kind, n),
    };
    expect(fromTable, fromAsset);
    // contains() agrees with the table everywhere, including outside ranges.
    for (final book in recordingAvailability.keys) {
      for (var n = -1; n <= 1000; n++) {
        for (final kind in RecordingKind.values) {
          expect(HymnRecordings.contains(book, n, kind: kind),
              fromAsset.contains((book, kind, n)),
              reason: '$book $n $kind');
        }
      }
    }
  });

  test('kinds are listed per exact book', () {
    expect(HymnRecordings.kindsFor('sda-es-2009', 1), [instrumental]);
    expect(HymnRecordings.kindsFor('sda-es-2009', 614), [instrumental]);
    expect(HymnRecordings.kindsFor('sda-es-1962', 527), [instrumental]);
    for (final (book, n) in [
      ('sda-es-2009', 615),
      ('sda-es-1962', 0),
      ('sda-pt-1996', 1),
      ('sda-ru-1997', 1),
      ('new', 1),
      ('old', 1),
      ('sda-fr-hymnes-et-louanges', 1),
      ('sda-sw-nyimbo-za-kristo', 1),
      ('sda-ny-khristu-mu-nyimbo', 1),
    ]) {
      expect(HymnRecordings.kindsFor(book, n), isEmpty, reason: '$book $n');
      expect(HymnRecordings.contains(book, n), isFalse);
    }
    expect(HymnRecordings.contains('sda-es-2009', 1, kind: sung), isFalse);
  });

  test('the preferred kind wins when recorded, otherwise the other kind', () {
    for (final (book, preferred, expected) in [
      ('sda-es-2009', instrumental, instrumental),
      ('sda-es-2009', sung, instrumental),
      ('sda-es-1962', sung, instrumental),
    ]) {
      expect(HymnRecordings.resolveKind(book, 1, preferred), expected,
          reason: '$book prefers $preferred');
    }
    expect(HymnRecordings.resolveKind('sda-pt-1996', 1, sung), isNull);
    expect(HymnRecordings.resolveKind('sda-fr-hymnes-et-louanges', 1, sung),
        isNull);
    expect(HymnRecordings.resolveKind('sda-es-2009', 615, sung), isNull);
  });

  test('explicit lookups never substitute another kind', () async {
    expect((await HymnRecordings.lookup('sda-es-2009', 1)).kind, instrumental);
    await expectLater(HymnRecordings.lookup('sda-es-2009', 1, kind: sung),
        throwsArgumentError);
    await expectLater(
        HymnRecordings.lookup('sda-pt-1996', 1), throwsArgumentError);
    await expectLater(HymnRecordings.lookup('sda-fr-hymnes-et-louanges', 1),
        throwsArgumentError);
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
  final hash = sha1.convert(
      [...utf8.encode('blob ${bytes.length}\u0000'), ...bytes]).toString();
  HymnRecording recording(int n, {RecordingKind kind = instrumental}) =>
      HymnRecording('sda-es-2009', n, Uri.parse('https://example.com/$n.m4a'),
          bytes.length, hash,
          kind: kind);

  test('cache filenames include the kind, so kinds never collide', () async {
    expect(recording(1).filename, 'sda-es-2009-1-instrumental-$hash.m4a');
    expect(recording(1, kind: sung).filename, 'sda-es-2009-1-sung-$hash.m4a');
    final requested = <RecordingKind>[];
    final cache = RecordingCache(dir, download: (r) async {
      requested.add(r.kind);
      return bytes;
    });
    // Identical bytes still produce two files: one per kind, fetched once each.
    final files = await Future.wait([
      cache.get(recording(1)),
      cache.get(recording(1, kind: sung)),
      cache.get(recording(1, kind: sung)),
    ]);
    expect(requested..sort((a, b) => a.index - b.index), [instrumental, sung]);
    expect(files[0].path, isNot(files[1].path));
    expect(files[1].path, files[2].path);
    expect(files[0].path, endsWith('-instrumental-$hash.m4a'));
    expect(files[1].path, endsWith('-sung-$hash.m4a'));
    expect(await dir.list().where((f) => f.path.endsWith('.m4a')).length, 2);
  });

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
    final latest = await cache.get(recording(1, kind: sung));
    expect(await old.exists(), isFalse);
    expect(await latest.exists(), isTrue);
  });
}
