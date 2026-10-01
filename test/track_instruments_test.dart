import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/services/midi_file.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/music_options.dart';

Uint8List file(List<List<int>> tracks) => Uint8List.fromList([
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
      for (final track in tracks) ...[
        77,
        84,
        114,
        107,
        0,
        0,
        0,
        track.length,
        ...track
      ],
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'shared channel instruments stay independent and preserve controller timing',
      () {
    final source = file([
      [0, 0xc0, 19, 0, 0xb0, 0, 8, 0, 0xb0, 7, 80, 0, 0xff, 0x2f, 0],
      [0, 0x90, 72, 100, 96, 72, 0, 0, 0xff, 0x2f, 0],
      [0, 0x90, 48, 100, 48, 0xb0, 64, 127, 48, 0x80, 48, 0, 0, 0xff, 0x2f, 0],
    ]);
    final result = instrumentMidiParts(source, {1: 0, 2: 42});
    final stats = channelStats(result);
    expect(stats.keys, unorderedEquals([1, 2]));
    expect(stats[1]?.avgPitch, 72);
    expect(stats[2]?.avgPitch, 48);
    final tracks = midiTrackChunks(result);
    expect(
        tracks[0],
        containsAllInOrder(
            [0xc1, 0, 0, 0xb2, 0, 0, 0, 0xb2, 32, 0, 0, 0xc2, 42]));
    // Source bank/program changes cannot override either selected GM instrument.
    expect(tracks[0], containsAllInOrder([0xc0, 19, 0, 0xc1, 0, 0, 0xc2, 42]));
    expect(
        tracks[2],
        containsAllInOrder(
            [48, 0xb0, 64, 127, 0, 0xb1, 64, 127, 0, 0xb2, 64, 127]));
    expect(readMidiDuration(result), readMidiDuration(source));
  });
  test('one override leaves the other shared track on its original channel',
      () {
    final source = file([
      [0, 0xc0, 19, 0, 0x90, 72, 100, 96, 72, 0, 0, 0xff, 0x2f, 0],
      [0, 0x90, 48, 100, 96, 48, 0, 0, 0xff, 0x2f, 0],
    ]);
    final result = instrumentMidiParts(source, {1: 42});
    expect(channelStats(result)[0]?.avgPitch, 72);
    expect(channelStats(result)[1]?.avgPitch, 48);
    expect(instrumentMidiParts(source, {}), source);
  });
  test('real Old Hymnal parts use selected instruments with transpose and solo',
      () {
    final source = File('assets/midi/C001.mid').readAsBytesSync();
    final changed = instrumentMidiParts(source, {1: 0, 4: 42});
    expect(channelStats(changed), channelStats(source));
    expect(readMidiDuration(changed), readMidiDuration(source));
    final result = renderHymnMidi(source,
        theme: 'reggae',
        choirPractice: true,
        trackPrograms: {1: 0, 4: 42},
        mutedTracks: {1, 2, 3},
        semitones: 2);
    expect(midiParts(result).map((p) => p.name), ['Bass']);
    expect(
        result, transformMidi(mixMidiParts(changed, {1, 2, 3}), semitones: 2));
    expect(renderHymnMidi(source, trackPrograms: {4: 42}), source,
        reason: 'Practice choices must not affect full ensemble playback');
  });
  test('percussion is unchanged and unavailable channel capacity is explicit',
      () {
    final source = file([
      [0, 0x99, 36, 100, 96, 36, 0, 0, 0xff, 0x2f, 0],
      [0, 0x90, 60, 100, 96, 60, 0, 0, 0xff, 0x2f, 0],
    ]);
    expect(midiTrackChunks(instrumentMidiParts(source, {1: 42}))[0].sublist(19),
        [0, 0x99, 36, 100, 96, 0x99, 36, 0, 0, 0xff, 0x2f, 0]);
    expect(() => instrumentMidiParts(source, {0: 42}), throwsFormatException);
    final full = file([
      for (var ch = 0; ch < 16; ch++)
        [0, 0x90 | ch, 60, 100, 96, 60, 0, 0, 0xff, 0x2f, 0],
      [0, 0x90, 72, 100, 96, 72, 0, 0, 0xff, 0x2f, 0],
    ]);
    expect(() => instrumentMidiParts(full, {16: 42}), throwsFormatException);
  });
  test('track choices persist per hymn independently of ensemble preferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final options = MusicOptions.instance;
    await options.load();
    await options.setTrackProgram('old:1', 1, 0);
    await options.setTrackProgram('old:1', 4, 42);
    await options.setTrackProgram('new:1', 4, 40);
    await options.load();
    expect(options.trackPrograms('old:1'), {1: 0, 4: 42});
    expect(options.trackPrograms('new:1'), {4: 40});
    expect(options.customInstruments, false);
    await options.setTrackProgram('old:1', 4, null);
    expect(options.trackPrograms('old:1'), {1: 0});
    expect(options.trackPrograms('new:1'), {4: 40});
  });

  test('ensemble role volume and solo alter regular style playback', () {
    final bytes = File('assets/midi/016.mid').readAsBytesSync();
    final full = renderHymnMidi(bytes, theme: 'gospel');
    final quiet =
        renderHymnMidi(bytes, theme: 'gospel', channelVolumes: {2: 30});
    final solo =
        renderHymnMidi(bytes, theme: 'gospel', mutedChannels: {0, 1, 2, 3, 4});
    expect(readMidiDuration(quiet), readMidiDuration(full));
    expect(channelStats(quiet).keys, channelStats(full).keys);
    expect(quiet, isNot(full));
    expect(solo, isNot(full));
  });
}
