import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/instrument_catalog.dart';

Uint8List midi(List<List<int>> tracks) => Uint8List.fromList([
      77,
      84,
      104,
      100,
      0,
      0,
      0,
      6,
      0,
      1,
      0,
      tracks.length,
      0,
      96,
      for (final t in tracks) ...[77, 84, 114, 107, 0, 0, 0, t.length, ...t],
    ]);
List<int> note({int program = 114, int length = 96, int channel = 0}) => [
      0,
      0xc0 | channel,
      program,
      0,
      0x90 | channel,
      60,
      100,
      length,
      60,
      0,
      0,
      0xff,
      0x2f,
      0,
    ];
void main() {
  test(
      'zero ensemble volume silences regular playback without a program override',
      () {
    final source = midi([note(program: 0)]);
    expect(
        channelStats(renderHymnMidi(source, channelVolumes: {0: 0})), isEmpty);
  });
  test('long steelpan notes roll while preserving pitch and duration', () {
    final source = midi([note()]);
    final rolled = steelpanRolls(source);
    expect(channelStats(rolled)[0]?.notes, 3);
    expect(channelStats(rolled)[0]?.avgPitch, 60);
    expect(readMidiDuration(rolled), readMidiDuration(source));
  });
  test('short notes, other instruments and percussion channel stay identical',
      () {
    for (final track in [
      note(length: 24),
      note(program: 0),
      note(program: 42),
      note(channel: 9)
    ]) {
      final source = midi([track]);
      expect(steelpanRolls(source), source);
    }
  });
  test('roll spacing follows tempo changes from the conductor track', () {
    final source = midi([
      [48, 0xff, 0x51, 3, 0x0f, 0x42, 0x40, 48, 0xff, 0x2f, 0],
      note(),
    ]);
    final rolled = steelpanRolls(source);
    expect(channelStats(rolled)[0]?.notes, 5);
    expect(readMidiDuration(rolled), const Duration(milliseconds: 750));
  });
  test('overlapping shared-channel unisons and program changes are left alone',
      () {
    final overlap = midi([
      note(),
      [0, 0x90, 60, 90, 96, 60, 0, 0, 0xff, 0x2f, 0]
    ]);
    expect(steelpanRolls(overlap), overlap);
    final changed = midi([
      [
        0,
        0xc0,
        114,
        0,
        0x90,
        60,
        100,
        48,
        0xc0,
        0,
        48,
        0x80,
        60,
        0,
        0,
        0xff,
        0x2f,
        0
      ]
    ]);
    expect(steelpanRolls(changed), changed);
  });
  test('chords roll independently and retain final note boundaries', () {
    final source = midi([
      [
        0,
        0xc0,
        114,
        0,
        0x90,
        60,
        100,
        0,
        64,
        100,
        96,
        60,
        0,
        0,
        64,
        0,
        0,
        0xff,
        0x2f,
        0
      ]
    ]);
    final rolled = steelpanRolls(source);
    expect(channelStats(rolled)[0]?.notes, 6);
    expect(channelStats(rolled)[0]?.avgPitch, 62);
    expect(readMidiDuration(rolled), readMidiDuration(source));
  });
  test('assignment enables rolls in ensemble and choir, muting removes them',
      () {
    final source = midi([note(program: 0)]);
    expect(
        channelStats(renderHymnMidi(source, channelPrograms: {0: 114}))[0]
            ?.notes,
        3);
    expect(
        channelStats(renderHymnMidi(source,
                choirPractice: true, trackPrograms: {0: 114}))[0]
            ?.notes,
        3);
    expect(
        channelStats(renderHymnMidi(source,
            choirPractice: true, trackPrograms: {0: 114}, mutedTracks: {0})),
        isEmpty);
    expect(
        channelStats(renderHymnMidi(source,
            choirPractice: true,
            trackPrograms: {0: 114},
            trackVolumes: {0: 0})),
        isEmpty);
  });
  test('catalog has unique standard programs and steelpan is percussion', () {
    expect(instrumentCategories['Percussion']?[114], 'Steelpan');
    expect(instrumentNames.length, 111);
    expect(instrumentCategories.values.expand((g) => g.keys).length,
        instrumentNames.length);
    expect(instrumentNames.keys.every((p) => p >= 0 && p < 128), isTrue);
  });
}
