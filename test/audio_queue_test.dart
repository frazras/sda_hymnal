import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/playback_queue.dart';
import 'package:sdahymnal/services/audio_queue.dart';

void main() {
  Hymn hymn(int n) =>
      Hymn(number: n, version: 'new', title: 'Hymn $n', body: 'Lyrics');
  test('serialized advancement preserves repeats and stops at service reading',
      () async {
    final played = <int>[];
    final controller = AudioQueue(
        play: (h) async => played.add(h.number),
        playable: (_) => true,
        autoplay: () => true);
    final repeated = hymn(1);
    controller.select(
        HymnPlaybackQueue(
            entries: [repeated, repeated, null, hymn(2)],
            wrap: false,
            skipUnavailable: false),
        0);
    await controller.advance(1);
    expect(controller.value!.index, 1);
    expect(played, [1]);
    await controller.advance(1);
    expect(played, [1]);
    await controller.advance(-1);
    expect(controller.value!.index, 0);
    expect(played, [1, 1]);
  });
  test('clearing or replacing selection cancels queued navigation', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    final controller = AudioQueue(
        play: (_) async {
          started.complete();
          await gate.future;
        },
        playable: (_) => true,
        autoplay: () => true);
    final queue = HymnPlaybackQueue(
        entries: [hymn(1), hymn(2)], wrap: true, skipUnavailable: true);
    controller.select(queue, 0);
    final first = controller.advance(1);
    await started.future;
    final second = controller.advance(1);
    controller.clear();
    gate.complete();
    await Future.wait([first, second]);
    expect(controller.value, isNull);
  });
  test('failed load preserves occurrence and allows retry', () async {
    var fail = true;
    final controller = AudioQueue(
        play: (_) async {
          if (fail) throw StateError('offline');
        },
        playable: (_) => true,
        autoplay: () => false);
    controller.select(
        HymnPlaybackQueue(
            entries: [hymn(1), hymn(2)], wrap: true, skipUnavailable: true),
        0);
    await expectLater(controller.advance(1), throwsStateError);
    expect(controller.value!.index, 0);
    fail = false;
    await controller.advance(1);
    expect(controller.value!.index, 1);
  });
  test('pause cancels automatic advancement during preparation', () async {
    final gate = Completer<void>(), started = Completer<void>();
    final played = <int>[];
    final controller = AudioQueue(
        play: (h) async => played.add(h.number),
        guardedPlay: (h, valid) async {
          started.complete();
          await gate.future;
          if (valid()) played.add(h.number);
        },
        playable: (_) => true,
        autoplay: () => true);
    controller.select(
        HymnPlaybackQueue(
            entries: [hymn(1), hymn(2)], wrap: true, skipUnavailable: true),
        0);
    final advancing = controller.advance(1, automatic: true);
    await started.future;
    controller.cancelPending();
    gate.complete();
    await advancing;
    expect(played, isEmpty);
    expect(controller.value!.index, 0);
    await controller.advance(1, automatic: true);
    expect(played, isEmpty);
  });
}
