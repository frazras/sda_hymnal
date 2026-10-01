import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/services/midi_transform.dart';

/// `id` + big-endian length + data — track lengths are computed here so the
/// expected fixtures below stay in sync automatically.
List<int> _chunk(String id, List<int> data) => [
      ...id.codeUnits,
      (data.length >> 24) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
      ...data,
    ];

/// Format-1 SMF, division 96 ticks/quarter.
Uint8List _smf(List<List<int>> tracks) => Uint8List.fromList([
      ..._chunk('MThd',
          [0x00, 0x01, tracks.length >> 8, tracks.length & 0xFF, 0x00, 0x60]),
      for (final t in tracks) ..._chunk('MTrk', t),
    ]);

// Conductor track: tempo + key signature F major (sf = -1).
const _conductor = <int>[
  0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, // tempo 120bpm
  0x00, 0xFF, 0x59, 0x02, 0xFF, 0x00, // key sig: 1 flat, major
  0x00, 0xFF, 0x2F, 0x00, // end of track
];

// Note track: PC + notes on ch0 (running status), a bare ch1 (no PC), and
// percussion ch9 with its own PC. Note-offs are vel-0 note-ons via running
// status, so the transposer must resolve running status to touch them.
const _notes = <int>[
  0x00, 0xC0, 0x00, // program change ch0 -> 0
  0x00, 0x90, 0x3C, 0x64, // note on ch0, note 60
  0x60, 0x3C, 0x00, // running status: note 60 off
  0x00, 0x7E, 0x64, // running status: note 126 on (clamp fodder)
  0x60, 0x7E, 0x00, // running status: note 126 off
  0x00, 0x91, 0x3E, 0x5A, // note on ch1, note 62 — ch1 has no PC
  0x60, 0x3E, 0x00, // running status: note 62 off
  0x00, 0xC9, 0x30, // program change ch9 (percussion) -> 48
  0x00, 0x99, 0x24, 0x64, // note on ch9, note 36
  0x60, 0x24, 0x00, // running status: note 36 off
  0x00, 0xFF, 0x2F, 0x00, // end of track
];

// _smf([_conductor, _notes]) after semitones: 2, forceProgram: 19.
const _conductorUp2 = <int>[
  0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
  0x00, 0xFF, 0x59, 0x02, 0x01, 0x00, // F major -> G major (1 sharp)
  0x00, 0xFF, 0x2F, 0x00,
];
const _notesUp2Program19 = <int>[
  0x00, 0xC1, 0x13, // inserted: ch1 had notes but no PC
  0x00, 0xC0, 0x13, // ch0 PC rewritten to 19
  0x00, 0x90, 0x3E, 0x64, // 60 -> 62
  0x60, 0x3E, 0x00, // running status preserved
  0x00, 0x7F, 0x64, // 126 + 2 clamps to 127
  0x60, 0x7F, 0x00,
  0x00, 0x91, 0x40, 0x5A, // 62 -> 64
  0x60, 0x40, 0x00,
  0x00, 0xC9, 0x30, // percussion PC untouched
  0x00, 0x99, 0x24, 0x64, // percussion note untouched
  0x60, 0x24, 0x00,
  0x00, 0xFF, 0x2F, 0x00,
];

// _smf([_conductor, _notes]) after semitones: -100 (clamps to 0).
const _conductorDown100 = <int>[
  0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
  0x00, 0xFF, 0x59, 0x02, 0xFB, 0x00, // F -> Db (5 flats)
  0x00, 0xFF, 0x2F, 0x00,
];
const _notesDown100 = <int>[
  0x00, 0xC0, 0x00, // no forceProgram: PC untouched
  0x00, 0x90, 0x00, 0x64, // 60 - 100 clamps to 0
  0x60, 0x00, 0x00,
  0x00, 0x1A, 0x64, // 126 - 100 = 26
  0x60, 0x1A, 0x00,
  0x00, 0x91, 0x00, 0x5A, // 62 - 100 clamps to 0
  0x60, 0x00, 0x00,
  0x00, 0xC9, 0x30,
  0x00, 0x99, 0x24, 0x64, // percussion untouched
  0x60, 0x24, 0x00,
  0x00, 0xFF, 0x2F, 0x00,
];

