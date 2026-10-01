import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/midi_cache.dart';

void main() {
  late Directory directory;
  late MidiRenderCache cache;
  final bytes = File('assets/midi/016.mid').readAsBytesSync();
  const name = '016_t0_reggae_apple-scoped_v35.mid';
  setUp(() async {
    directory =
        await Directory.systemTemp.createTemp('hymnal-midi-cache-test-');
    cache = MidiRenderCache(directory);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('cache identity includes bank/mix revision, platform and render options',
      () {
    final apple = MidiRenderCache.filename(
        hymnal: 'new',
        hymn: 16,
        semitones: 0,
        theme: 'reggae',
        forAppleSynth: true);
    expect(apple, name);
    expect(
        MidiRenderCache.filename(
            hymnal: 'new',
            hymn: 16,
            semitones: 0,
            theme: 'reggae',
            forAppleSynth: false),
        isNot(apple));
    expect(
        MidiRenderCache.filename(
            hymnal: 'new',
            hymn: 16,
            semitones: 2,
            theme: 'reggae',
            forAppleSynth: true),
        isNot(apple));
    expect(
        MidiRenderCache.filename(
            hymnal: 'new',
            hymn: 16,
            semitones: 0,
            theme: 'reggae',
            forAppleSynth: true,
            forceProgram: 19),
        isNot(apple));
    expect(
        MidiRenderCache.filename(
            hymnal: 'old',
            hymn: 16,
            semitones: 0,
            theme: 'reggae',
            forAppleSynth: true),
        'old_$name');
  });

  test('concurrent requests render once and never expose a partial file',
      () async {
    final ready = Completer<Uint8List>();
    var calls = 0;
    final first = cache.getOrCreate(name, () {
      calls++;
      return ready.future;
    });
    final second = cache.getOrCreate(name, () {
      calls++;
      return ready.future;
    });
    expect(identical(first, second), true);
    expect(await File('${directory.path}/$name').exists(), false);
    ready.complete(bytes);
    final results = await Future.wait([first, second]);
    expect(calls, 1);
    expect(await results.first.readAsBytes(), bytes);
    expect(directory.listSync(), hasLength(1));
    await cache.getOrCreate(name, () async {
      fail('Complete cache must be reused');
    });
  });

  test('invalid entries are replaced and failed renders can be retried',
      () async {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes.sublist(0, 20));
    expect(
        await (await cache.getOrCreate(name, () async => bytes)).readAsBytes(),
        bytes);
    await expectLater(cache.getOrCreate('failed.mid', () async => Uint8List(0)),
        throwsFormatException);
    expect(await File('${directory.path}/failed.mid').exists(), false);
    expect(
        await (await cache.getOrCreate('failed.mid', () async => bytes))
            .readAsBytes(),
        bytes);
    expect(directory.listSync().whereType<Directory>(), isEmpty);
  });

  test('legacy caches and source data are not erased or overwritten', () async {
    final legacy = File('${directory.path}/016_t0_reggae_v22.mid');
    await legacy.writeAsBytes(bytes);
    await cache.getOrCreate(name, () async => bytes);
    expect(await legacy.readAsBytes(), bytes);
    await expectLater(cache.getOrCreate('../escape.mid', () async => bytes),
        throwsArgumentError);
  });
}
