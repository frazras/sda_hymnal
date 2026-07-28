import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_transform.dart';

/// `id` + big-endian length + data — track lengths are computed here so the
/// fixtures below stay in sync automatically.
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
      ..._chunk('MThd', [0x00, 0x01, tracks.length >> 8, tracks.length & 0xFF, 0x00, 0x60]),
      for (final t in tracks) ..._chunk('MTrk', t),
    ]);

// Conductor track: 120bpm, 4/4, key signature C major.
const _conductor = <int>[
  0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, // tempo 120bpm
  0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08, // time sig 4/4
  0x00, 0xFF, 0x59, 0x02, 0x00, 0x00, // key sig: C major
  0x00, 0xFF, 0x2F, 0x00, // end of track
];

/// One block chord: [pitches] on at delta 0, all off a whole note (384 ticks,
/// varlen 0x83 0x00) later, via running status with vel-0 note-ons.
List<int> _wholeNoteChord(List<int> pitches) => [
      0x00, 0x90, pitches.first, 0x64,
      for (final p in pitches.skip(1)) ...[0x00, p, 0x64],
      0x83, 0x00, pitches.first, 0x00,
      for (final p in pitches.skip(1)) ...[0x00, p, 0x00],
    ];

// C-E-G | F-A-C | G-B-D-F | C-E-G, one whole-note chord per 4/4 measure.
final _notes = <int>[
  ..._wholeNoteChord([60, 64, 67]), // C4 E4 G4
  ..._wholeNoteChord([65, 69, 72]), // F4 A4 C5
  ..._wholeNoteChord([55, 59, 62, 65]), // G3 B3 D4 F4
  ..._wholeNoteChord([60, 64, 67]), // C4 E4 G4
  0x00, 0xFF, 0x2F, 0x00, // end of track
];

/// The track's chords as printed labels in the file's own key.
List<String> _labels(ChordTrack track) => [
      for (final c in track.chords) chordLabel(c.rootPc, c.quality, track.key, 0),
    ];

/// Hand-made [beats]-beat chord at 500ms/beat.
ChordEvent _ev(int startMs, int beats, int rootPc, String quality) =>
    ChordEvent(
      startMs: startMs,
      durationMs: beats * 500,
      rootPc: rootPc,
      quality: quality,
      beatMs: [for (var b = 0; b < beats; b++) startMs + b * 500],
    );

/// Wraps hand-made [chords] in a 4/4 track (no key).
ChordTrack _handTrack(List<ChordEvent> chords) => ChordTrack(
      chords: chords,
      key: null,
      beatsPerBar: 4,
      measureStartMs: [0, 2000, 4000, 6000],
    );

int _beatCount(ChordTrack track) =>
    track.chords.fold(0, (sum, c) => sum + c.beatMs.length);

