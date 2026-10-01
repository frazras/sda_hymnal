import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/jazz_phrasing.dart';

void main() {
  const d = 120;
  final notes = <JazzPhraseNote>[
    for (var beat = 0; beat < 24; beat++)
      (
        tick: beat * d,
        end: (beat + 1) * d - 1,
        pitch: [60, 62, 64, 67, 64, 65, 67, 64][beat % 8]
      ),
  ];
  final harmony = <int, JazzHarmony>{
    for (var beat = 0; beat < 24; beat++)
      beat: (
        rootPc: beat < 8
            ? 0
            : beat < 16
                ? 5
                : 7,
        quality: ''
      ),
  };
  List<int> plan(List<JazzPhraseNote> source, Map<int, JazzHarmony> chords) =>
      phraseJazzMelody(source, division: d, beatsPerBar: 4, harmony: chords);

  test(
      'added answers are spacious, harmonized and lead to the next melody note',
      () {
    final source = <JazzPhraseNote>[
      (tick: 0, end: 4 * d, pitch: 60),
      (tick: 4 * d, end: 9 * d, pitch: 64),
      (tick: 9 * d, end: 10 * d, pitch: 67),
    ];
    final chords = {for (var b = 0; b < 10; b++) b: (rootPc: 0, quality: '')};
    final fills = jazzMelodyFills(source,
        division: d, beatsPerBar: 4, bpm: 120, harmony: chords);
    expect(fills, hasLength(2));
    for (final fill in fills) {
      expect(fill.sourceIndex, 1);
      expect(fill.end - fill.tick, greaterThanOrEqualTo(d));
      expect(fill.tick, greaterThanOrEqualTo(source[1].tick + 2 * d));
      expect(fill.end, lessThanOrEqualTo(source[2].tick));
      expect({0, 4, 7}, contains(fill.pitch % 12));
    }
    expect(
        jazzMelodyFills(source,
            division: d, beatsPerBar: 4, bpm: 120, harmony: {}),
        isEmpty);
    final quick = jazzMelodyFills(notes,
        division: d, beatsPerBar: 4, bpm: 120, harmony: harmony);
    expect(quick, isEmpty);
  });

  test('develops a multi-bar phrase without adding notes or losing anchors',
      () {
    final output = plan(notes, harmony);
    expect(output, hasLength(notes.length));
    expect(output, plan(notes, harmony));
    expect(output.take(4), notes.take(4).map((n) => n.pitch));
    expect(output.skip(19), notes.skip(19).map((n) => n.pitch));
    final changed = [
      for (var i = 0; i < notes.length; i++)
        if (output[i] != notes[i].pitch) i
    ];
    expect(changed.length, greaterThanOrEqualTo(2));
    expect(changed.last - changed.first, greaterThanOrEqualTo(4));
    for (var i = 0; i < changed.length; i++) {
      final at = changed[i];
      expect((output[at] - notes[at].pitch).abs(), lessThanOrEqualTo(4));
      expect({0, 4, 7}, contains((output[at] - harmony[at]!.rootPc) % 12));
      if (i > 0) expect(at - changed[i - 1], greaterThanOrEqualTo(2));
    }
  });

  test('missing harmony and short phrases retain the written melody', () {
    expect(plan(notes, {}), notes.map((n) => n.pitch));
    expect(plan(notes.take(8).toList(), harmony),
        notes.take(8).map((n) => n.pitch));
  });

  test('a held variation must fit all chords crossed, not just its attack', () {
    final held = [...notes];
    held[8] = (tick: 8 * d, end: 10 * d - 1, pitch: 64);
    held.removeAt(9);
    final chords = {
      ...harmony,
      8: (rootPc: 0, quality: ''),
      9: (rootPc: 1, quality: '')
    };
    // C major and Db major have no shared chord tones.
    expect(plan(held, chords)[8], 64);
  });

  test('fast written notes never become new improvised pitches', () {
    final fast = [
      for (var i = 0; i < 96; i++)
        (tick: i * d ~/ 4, end: (i + 1) * d ~/ 4 - 1, pitch: 60 + i % 5)
    ];
    expect(plan(fast, harmony), fast.map((n) => n.pitch));
  });
}