void main() {
  test('percussion volume and mute change velocity without changing drum keys',
      () {
    final input = _smf([_conductor, _notes]);
    for (final volume in [0, 35, 100]) {
      final expected = [..._notes];
      expected[expected.indexOf(0x99) + 2] = volume;
      expect(transformMidi(input, channelVolumes: {9: volume}),
          _smf([_conductor, expected]));
    }
    final muted = [..._notes];
    muted[muted.indexOf(0x99) + 2] = 0;
    expect(transformMidi(input, mutedChannels: {9}), _smf([_conductor, muted]));
  });

  final input = _smf([_conductor, _notes]);

  group('MIDI duration', () {
    test('counts all tracks including percussion and running status', () {
      expect(readMidiDuration(input), const Duration(seconds: 2));
    });

    test('uses default tempo and includes the trailing rest at end of track',
        () {
      expect(
          readMidiDuration(_smf([
            [0x60, 0xff, 0x2f, 0],
            [0x81, 0x40, 0xff, 0x2f, 0], // 192 ticks, no notes
          ])),
          const Duration(seconds: 1));
    });

    test('integrates tempo changes in absolute time across tracks', () {
      final bytes = _smf([
        [0x60, 0xff, 0x51, 3, 0x0f, 0x42, 0x40, 0, 0xff, 0x2f, 0],
        [0, 0xff, 0x51, 3, 0x07, 0xa1, 0x20, 0x81, 0x40, 0xff, 0x2f, 0],
      ]);
      // First quarter at 120 BPM, second at 60 BPM.
      expect(readMidiDuration(bytes), const Duration(milliseconds: 1500));
    });

    test('supports format 0 and rejects malformed/unsupported timing', () {
      final single = _smf([_notes])..[9] = 0;
      expect(readMidiDuration(single), const Duration(seconds: 2));
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList(input.sublist(0, input.length - 1)),
        Uint8List.fromList(input)..[9] = 2,
        Uint8List.fromList(input)..[12] = 0xe7,
        Uint8List.fromList(input)..[13] = 0,
        Uint8List.fromList(input)..[11] = 3,
        _smf([
          [0, 0xff, 0x51, 3, 0, 0, 0]
        ]),
      ]) {
        expect(() => readMidiDuration(bytes), throwsFormatException);
      }
    });

    test('both complete hymnals have a usable full-song duration', () {
      final files = Directory('assets/midi')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.mid'))
          .toList();
      final names = {for (final file in files) file.uri.pathSegments.last};
      final expected = {
        for (var n = 1; n <= 695; n++) '${n.toString().padLeft(3, '0')}.mid',
        for (var n = 1; n <= 703; n++) 'C${n.toString().padLeft(3, '0')}.mid',
      };
      expect(names, expected);
      for (final file in files) {
        expect(readMidiDuration(file.readAsBytesSync()),
            greaterThan(Duration.zero),
            reason: file.path);
      }
    });
  });

  group('MidiKey.label', () {
    test('major keys map sf to circle-of-fifths names', () {
      expect(const MidiKey(0).label, 'C');
      expect(const MidiKey(1).label, 'G');
      expect(const MidiKey(4).label, 'E');
      expect(const MidiKey(6).label, 'F#');
      expect(const MidiKey(7).label, 'C#');
      expect(const MidiKey(-1).label, 'F');
      expect(const MidiKey(-2).label, 'Bb');
      expect(const MidiKey(-5).label, 'Db');
      expect(const MidiKey(-7).label, 'Cb');
    });

    test('minor keys use the relative-minor tonic with m suffix', () {
      expect(const MidiKey(0, minor: true).label, 'Am');
      expect(const MidiKey(1, minor: true).label, 'Em');
      expect(const MidiKey(4, minor: true).label, 'C#m');
      expect(const MidiKey(-1, minor: true).label, 'Dm');
      expect(const MidiKey(-5, minor: true).label, 'Bbm');
      expect(const MidiKey(-7, minor: true).label, 'Abm');
    });
  });

  group('transposedKeyLabel', () {
    test('semitones 0 keeps the original spelling', () {
      expect(transposedKeyLabel(const MidiKey(6), 0), 'F#');
      expect(transposedKeyLabel(const MidiKey(-1, minor: true), 0), 'Dm');
    });

    test('shifts the tonic, preferring flat spellings', () {
      expect(transposedKeyLabel(const MidiKey(-1), 2), 'G'); // F + 2
      expect(transposedKeyLabel(const MidiKey(0), 1), 'Db'); // C + 1
      expect(transposedKeyLabel(const MidiKey(0), -1), 'B'); // C - 1
      expect(transposedKeyLabel(const MidiKey(6), 12), 'Gb'); // flat respelling
      expect(transposedKeyLabel(const MidiKey(0, minor: true), 3), 'Cm');
      expect(transposedKeyLabel(const MidiKey(1, minor: true), -2), 'Dm');
    });
  });

  group('readKeySignature', () {
    test('finds the first FF 59 event', () {
      final key = readKeySignature(input);
      expect(key, isNotNull);
      expect(key!.sf, -1);
      expect(key.minor, isFalse);
      expect(key.label, 'F');
    });

    test('returns null when the file has no key signature', () {
      expect(readKeySignature(_smf([_notes])), isNull);
    });

    test('returns null for non-MIDI bytes', () {
      expect(readKeySignature(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('transformMidi', () {
    test('no-op transform is byte-identical', () {
      expect(transformMidi(input), equals(input));
    });

    test('transposes, clamps, rewrites and inserts PCs, updates key sig', () {
      final out = transformMidi(input, semitones: 2, forceProgram: 19);
      expect(out, equals(_smf([_conductorUp2, _notesUp2Program19])));
      // Output is a valid SMF again: it re-parses, and a semitones-0
      // round trip through the transformer is byte-identical.
      expect(readKeySignature(out)!.label, 'G');
      expect(transformMidi(out), equals(out));
    });

    test('clamps notes at 0 and leaves percussion alone', () {
      final out = transformMidi(input, semitones: -100);
      expect(out, equals(_smf([_conductorDown100, _notesDown100])));
    });

    test('rejects malformed input', () {
      expect(() => transformMidi(Uint8List.fromList([1, 2, 3])),
          throwsFormatException);
      expect(() => transformMidi(input, forceProgram: 128), throwsRangeError);
    });
  });

  group('real hymn assets/midi/001.mid', () {
    final bytes =
        Uint8List.fromList(File('assets/midi/001.mid').readAsBytesSync());

    test('key signature reads as F major', () {
      final key = readKeySignature(bytes);
      expect(key, isNotNull);
      expect(key!.sf, -1);
      expect(key.minor, isFalse);
      expect(transposedKeyLabel(key, 2), 'G');
    });

    test('transform +2 keeps length, changes notes, round-trips', () {
      final out = transformMidi(bytes, semitones: 2);
      expect(out.length, bytes.length); // no insertions without forceProgram
      expect(out, isNot(equals(bytes)));
      expect(readKeySignature(out)!.sf, 1); // G major
      // Both the input and the transformed output survive a no-op transform
      // unchanged, i.e. the output is a well-formed SMF.
      expect(transformMidi(bytes), equals(bytes));
      expect(transformMidi(out), equals(out));
      // Hymn notes sit well inside 0..127, so -2 undoes +2 exactly.
      expect(transformMidi(out, semitones: -2), equals(bytes));
    });
  });

  group('channelStats and per-channel programs on the real hymn files', () {
    final bytes = File('assets/midi/001.mid').readAsBytesSync();

    test('finds the dedicated bass channel', () {
      final stats = channelStats(Uint8List.fromList(bytes));
      expect(stats.length, 7);
      var bassCh = -1;
      var bass = double.infinity;
      stats.forEach((ch, s) {
        expect(s.notes, greaterThan(0));
        expect(s.avgPitch, inInclusiveRange(30, 75));
        if (s.avgPitch < bass) {
          bass = s.avgPitch;
          bassCh = ch;
        }
      });
      expect(bassCh, 4); // the hymn files carry the bass line on channel 4
      expect(bass, lessThan(45));
    });

    test('channelPrograms rewrites only the mapped channels', () {
      final input = Uint8List.fromList(bytes);
      final mapped = transformMidi(input, channelPrograms: const {4: 33});
      expect(mapped, isNot(equals(input)));
      // Note content is untouched: stats identical before and after.
      expect(channelStats(mapped).toString(), channelStats(input).toString());
      // Unmapped transform at defaults stays byte-identical.
      expect(transformMidi(input), equals(input));
    });

    test('channelPrograms combines with a forceProgram fallback', () {
      final input = Uint8List.fromList(bytes);
      final combined =
          transformMidi(input, forceProgram: 4, channelPrograms: const {4: 33});
      final blanket = transformMidi(input, forceProgram: 4);
      expect(combined, isNot(equals(blanket)));
      expect(channelStats(combined).toString(), channelStats(input).toString());
    });
  });
}