void main() {
  group('detectChords on a synthetic C major progression', () {
    final track = detectChords(_smf([_conductor, _notes]))!;

    test('finds C, F, G7, C with 500ms/beat timings', () {
      expect(track.key!.sf, 0);
      expect(track.beatsPerBar, 4);
      expect(_labels(track), ['C', 'F', 'G7', 'C']);
      expect([for (final c in track.chords) c.rootPc], [0, 5, 7, 0]);
      expect([for (final c in track.chords) c.quality], ['', '', '7', '']);
      expect([for (final c in track.chords) c.startMs], [0, 2000, 4000, 6000]);
      expect([for (final c in track.chords) c.durationMs],
          [2000, 2000, 2000, 2000]);
    });

    test('lays measures out every 4 beats', () {
      expect(track.measureStartMs, [0, 2000, 4000, 6000]);
    });

    test('carries every beat onset of each held chord', () {
      // Whole-note chords at 120bpm: four 500ms beats each, the first onset
      // being the chord's own startMs.
      expect([for (final c in track.chords) c.beatMs], [
        [0, 500, 1000, 1500],
        [2000, 2500, 3000, 3500],
        [4000, 4500, 5000, 5500],
        [6000, 6500, 7000, 7500],
      ]);
    });

    test('indexAt returns the last chord at or before the position', () {
      expect(track.indexAt(-1), -1);
      expect(track.indexAt(0), 0);
      expect(track.indexAt(1999), 0);
      expect(track.indexAt(2000), 1);
      expect(track.indexAt(4500), 2);
      expect(track.indexAt(6000), 3);
      expect(track.indexAt(999999), 3);
    });

    test('measureAt mirrors indexAt for measure starts', () {
      expect(track.measureAt(-5), -1);
      expect(track.measureAt(0), 0);
      expect(track.measureAt(3999), 1);
      expect(track.measureAt(4000), 2);
      expect(track.measureAt(80000), 3);
    });
  });

  group('detectChords rejects unusable input', () {
    test('returns null for non-MIDI bytes', () {
      expect(detectChords(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('returns null for a file without notes', () {
      expect(detectChords(_smf([_conductor])), isNull);
    });
  });

  group('chordLabel', () {
    test('spells by the (transposed) key', () {
      expect(chordLabel(10, '', const MidiKey(-1), 0), 'Bb'); // F major: flats
      expect(chordLabel(10, '', const MidiKey(-1), 2), 'C'); // pc 10 + 2 in G
      expect(chordLabel(6, '', const MidiKey(-1), 2), 'G#'); // G major: sharps
      expect(chordLabel(9, '', const MidiKey(0), 1), 'Bb'); // C + 1 = Db: flats
      expect(chordLabel(10, '', null, 0), 'A#'); // no key: sharps
    });

    test('appends the quality suffix verbatim', () {
      expect(chordLabel(4, 'm', const MidiKey(1), 0), 'Em');
      expect(chordLabel(2, '7', const MidiKey(1), 0), 'D7');
      expect(chordLabel(6, 'm7', const MidiKey(2), 0), 'F#m7');
      expect(chordLabel(10, 'maj7', const MidiKey(-2), 0), 'Bbmaj7');
    });
  });

  group('simplifyTrack simple', () {
    // One event per quality, two beats each.
    final track = _handTrack([
      _ev(0, 2, 0, ''), // C
      _ev(1000, 2, 0, 'maj7'), // Cmaj7
      _ev(2000, 2, 0, '7'), // C7
      _ev(3000, 2, 0, 'sus4'), // Csus4
      _ev(4000, 2, 0, 'aug'), // Caug
      _ev(5000, 2, 9, 'm'), // Am
      _ev(6000, 2, 9, 'm7'), // Am7
      _ev(7000, 2, 11, 'dim'), // Bdim
    ]);

    test('original returns the track unchanged', () {
      expect(simplifyTrack(track, ChordLevel.original), same(track));
    });

    test('reduces every quality to major or minor and merges the runs', () {
      final simple = simplifyTrack(track, ChordLevel.simple);
      expect([for (final c in simple.chords) (c.rootPc, c.quality)], [
        (0, ''), // C..Caug: one C spanning all five
        (9, 'm'), // Am + Am7
        (7, ''), // Bdim stands for the G it implies
      ]);
      expect(simple.chords.first.startMs, 0);
      expect(simple.chords.first.durationMs, 5000);
      expect(simple.chords.first.beatMs,
          [for (var ms = 0; ms < 5000; ms += 500) ms]);
      expect(simple.chords[1].startMs, 5000);
      expect(simple.chords[1].durationMs, 2000);
      expect(simple.chords.last.startMs, 7000);
      expect(simple.chords.last.beatMs, [7000, 7500]);
      expect(simple.key, track.key);
      expect(simple.beatsPerBar, track.beatsPerBar);
      expect(simple.measureStartMs, track.measureStartMs);
    });

    test('dim stands for its dominant: the root drops a major third', () {
      final dims = _handTrack([
        _ev(0, 4, 4, 'dim'), // Edim
        _ev(2000, 2, 11, 'dim'), // Bdim
        _ev(3000, 2, 6, 'dim'), // F#dim
      ]);
      final simple = simplifyTrack(dims, ChordLevel.simple);
      expect([for (final c in simple.chords) (c.rootPc, c.quality)],
          [(0, ''), (7, ''), (2, '')]); // C, G, D — never Em/Bm/F#m
      expect(simple.chords.first.beatMs, [0, 500, 1000, 1500]);
    });

    test('never absorbs a held chord: F, Fmaj7, Dm keeps the Dm', () {
      // One beat each: rapid changes between easy chords are fine — a wrong
      // chord held over a real harmony is not.
      final quick = _handTrack([
        _ev(0, 1, 5, ''), // F
        _ev(500, 1, 5, 'maj7'), // Fmaj7
        _ev(1000, 1, 2, 'm'), // Dm
      ]);
      final simple = simplifyTrack(quick, ChordLevel.simple);
      expect([for (final c in simple.chords) (c.rootPc, c.quality)],
          [(5, ''), (2, 'm')]);
      expect(simple.chords.first.beatMs, [0, 500]);
      expect(simple.chords.last.beatMs, [1000]);
    });

    test('conserves every beat and keeps merged onsets ordered', () {
      for (final level in ChordLevel.values) {
        final simplified = simplifyTrack(track, level);
        expect(_beatCount(simplified), _beatCount(track));
        for (final c in simplified.chords) {
          expect(c.beatMs.first, c.startMs);
          for (var k = 1; k < c.beatMs.length; k++) {
            expect(c.beatMs[k], greaterThan(c.beatMs[k - 1]));
          }
        }
      }
    });

    test('leaves the input track untouched', () {
      simplifyTrack(track, ChordLevel.simple);
      simplifyTrack(track, ChordLevel.medium);
      expect([for (final c in track.chords) c.quality],
          ['', 'maj7', '7', 'sus4', 'aug', 'm', 'm7', 'dim']);
      expect([for (final c in track.chords) c.rootPc],
          [0, 0, 0, 0, 0, 9, 9, 11]);
      expect([for (final c in track.chords) c.beatMs.length],
          everyElement(2));
    });
  });

  group('simplifyTrack medium', () {
    List<(int, String)> reduced(List<ChordEvent> chords) => [
          for (final c
              in simplifyTrack(_handTrack(chords), ChordLevel.medium).chords)
            (c.rootPc, c.quality),
        ];

    test('keeps a 7 that resolves a fourth up', () {
      expect(
          reduced([
            _ev(0, 2, 0, '7'), // C7
            _ev(1000, 2, 5, ''), // F: the I of C7's V7-I motion
          ]),
          [(0, '7'), (5, '')]);
    });

    test('drops a non-resolving 7 to major', () {
      expect(
          reduced([
            _ev(0, 2, 0, '7'), // C7
            _ev(1000, 2, 7, ''), // G: no resolution
          ]),
          [(0, ''), (7, '')]);
    });

    test('drops a track-final 7 to major', () {
      expect(reduced([_ev(0, 2, 0, '7')]), [(0, '')]);
    });

    test('dim becomes the dominant 7 it stands for when that resolves', () {
      expect(
          reduced([
            _ev(0, 2, 11, 'dim'), // Bdim
            _ev(1000, 2, 0, ''), // C: G7 -> C resolves
          ]),
          [(7, '7'), (0, '')]);
    });

    test('dim becomes the plain dominant when there is no resolution', () {
      expect(
          reduced([
            _ev(0, 2, 11, 'dim'), // Bdim
            _ev(1000, 2, 2, ''), // D: G7 -> D would not resolve
          ]),
          [(7, ''), (2, '')]);
    });

    test('drops colour tones to their triads and merges the runs', () {
      expect(
          reduced([
            _ev(0, 2, 0, 'maj7'), // Cmaj7
            _ev(1000, 2, 0, 'sus4'), // Csus4
            _ev(2000, 2, 0, 'aug'), // Caug
            _ev(3000, 2, 9, 'm'), // Am
            _ev(4000, 2, 9, 'm7'), // Am7
          ]),
          [(0, ''), (9, 'm')]);
    });
  });

  group('real hymn assets/midi/016.mid', () {
    final track = detectChords(
        Uint8List.fromList(File('assets/midi/016.mid').readAsBytesSync()))!;

    test('reads the written key and meter', () {
      expect(track.key!.sf, 1); // G major
      expect(track.beatsPerBar, 4);
    });

    test('opens on G major harmony and closes on G', () {
      final labels = _labels(track);
      expect(labels.take(8), containsAll(['G', 'D', 'Em']));
      expect(labels.last, 'G');
    });

    test('every chord carries ordered beat onsets within its span', () {
      for (final c in track.chords) {
        expect(c.beatMs, isNotEmpty);
        expect(c.beatMs.first, c.startMs);
        for (var k = 1; k < c.beatMs.length; k++) {
          expect(c.beatMs[k], greaterThan(c.beatMs[k - 1]));
        }
        expect(c.beatMs.last, lessThan(c.startMs + c.durationMs));
      }
    });

    test('chords and measures are chronological and searchable', () {
      final starts = [for (final c in track.chords) c.startMs];
      expect(starts, isNotEmpty);
      for (var i = 1; i < starts.length; i++) {
        expect(starts[i], greaterThan(starts[i - 1]));
      }
      expect(track.indexAt(starts.last), track.chords.length - 1);
      expect(track.measureAt(-1), -1);
      expect(track.measureStartMs.first, 0);
    });

    test('simplified to simple: fewer events, only major/minor, same beats',
        () {
      final simple = simplifyTrack(track, ChordLevel.simple);
      expect(simple.chords.length, lessThan(track.chords.length));
      for (final c in simple.chords) {
        expect(c.quality, anyOf('', 'm'));
      }
      expect(_beatCount(simple), _beatCount(track));
    });

    test('simplified to medium: sits strictly between simple and original',
        () {
      final simple = simplifyTrack(track, ChordLevel.simple);
      final medium = simplifyTrack(track, ChordLevel.medium);
      // Medium is a real level of its own: it drops colour tones the
      // original carries but keeps the resolving dominants simple flattens.
      expect(_labels(medium), isNot(equals(_labels(track))));
      expect(_labels(medium), isNot(equals(_labels(simple))));
      expect(medium.chords.length,
          inExclusiveRange(simple.chords.length, track.chords.length));
      for (final c in medium.chords) {
        expect(c.quality, anyOf('', 'm', '7'));
      }
      expect(medium.chords.any((c) => c.quality == '7'), isTrue);
      expect(_beatCount(medium), _beatCount(track));
    });
  });

  group('real hymn assets/midi/001.mid', () {
    final track = detectChords(
        Uint8List.fromList(File('assets/midi/001.mid').readAsBytesSync()))!;

    test('reads the written key and meter', () {
      expect(track.key!.sf, -1); // F major
      expect(track.beatsPerBar, 3);
    });

    test('opens and closes on F with Bb and C7 inside', () {
      final labels = _labels(track);
      expect(labels.first, 'F');
      expect(labels, contains('Bb'));
      expect(labels, contains('C7'));
      expect(labels.last, 'F');
    });
  });
}
