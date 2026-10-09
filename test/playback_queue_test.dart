import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/playback_queue.dart';

void main() {
  Hymn hymn(int number, String book) => Hymn(
      number: number,
      version: book,
      title: 'Source title',
      body: 'Source lyrics');
  final spanish = hymn(1, 'sda-es-2009');
  final english = hymn(1, 'new');
  final old = hymn(1, 'sda-es-1962');

  test(
      'category snapshot retains mixed editions, order and wrap in either direction',
      () {
    final input = [spanish, english, old];
    final queue =
        HymnPlaybackQueue(entries: input, wrap: true, skipUnavailable: true);
    input.clear();
    expect(queue.entries, [spanish, english, old]);
    expect(queue.adjacent(0, 1, (_) => true), 1);
    expect(queue.adjacent(2, 1, (_) => true), 0);
    expect(queue.adjacent(0, -1, (_) => true), 2);
    expect(queue.adjacent(0, 1, (h) => h.version != 'new'), 2);
    expect(queue.adjacent(0, 1, (_) => false), isNull);
    expect(() => queue.entries.clear(), throwsUnsupportedError);
  });

  test(
      'service occurrences retain repetitions and stop at readings or missing music',
      () {
    final queue = HymnPlaybackQueue(
        entries: [spanish, spanish, null, english, old],
        wrap: false,
        skipUnavailable: false);
    expect(queue.adjacent(0, 1, (_) => true), 1);
    expect(queue.adjacent(1, 1, (_) => true), isNull);
    expect(queue.adjacent(3, -1, (_) => true), isNull);
    expect(queue.adjacent(3, 1, (h) => h.version != 'sda-es-1962'), isNull);
    expect(queue.adjacent(4, 1, (_) => true), isNull);
    expect(queue.adjacent(0, -1, (_) => true), isNull);
  });

  test(
      'single-item categories loop; empty or invalid selections do not start playback',
      () {
    final single = HymnPlaybackQueue(
        entries: [spanish], wrap: true, skipUnavailable: true);
    expect(single.adjacent(0, 1, (_) => true), 0);
    expect(single.adjacent(0, -1, (_) => true), 0);
    for (final index in [-1, 1]) {
      expect(single.adjacent(index, 1, (_) => true), isNull);
    }
    expect(single.adjacent(0, 0, (_) => true), isNull);
    expect(
        HymnPlaybackQueue(entries: [], wrap: true, skipUnavailable: true)
            .adjacent(0, 1, (_) => true),
        isNull);
  });
}
