import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/hymn_recordings.dart';
import 'package:sdahymnal/services/recording_packs.dart';

void main() {
  late Directory directory;
  setUp(
      () async => directory = await Directory.systemTemp.createTemp('packs-'));
  tearDown(() async => directory.delete(recursive: true));
  Uint8List audio(int revision) => Uint8List.fromList(
      [0, 0, 0, 20, ...ascii.encode('ftypM4A '), 0, 0, 0, revision]);
  HymnRecording recording(int number, int revision,
      [String book = 'sda-es-2009']) {
    final bytes = audio(revision);
    return HymnRecording(
        book,
        number,
        Uri.parse('https://example.com/$number'),
        bytes.length,
        sha1.convert([
          ...utf8.encode('blob ${bytes.length}\u0000'),
          ...bytes
        ]).toString());
  }

  RecordingPack pack(int revision, [String book = 'sda-es-2009']) =>
      RecordingPack(book: book, recordings: [
        recording(1, revision, book),
        recording(2, revision, book)
      ]);

  test('complete packs remain verified and usable after reopening offline',
      () async {
    final progress = <int>[];
    final store =
        RecordingPackStore(directory, download: (_) async => audio(1));
    await store.install(pack(1), onProgress: (done, total, bytes) {
      expect(total, 2);
      expect(bytes, done * audio(1).length);
      progress.add(done);
    });
    expect(progress, [1, 2]);
    final reopened = RecordingPackStore(directory,
        download: (_) async => throw StateError('offline'));
    for (final item in pack(1).recordings) {
      expect(await (await reopened.file(item))!.readAsBytes(), audio(1));
    }
    final old = await reopened.file(recording(1, 1));
    await old!.writeAsString('corrupt');
    expect(await reopened.file(recording(1, 1)), isNull);
    expect(await reopened.file(recording(1, 2)), isNull);
  });

  test('failed update keeps active version and removes incomplete staging',
      () async {
    await RecordingPackStore(directory, download: (_) async => audio(1))
        .install(pack(1));
    final before =
        await File('${directory.path}/sda-es-2009.json').readAsString();
    var count = 0;
    final update = RecordingPackStore(directory, download: (_) async {
      if (++count == 2) throw const HttpException('interrupted');
      return audio(2);
    });
    await expectLater(update.install(pack(2)), throwsA(isA<HttpException>()));
    expect(await File('${directory.path}/sda-es-2009.json').readAsString(),
        before);
    expect(await update.file(recording(1, 1)), isNotNull);
    expect(await update.file(recording(1, 2)), isNull);
    expect((await directory.list().toList()).whereType<Directory>().length, 1);
  });

  test('update becomes visible only after all files are verified', () async {
    final gate = Completer<Uint8List>();
    await RecordingPackStore(directory, download: (_) async => audio(1))
        .install(pack(1));
    final reached = Completer<void>();
    final store = RecordingPackStore(directory, download: (r) async {
      if (r.number == 2) {
        reached.complete();
        return await gate.future;
      }
      return audio(2);
    });
    final installing = store.install(pack(2));
    await reached.future;
    expect(await store.file(recording(1, 1)), isNotNull);
    expect(await store.file(recording(1, 2)), isNull);
    gate.complete(audio(2));
    await installing;
    expect(await store.file(recording(1, 1)), isNull);
    expect(await store.file(recording(1, 2)), isNotNull);
    expect(await store.file(recording(2, 2)), isNotNull);
    await store.remove('sda-es-2009');
    expect(await directory.list().toList(), isEmpty);
  });

  test('cancellation and invalid bytes cannot activate packs', () async {
    final control = PackDownloadControl();
    final store =
        RecordingPackStore(directory, download: (_) async => audio(1));
    await expectLater(
        store.install(pack(1),
            control: control, onProgress: (_, __, ___) => control.cancel()),
        throwsA(isA<PackDownloadCancelled>()));
    expect(await directory.list().toList(), isEmpty);
    final bad = RecordingPackStore(directory, download: (_) async => audio(2));
    await expectLater(bad.install(pack(1)), throwsFormatException);
    expect(await directory.list().toList(), isEmpty);
    // A failed operation does not poison later serialized operations.
    await store.install(pack(1));
    expect(await store.file(recording(1, 1)), isNotNull);
  });

  test('removal is edition-specific and unsafe pointers are ignored', () async {
    final store =
        RecordingPackStore(directory, download: (_) async => audio(1));
    await store.install(pack(1));
    await store.install(pack(1, 'sda-es-1962'));
    await store.remove('sda-es-2009');
    expect(await store.file(recording(1, 1)), isNull);
    expect(await store.file(recording(1, 1, 'sda-es-1962')), isNotNull);
    await File('${directory.path}/sda-es-2009.json').writeAsString(
        jsonEncode({'book': 'sda-es-2009', 'folder': '../outside'}));
    expect(await store.file(recording(1, 1)), isNull);
    await store.remove('sda-es-2009');
    expect(await store.file(recording(1, 1, 'sda-es-1962')), isNotNull);
  });

  test('remove waits for an in-flight install and never leaves it active',
      () async {
    final gate = Completer<Uint8List>();
    final reached = Completer<void>();
    final store = RecordingPackStore(directory, download: (r) async {
      if (r.number == 1) {
        reached.complete();
        return await gate.future;
      }
      return audio(1);
    });
    final installing = store.install(pack(1));
    await reached.future;
    final removing = store.remove('sda-es-2009');
    gate.complete(audio(1));
    await Future.wait([installing, removing]);
    expect(await store.file(recording(1, 1)), isNull);
    expect(await directory.list().toList(), isEmpty);
  });

  test(
      'pack specification rejects missing numbers, duplicate and mixed editions',
      () {
    for (final items in [
      <HymnRecording>[],
      [recording(2, 1)],
      [recording(1, 1), recording(1, 1)],
      [recording(1, 1, 'sda-es-1962')]
    ]) {
      expect(() => RecordingPack(book: 'sda-es-2009', recordings: items),
          throwsArgumentError);
    }
    expect(
        () => RecordingPack(book: '../escape', recordings: [recording(1, 1)]),
        throwsArgumentError);
    final input = [recording(1, 1)];
    final immutable = RecordingPack(book: 'sda-es-2009', recordings: input);
    input.clear();
    expect(immutable.recordings.length, 1);
  });
}
