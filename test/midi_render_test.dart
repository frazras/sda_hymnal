import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/midi_file.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/style_arranger.dart';

void main() {
  final hymn = File('assets/midi/016.mid').readAsBytesSync();

  test('every bundled original remains a complete, byte-identical classic MIDI',
      () {
    final files = Directory('assets/midi')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.mid'))
        .toList();
    expect(files.length, greaterThan(600));
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      expect(midiTrackChunks(bytes), isNotEmpty, reason: file.path);
      expect(renderHymnMidi(bytes), bytes, reason: file.path);
      expect(renderHymnMidi(bytes, forAppleSynth: true), bytes,
          reason: file.path);
    }
  });

  for (final entry in arrangedMidiThemes.entries) {
    test('${entry.key} shares the exact arranger and transposition pipeline',
        () {
      final raw = arrangeStyle(hymn, entry.value.$1);
      final volumes = <int, int>{if (entry.key == 'jazz') 0: 50};
      expect(renderHymnMidi(hymn, theme: entry.key),
          transformMidi(raw, channelVolumes: volumes));
      expect(renderHymnMidi(hymn, theme: entry.key, semitones: 2),
          transformMidi(raw, semitones: 2, channelVolumes: volumes));
      final ios = arrangeStyle(hymn, entry.value.$1,
          channelVolumes:
              entry.key == 'reggae' ? reggaeVolumesForAppleSynth : const {});
      expect(renderHymnMidi(hymn, theme: entry.key, forAppleSynth: true),
          transformMidi(ios, channelVolumes: volumes));
      if (entry.key != 'reggae') expect(ios, raw);
    });
  }

  test('only the iOS reggae piano volume changes from the v22 mix', () {
    expect(reggaeVolumesForAppleSynth,
        {0: 53, 4: 53, 1: 82, 3: 57, 2: 109, 9: 127});
    final legacy = arrangeStyle(hymn, ArrangeStyle.reggae,
        channelVolumes: {...reggaeVolumesForAppleSynth, 1: 41});
    final current = renderHymnMidi(hymn, theme: 'reggae', forAppleSynth: true);
    expect(current.length, legacy.length);
    final differences = [
      for (var i = 0; i < legacy.length; i++)
        if (legacy[i] != current[i]) i
    ];
    expect(differences, hasLength(1));
    final offset = differences.single;
    expect(legacy.sublist(offset - 2, offset + 1), [0xb1, 7, 41]);
    expect(current.sublist(offset - 2, offset + 1), [0xb1, 7, 82]);
  });

  for (final id in ['001', '016', '190']) {
    test('solo keeps conductor and piano bytes, including descant hymn $id',
        () {
      final full = renderHymnMidi(File('assets/midi/$id.mid').readAsBytesSync(),
          theme: 'reggae', forAppleSynth: true);
      final tracks = midiTrackChunks(full);
      final solo = midiTrackChunks(reggaePianoOnlyMidi(full));
      final index = tracks.indexWhere((track) =>
          track.length >= 11 &&
          track[8] == 0 &&
          track[9] == 0xc1 &&
          track[10] == 0);
      expect(index, greaterThan(0));
      if (id == '190') expect(index, 3, reason: 'descant precedes piano');
      expect(solo, hasLength(2));
      expect(solo[0], tracks[0]);
      expect(solo[1], tracks[index]);
    });
  }

  test('rejects incomplete files and soloing a non-piano arrangement', () {
    expect(() => midiTrackChunks(Uint8List(0)), throwsFormatException);
    expect(
        () => midiTrackChunks(Uint8List.sublistView(hymn, 0, hymn.length - 1)),
        throwsFormatException);
    expect(() => reggaePianoOnlyMidi(renderHymnMidi(hymn, theme: 'calypso')),
        throwsFormatException);
  });

  test('plain program remaps and no-harmony fallbacks retain existing behavior',
      () {
    expect(
        renderHymnMidi(hymn, theme: 'organ', forceProgram: 19, semitones: -1),
        transformMidi(hymn, forceProgram: 19, semitones: -1));
    final empty = Uint8List.fromList([
      0x4d,
      0x54,
      0x68,
      0x64,
      0,
      0,
      0,
      6,
      0,
      1,
      0,
      1,
      1,
      0xe0,
      0x4d,
      0x54,
      0x72,
      0x6b,
      0,
      0,
      0,
      4,
      0,
      0xff,
      0x2f,
      0,
    ]);
    for (final entry in arrangedMidiThemes.entries) {
      expect(renderHymnMidi(empty, theme: entry.key, forAppleSynth: true),
          transformMidi(empty, forceProgram: entry.value.$2));
    }
  });
}
