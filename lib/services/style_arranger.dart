import 'dart:typed_data';

import 'package:sdahymnal/services/chord_detect.dart';

/// Generated-accompaniment engine for the bundled hymn tunes
/// (assets/midi/NNN.mid): keeps the hymn's melody line but replaces the
/// written SATB accompaniment with a style-specific backing driven by the
/// harmony that [detectChords] hears in the original file.
///
/// A style is data plus small hooks: per-meter rhythm patterns (grid offsets,
/// velocities, note lengths), chord-quality-aware voicing tables (a mini
/// note-transposition-table in the arranger-keyboard sense: minor qualities
/// flatten the third, dim/aug adjust the fifth, sevenths carry their seventh),
/// and a per-bar emitter that reads the chord governing each hit's own beat,
/// so mid-bar chord changes re-voice the pattern without re-slicing it.
///
/// De-mechanization is deterministic: velocities are jittered by a small
/// amount derived from an FNV hash of the input bytes plus the bar index and
/// a per-hit slot — never a random source — so two runs are byte-identical.
/// Timing stays quantized (the swing offsets below are structural, not
/// jitter): tick-domain jitter at hymnal divisions is coarse and risks
/// pushing beat-boundary notes across detection windows.
///
/// The output is a fresh format-1 SMF at the original division, with the
/// original tempo/time-signature/key-signature meta events copied into a
/// conductor track, so it plays at the same speed and key as the hymn it
/// replaces.

/// The accompaniment styles the engine can generate.
enum ArrangeStyle {
  /// Modern gospel: Rhodes stabs, finger bass with chromatic walk-ins,
  /// subtle hat/kick/sidestick groove.
  gospel,

  /// Roots reggae, church register: one-drop drums (bar accent on beat 3,
  /// beat 1 kick-free), offbeat guitar skank, drawbar-organ bubble, riff
  /// bass with structural rests. Gentle global swing on the offbeats.
  reggae,

  /// Trinidadian calypso: steel pan melody and offbeat pan strum, calypso
  /// bass on the 3+3+2 tresillo, kit plus an engine room of claves,
  /// maracas and cowbell. Straight sixteenths, no swing.
  calypso,
}

/// MIDI percussion channel (0-based).
const int _percussionChannel = 9;

/// Default tempo (microseconds per quarter note) when a file has no FF 51.
const int _defaultUsPerQuarter = 500000;

// GM programs (0-indexed program-change bytes).
const int _rhodesProgram = 4; // Electric Piano 1
const int _fingerBassProgram = 33; // Electric Bass (finger)
const int _acousticBassProgram = 32; // Acoustic Bass
const int _cleanGuitarProgram = 27; // Electric Guitar (clean)
const int _drawbarOrganProgram = 16; // Drawbar Organ
const int _fluteProgram = 73; // Flute
const int _steelDrumsProgram = 114; // Steel Drums

// GM percussion keys.
const int _kick = 36;
const int _sidestick = 37;
const int _snare = 38;
const int _closedHat = 42;
const int _pedalHat = 44;
const int _openHat = 46;
const int _crash = 49;
const int _tambourine = 54;
const int _cowbell = 56;
const int _maracas = 70;
const int _claves = 75;
const int _triangle = 81;

/// Gospel stab intervals in semitones above the root, per detected chord
/// quality. The root is omitted everywhere — the bass owns it. Colors: every
/// quality gets the 9th; dominant/minor stabs carry their 7th.
///
/// Musical decision: the plain-major stab is 3rd+5th+9th only. An added 6th
/// (the C6/9 sound) is idiomatic gospel, but C6 is pitch-class-identical to
/// Am7, so [detectChords] re-reads every major bar as its relative minor
/// seventh and the arrangement no longer analyzes as the hymn's own
/// progression. v1 keeps the 9th color and leaves the 6th out.
const Map<String, List<int>> _stabIntervals = {
  '': [4, 7, 2], // 3, 5, 9
  'm': [3, 7, 10, 2], // b3, 5, b7, 9
  'm7': [3, 7, 10, 2], // b3, 5, b7, 9
  '7': [4, 10, 2], // 3, b7, 9
  'maj7': [4, 7, 11, 2], // 3, 5, 7, 9
  'dim': [3, 6, 9], // b3, b5, 6 (bb7)
  'sus4': [5, 7, 2], // 4, 5, 9
  'aug': [4, 8, 2], // 3, #5, 9
};

/// Reggae skank / organ-bubble voicings: plain 3–4 note close voicings with
/// the root in (reggae comping is triadic, not rootless — the research's
/// hard avoid-list bans busy chord extensions). Sevenths trade their 5th for
/// the 7th to stay at three notes.
const Map<String, List<int>> _triadIntervals = {
  '': [0, 4, 7],
  'm': [0, 3, 7],
  '7': [0, 4, 10],
  'maj7': [0, 4, 11],
  'm7': [0, 3, 10],
  'dim': [0, 3, 6],
  'sus4': [0, 5, 7],
  'aug': [0, 4, 8],
};

/// Calypso pan-strum double stops (real double-seconds players double-stop,
/// never full chords). Guide tones are 3rd+7th where the quality has a
/// seventh; plain triads use 3rd+5th — the research's 3rd+6th option is
/// pitch-class-ambiguous with the relative minor (same reasoning as the
/// gospel stab's missing 6th) and would break re-detection of the hymn's
/// own progression.
const Map<String, List<int>> _guideTones = {
  '': [4, 7],
  'm': [3, 7],
  '7': [4, 10],
  'maj7': [4, 11],
  'm7': [3, 10],
  'dim': [3, 6],
  'sus4': [5, 7],
  'aug': [4, 8],
};

/// Comp stabs live in this octave band (around middle C).
const int _stabLow = 60;

/// Reggae skank band: top-string voicings, no roots below middle C (64..75).
const int _skankLow = 64;

/// Organ bubble right hand: triads C3–C4 (48..59).
const int _bubbleRhLow = 48;

/// Calypso strum band (60..71 ⊂ the researched G3–E5).
const int _strumLow = 60;

/// Bass notes live in this octave band.
const int _bassLow = 36;

/// One detected chord as it governs a beat.
typedef _Chord = ({int rootPc, String quality});

/// The chord-quality-aware third and fifth (the "mini-NTT"): minor-family
/// qualities flatten the third, sus4 raises it to the fourth, dim/aug bend
/// the fifth.
int _third(String quality) => switch (quality) {
      'm' || 'm7' || 'dim' => 3,
      'sus4' => 5,
      _ => 4,
    };

int _fifth(String quality) => switch (quality) {
      'dim' => 6,
      'aug' => 8,
      _ => 7,
    };

/// Rewrites the hymn SMF in [originalBytes] as a generated arrangement in
/// [style]. All styles share the same skeleton:
///
/// * conductor track — the original tempo (FF 51), time-signature (FF 58)
///   and key-signature (FF 59) meta events, copied verbatim at their ticks;
/// * channel 0 — the melody (the input channel with the highest average
///   pitch), notes copied verbatim on the style's lead instrument with
///   velocities scaled to 0.9 (capped at 112) so the backing sits around it;
/// * style-specific comp/bass/percussion tracks generated bar by bar from
///   the chord detected on each hit's own beat.
///
/// Throws [FormatException] when [originalBytes] is not a well-formed SMF or
/// contains no detectable harmony (the caller falls back to a plain remap).
Uint8List arrangeStyle(Uint8List originalBytes, ArrangeStyle style) {
  final song = _parseSong(originalBytes);
  final chordTrack = detectChords(originalBytes);
  if (chordTrack == null) {
    throw const FormatException('No detectable harmony to arrange');
  }

  final d = song.division; // ticks per beat (quarter note)
  final n = chordTrack.beatsPerBar;
  final tempo = _TempoMap(song.tempi, d);

  // Chord governing each beat index: detection windows start at k*division
  // ticks, so every beatMs maps back onto an exact beat via the tempo map.
  final beatChords = <int, _Chord>{};
  for (final chord in chordTrack.chords) {
    for (final ms in chord.beatMs) {
      final beat = (tempo.tickOf(ms) / d).round();
      beatChords[beat] = (rootPc: chord.rootPc, quality: chord.quality);
    }
  }
  var firstBeat = beatChords.keys.first;
  var lastBeat = firstBeat;
  for (final beat in beatChords.keys) {
    if (beat < firstBeat) firstBeat = beat;
    if (beat > lastBeat) lastBeat = beat;
  }

  // The hymn's opening tempo decides tempo-sensitive pattern choices (the
  // reggae half-time reading); mid-hymn fermata dips don't.
  var usPerQuarter = _defaultUsPerQuarter;
  var tempoTick = -1;
  for (final (tick, us) in song.tempi) {
    if (tempoTick < 0 || tick < tempoTick) {
      tempoTick = tick;
      usPerQuarter = us;
    }
  }

  final ctx = _Ctx(
    d: d,
    n: n,
    beatChords: beatChords,
    firstBeat: firstBeat,
    lastBeat: lastBeat,
    seed: _fnv(originalBytes),
    bpm: 60e6 / usPerQuarter,
  );

  final conductor = _Track();
  for (final (tick, bytes) in song.metas) {
    conductor.meta(tick, bytes);
  }

  final melodyProgram = switch (style) {
    ArrangeStyle.gospel => _rhodesProgram,
    ArrangeStyle.reggae => _fluteProgram,
    ArrangeStyle.calypso => _steelDrumsProgram,
  };
  final melody = _Track()..program(0, 0, melodyProgram);
  for (final note in _melodyNotes(song)) {
    final velocity = (note.velocity * 0.9).round().clamp(1, 112);
    melody.note(note.startTick, 0, note.pitch, velocity,
        note.endTick - note.startTick);
  }

  switch (style) {
    case ArrangeStyle.gospel:
      final comp = _Track()..program(0, 1, _rhodesProgram);
      final bass = _Track()..program(0, 2, _fingerBassProgram);
      final drums = _Track();
      _emitGospel(ctx, comp, bass, drums);
      return _writeSmf(d, [conductor, melody, comp, bass, drums]);
    case ArrangeStyle.reggae:
      final skank = _Track()..program(0, 1, _cleanGuitarProgram);
      final bass = _Track()..program(0, 2, _fingerBassProgram);
      final organ = _Track()..program(0, 3, _drawbarOrganProgram);
      final drums = _Track();
      _emitReggae(ctx, skank, bass, organ, drums);
      return _writeSmf(d, [conductor, melody, skank, bass, organ, drums]);
    case ArrangeStyle.calypso:
      final strum = _Track()..program(0, 1, _steelDrumsProgram);
      final bass = _Track()..program(0, 2, _acousticBassProgram);
      final drums = _Track();
      _emitCalypso(ctx, strum, bass, drums);
      return _writeSmf(d, [conductor, melody, strum, bass, drums]);
  }
}

/// Everything a style emitter needs: the grid, the harmony, the span where
/// harmony exists, and the deterministic humanizer.
class _Ctx {
  _Ctx({
    required this.d,
    required this.n,
    required this.beatChords,
    required this.firstBeat,
    required this.lastBeat,
    required this.seed,
    required this.bpm,
  });

  final int d; // ticks per beat
  final int n; // beats per bar
  final Map<int, _Chord> beatChords;
  final int firstBeat;
  final int lastBeat;
  final int seed;
  final double bpm;

  int get firstBar => firstBeat ~/ n;
  int get lastBar => lastBeat ~/ n;

  _Chord? chordAt(int beat) => beatChords[beat];

  bool inSpan(int beat) => beat >= firstBeat && beat <= lastBeat;

  /// Whether a hit at [offset] ticks into [bar] falls on a beat that carries
  /// harmony — hits outside the harmonized span are dropped.
  bool hit(int bar, int offset) => inSpan(bar * n + offset ~/ d);

  /// [base] velocity jittered by at most ±[range], deterministically from
  /// the song seed, [bar] and a caller-chosen [slot] (unique per pattern
  /// position). MMA-style humanization without a random source.
  int vel(int base, int range, int bar, int slot) {
    if (range == 0) return base;
    var h = seed;
    h = (h ^ bar) * 16777619 & 0x7FFFFFFF;
    h = (h ^ slot) * 16777619 & 0x7FFFFFFF;
    return base + h % (2 * range + 1) - range;
  }
}

/// FNV-1a hash of [bytes], truncated to a positive 31-bit int.
int _fnv(Uint8List bytes) {
  var h = 0x811C9DC5;
  for (final b in bytes) {
    h = (h ^ b) * 16777619 & 0x7FFFFFFF;
  }
  return h;
}

// ---------------------------------------------------------------------------
// Gospel
// ---------------------------------------------------------------------------

/// Modern-gospel backing:
///
/// * channel 1, Rhodes — rootless comp stabs on a beat-1 / off-beat /
///   late-bar pattern, voiced from the chord detected on each stab's beat;
/// * channel 2, Finger Bass — root and quality-aware fifth per bar, with a
///   chromatic approach note walking into every bar that changes chord;
/// * channel 9 — closed hat eighths with kick and sidestick.
///
/// Stab and hat velocities carry a ±3 deterministic jitter; the kick,
/// sidestick and bass anchors stay fixed.
void _emitGospel(_Ctx c, _Track comp, _Track bass, _Track drums) {
  final d = c.d;
  final n = c.n;

  // (offset ticks, velocity, length ticks) per bar.
  final stabHits = n == 3
      ? [(0, 78, d), (3 * d ~/ 2, 64, d ~/ 2), (2 * d, 68, d ~/ 2)]
      : [(0, 78, d), (5 * d ~/ 2, 64, d ~/ 2), (3 * d, 70, d ~/ 2)];
  final kickHits = n == 3 ? [(0, 76)] : [(0, 78), (2 * d, 78)];
  final stickHits = n == 3 ? [(2 * d, 60)] : [(d, 66), (3 * d, 66)];

  for (var bar = c.firstBar; bar <= c.lastBar; bar++) {
    final barStart = bar * n * d;

    // Rhodes stabs: each hit sounds the chord governing its own beat, so a
    // mid-bar chord change (chords are beat-aligned) splits the pattern.
    for (final (i, (offset, velocity, length)) in stabHits.indexed) {
      final chord = c.chordAt(bar * n + offset ~/ d);
      if (chord == null) continue;
      final v = c.vel(velocity, 3, bar, 20 + i);
      for (final pitch in _voice(_stabIntervals, chord, _stabLow)) {
        comp.note(barStart + offset, 1, pitch, v, length);
      }
    }

    // Bass: root on 1, quality-aware fifth on 3, each from the chord on its
    // own beat.
    final rootChord = c.chordAt(bar * n);
    if (rootChord != null) {
      bass.note(barStart, 2, _voiceBass(rootChord.rootPc), 92, 3 * d ~/ 2);
    }
    final fifthChord = c.chordAt(bar * n + 2);
    if (fifthChord != null) {
      bass.note(
          barStart + 2 * d,
          2,
          _voiceBass(fifthChord.rootPc + _fifth(fifthChord.quality)),
          n == 3 ? 76 : 80,
          n == 3 ? d ~/ 2 : d);
    }

    // The classic walk-in: when the next bar opens on a different chord, the
    // last half-beat becomes a chromatic approach from below its root.
    final barEndChord = c.chordAt(bar * n + n - 1);
    final nextChord = c.chordAt((bar + 1) * n);
    if (barEndChord != null && nextChord != null && nextChord != barEndChord) {
      bass.note(barStart + n * d - d ~/ 2, 2,
          _voiceBass(nextChord.rootPc + 11), 84, d ~/ 2);
    }

    // Drums, only where harmony exists: hat eighths plus kick and sidestick.
    for (var k = 0; k < 2 * n; k++) {
      final offset = k * d ~/ 2;
      if (!c.hit(bar, offset)) continue;
      final velocity = n == 3 ? 44 : (k.isEven ? 58 : 46);
      drums.note(barStart + offset, _percussionChannel, _closedHat,
          c.vel(velocity, 3, bar, 40 + k), d ~/ 4);
    }
    for (final (offset, velocity) in kickHits) {
      if (!c.hit(bar, offset)) continue;
      drums.note(barStart + offset, _percussionChannel, _kick, velocity, d ~/ 4);
    }
    for (final (offset, velocity) in stickHits) {
      if (!c.hit(bar, offset)) continue;
      drums.note(
          barStart + offset, _percussionChannel, _sidestick, velocity, d ~/ 4);
    }
  }
}

// ---------------------------------------------------------------------------
// Reggae
// ---------------------------------------------------------------------------

/// Roots-reggae backing in the church register:
///
/// * channel 9 — the one drop: kick + sidestick together on beat 3 and
///   nothing on beat 1 but a pedal hat; closed-hat eighths accented on the
///   swung offbeats, open hat as the bar-end pickup; tambourine on the
///   backbeats; a sidestick fill every 8 bars resolving to a crash on the
///   NEXT bar's beat 3 (never beat 1 — that absence is the genre);
/// * channel 1, clean guitar — the skank: staccato triad stabs on every
///   swung offbeat eighth;
/// * channel 3, drawbar organ — the bubble: low left-hand root dabs on the
///   beats, right-hand triads answering on the swung offbeats;
/// * channel 2, finger bass — riff bass, Pattern A: root long-short on
///   beat 1, beat 2 structurally SILENT, fifth on 3, third on 4 with a
///   chromatic walk into every chord change. The bass anchors the "one" the
///   drums omit.
///
/// Swing: every offbeat eighth (hats, skank, organ RH together — the swing
/// is global) sits at 56.25% of the beat.
///
/// Tempo mapping per the research: at or above ~96 BPM the full-density
/// skank turns ska, so 4/4 hymns faster than that use the half-time reading
/// — skank on beats 2 and 4, bubble on straight offbeats, halved bass — with
/// the drop kept on beat 3. 3/4 hymns get the "reggae waltz": drop on the
/// bar's last beat, skank on the three offbeats.
void _emitReggae(_Ctx c, _Track skank, _Track bass, _Track organ, _Track drums) {
  final d = c.d;
  final n = c.n;
  final waltz = n == 3;
  final halfTime = !waltz && c.bpm >= 96;
  final beats = waltz ? 3 : 4;

  // Swung offbeat of beat [k]: 56.25% of the way to the next beat.
  int sw(int k) => k * d + 9 * d ~/ 16;

  for (var bar = c.firstBar; bar <= c.lastBar; bar++) {
    final barStart = bar * n * d;
    final phase = (bar - c.firstBar) % 8;

    void dnote(int offset, int key, int velocity, [int? length]) {
      if (!c.hit(bar, offset)) return;
      drums.note(barStart + offset, _percussionChannel, key, velocity,
          length ?? d ~/ 4);
    }

    // --- Drums: the one drop -------------------------------------------
    const dropBeat = 2; // beat 3 in both meters (0-based index 2)
    dnote(0, _pedalHat, c.vel(58, 2, bar, 1));
    for (var k = 0; k < beats; k++) {
      dnote(k * d, _closedHat, c.vel(60, 3, bar, 2 + 2 * k));
      final isPickup = k == beats - 1;
      if (isPickup) {
        dnote(sw(k), _openHat, c.vel(88, 3, bar, 3 + 2 * k), d ~/ 3);
      } else {
        dnote(sw(k), _closedHat, c.vel(80, 3, bar, 3 + 2 * k));
      }
    }
    dnote(dropBeat * d, _kick, 105);
    dnote(dropBeat * d, _sidestick, 98);
    // Tambourine backbeat, light — the church signature.
    if (waltz) {
      dnote(d, _tambourine, c.vel(50, 4, bar, 30));
    } else {
      dnote(d, _tambourine, c.vel(50, 4, bar, 30));
      dnote(3 * d, _tambourine, c.vel(50, 4, bar, 31));
    }
    // Fill on the last beat of every 8th bar; crash lands with the NEXT
    // bar's drop, not its downbeat.
    if (phase == 7) {
      final fillBeat = (beats - 1) * d;
      dnote(fillBeat + d ~/ 4, _sidestick, 60);
      dnote(fillBeat + d ~/ 2, _sidestick, 74);
      dnote(fillBeat + 3 * d ~/ 4, _sidestick, 86);
    }
    if (phase == 0 && bar != c.firstBar) {
      dnote(dropBeat * d, _crash, 95, d);
    }

    // --- Skank ----------------------------------------------------------
    // (offset, beat index) pairs for the chop.
    final skankHits = halfTime
        ? [(d, 1), (3 * d, 3)] // half-time: beats 2 and 4, straight
        : [for (var k = 0; k < beats; k++) (sw(k), k)];
    for (final (i, (offset, beat)) in skankHits.indexed) {
      final chord = c.chordAt(bar * n + beat);
      if (chord == null || !c.hit(bar, offset)) continue;
      final v = c.vel(92, 4, bar, 50 + i);
      for (final pitch in _voice(_triadIntervals, chord, _skankLow)) {
        skank.note(barStart + offset, 1, pitch, v, d ~/ 8);
      }
    }

    // --- Organ bubble ---------------------------------------------------
    // LH: single low root dabs on the beats, felt more than heard.
    final lhBeats = halfTime ? [0, 2] : [for (var k = 0; k < beats; k++) k];
    for (final k in lhBeats) {
      final chord = c.chordAt(bar * n + k);
      if (chord == null) continue;
      organ.note(barStart + k * d, 3, _voiceBass(chord.rootPc),
          c.vel(55, 2, bar, 60 + k), d ~/ 4);
    }
    // RH: short triad dabs on the offbeats — swung with the skank, or
    // straight eighth offbeats in the half-time reading. A fat sixteenth
    // (d/3), not d/8: notes covering a quarter-beat or less are invisible
    // to [detectChords], and the bubble is what keeps every harmonized
    // beat window carrying full chord content — without it a melody breath
    // lets the detector extend a neighboring chord across a bar line.
    for (var k = 0; k < beats; k++) {
      final offset = halfTime ? k * d + d ~/ 2 : sw(k);
      final chord = c.chordAt(bar * n + k);
      if (chord == null || !c.hit(bar, offset)) continue;
      final v = c.vel(74, 3, bar, 70 + k);
      for (final pitch in _voice(_triadIntervals, chord, _bubbleRhLow)) {
        organ.note(barStart + offset, 3, pitch, v, d ~/ 3);
      }
    }

    // --- Bass -----------------------------------------------------------
    final c1 = c.chordAt(bar * n);
    final nextChord = c.chordAt((bar + 1) * n);
    if (waltz) {
      if (c1 != null) {
        bass.note(barStart, 2, _voiceBass(c1.rootPc), 104, 6 * d ~/ 5);
      }
      final c3 = c.chordAt(bar * n + 2);
      if (c3 != null) {
        bass.note(barStart + 2 * d, 2,
            _voiceBass(c3.rootPc + _fifth(c3.quality)), 88, d ~/ 2);
        if (nextChord != null && nextChord != c3) {
          bass.note(barStart + 2 * d + d ~/ 2, 2,
              _voiceBass(nextChord.rootPc + 11), 84, 2 * d ~/ 5);
        }
      }
    } else {
      if (c1 != null) {
        // The "doo—doot": dotted-eighth root plus a sixteenth at 1a.
        bass.note(barStart, 2, _voiceBass(c1.rootPc), 106, 3 * d ~/ 5);
        if (!halfTime) {
          bass.note(barStart + 3 * d ~/ 4, 2, _voiceBass(c1.rootPc), 88, d ~/ 8);
        }
      }
      // Beat 2: structurally silent — continuous motion destroys the style.
      final c3 = c.chordAt(bar * n + 2);
      if (c3 != null) {
        bass.note(barStart + 2 * d, 2,
            _voiceBass(c3.rootPc + _fifth(c3.quality)), 96, 4 * d ~/ 5);
      }
      final c4 = c.chordAt(bar * n + 3);
      if (c4 != null) {
        if (!halfTime) {
          bass.note(barStart + 3 * d, 2,
              _voiceBass(c4.rootPc + _third(c4.quality)), 84, 2 * d ~/ 5);
        }
        if (nextChord != null && nextChord != c4) {
          bass.note(barStart + 3 * d + d ~/ 2, 2,
              _voiceBass(nextChord.rootPc + 11), 86, 2 * d ~/ 5);
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Calypso
// ---------------------------------------------------------------------------

/// Steel-pan calypso backing (gospelypso register — dignified, side-stick
/// verses, no power-soca):
///
/// * channel 1, steel drums — the calypso strum: the genre's fingerprint,
///   double stops on the 2nd, 3rd and 4th sixteenth of each beat, RESTING
///   on every downbeat, accents on the "&"s (strongest on 2& and 4&);
/// * channel 2, acoustic bass — tresillo bass: root on 1, fifth on 2&,
///   root on 3, pickup on 4& walking chromatically into chord changes;
/// * channel 9 — kit (syncopated kick 1 / 2& / 3, side-stick backbeat with
///   tambourine, offbeat-accented eighth hats with an open hat on 4& every
///   2nd bar) plus an engine room of claves on the 3+3+2 anchor (1, 2&, 4),
///   running maracas eighths, and a 2-bar cowbell loop; snare pickup fill
///   every 8 bars into a crash on the following downbeat.
///
/// Everything is straight — the lilt comes from velocity shape and the
/// rests on the downbeats, not timing offsets. 3/4 hymns get the Caribbean
/// waltz: strum resting on beat 1 and filling beats 2–3, claves on the
/// 1 / 2& hemiola, triangle color on 2 and 3.
void _emitCalypso(_Ctx c, _Track strum, _Track bass, _Track drums) {
  final d = c.d;
  final n = c.n;
  final waltz = n == 3;

  // Strum velocities per beat, for the 2nd/3rd/4th sixteenth of the beat.
  const strumVels44 = [[70, 85, 72], [70, 88, 72], [70, 85, 72], [70, 90, 75]];
  const strumVels34 = [[70, 85, 72], [70, 85, 72]];

  for (var bar = c.firstBar; bar <= c.lastBar; bar++) {
    final barStart = bar * n * d;
    final phase = (bar - c.firstBar) % 8;
    final evenBar = (bar - c.firstBar) % 2 == 0;

    void dnote(int offset, int key, int velocity, [int? length]) {
      if (!c.hit(bar, offset)) return;
      drums.note(barStart + offset, _percussionChannel, key, velocity,
          length ?? d ~/ 4);
    }

    // --- Strum: rest on the beat, hit every e, &, a ---------------------
    final strumBeats = waltz ? [1, 2] : [0, 1, 2, 3];
    final vels = waltz ? strumVels34 : strumVels44;
    for (final (i, beat) in strumBeats.indexed) {
      final chord = c.chordAt(bar * n + beat);
      if (chord == null) continue;
      for (var sub = 1; sub <= 3; sub++) {
        final offset = beat * d + sub * d ~/ 4;
        if (!c.hit(bar, offset)) continue;
        final v = c.vel(vels[i][sub - 1], 3, bar, 10 + 4 * beat + sub);
        // The accented "&" chop is a fat sixteenth (d/3) so each beat
        // window keeps visible chord content for re-detection (see the
        // organ-bubble note in the reggae emitter); "e" and "a" stay
        // staccato d/8.
        final length = sub == 2 ? d ~/ 3 : d ~/ 8;
        for (final pitch in _voice(_guideTones, chord, _strumLow)) {
          strum.note(barStart + offset, 1, pitch, v, length);
        }
      }
    }

    // --- Bass: tresillo, air on the downbeat's tail ---------------------
    final c1 = c.chordAt(bar * n);
    final nextChord = c.chordAt((bar + 1) * n);
    if (waltz) {
      if (c1 != null) {
        bass.note(barStart, 2, _voiceBass(c1.rootPc), 100, 6 * d ~/ 5);
      }
      final c2 = c.chordAt(bar * n + 1);
      if (c2 != null) {
        bass.note(barStart + d + d ~/ 2, 2,
            _voiceBass(c2.rootPc + _fifth(c2.quality)), 85, 2 * d ~/ 5);
      }
      final c3 = c.chordAt(bar * n + 2);
      if (c3 != null && nextChord != null && nextChord != c3) {
        bass.note(barStart + 2 * d + d ~/ 2, 2,
            _voiceBass(nextChord.rootPc + 11), 82, d ~/ 4);
      }
    } else {
      if (c1 != null) {
        bass.note(barStart, 2, _voiceBass(c1.rootPc), 100, 3 * d ~/ 5);
      }
      final c2 = c.chordAt(bar * n + 1);
      if (c2 != null) {
        bass.note(barStart + d + d ~/ 2, 2,
            _voiceBass(c2.rootPc + _fifth(c2.quality)), 85, 2 * d ~/ 5);
      }
      final c3 = c.chordAt(bar * n + 2);
      if (c3 != null) {
        bass.note(barStart + 2 * d, 2, _voiceBass(c3.rootPc), 92, 4 * d ~/ 5);
      }
      final c4 = c.chordAt(bar * n + 3);
      if (c4 != null) {
        final pickup = nextChord != null && nextChord != c4
            ? nextChord.rootPc + 11 // chromatic approach from below
            : c4.rootPc; // root pickup when the harmony holds
        bass.note(
            barStart + 3 * d + d ~/ 2, 2, _voiceBass(pickup), 85, d ~/ 4);
      }
    }

    // --- Kit ------------------------------------------------------------
    if (waltz) {
      dnote(0, _kick, 100);
      dnote(d + d ~/ 2, _sidestick, 75);
      for (var k = 0; k < 5; k++) {
        dnote(k * d ~/ 2, _closedHat, c.vel(k.isEven ? 55 : 72, 3, bar, 40 + k));
      }
      if (evenBar) {
        dnote(5 * d ~/ 2, _closedHat, c.vel(72, 3, bar, 45));
      } else {
        dnote(5 * d ~/ 2, _openHat, c.vel(78, 3, bar, 45), d ~/ 3);
      }
      dnote(0, _claves, 90);
      dnote(d + d ~/ 2, _claves, 90); // the 3+3 hemiola over the bar
      dnote(d, _triangle, c.vel(55, 3, bar, 46));
      dnote(2 * d, _triangle, c.vel(55, 3, bar, 47));
      for (var k = 0; k < 6; k++) {
        dnote(k * d ~/ 2, _maracas, c.vel(k.isEven ? 55 : 70, 4, bar, 50 + k));
      }
      if (phase == 7) {
        dnote(2 * d + d ~/ 2, _snare, 80);
        dnote(2 * d + 3 * d ~/ 4, _snare, 92);
      }
    } else {
      dnote(0, _kick, 100);
      dnote(d + d ~/ 2, _kick, 85);
      dnote(2 * d, _kick, 95);
      dnote(d, _sidestick, 80);
      dnote(3 * d, _sidestick, 85);
      dnote(d, _tambourine, c.vel(70, 4, bar, 38));
      dnote(3 * d, _tambourine, c.vel(72, 4, bar, 39));
      for (var k = 0; k < 7; k++) {
        dnote(k * d ~/ 2, _closedHat, c.vel(k.isEven ? 60 : 78, 3, bar, 40 + k));
      }
      if (evenBar) {
        dnote(7 * d ~/ 2, _closedHat, c.vel(82, 3, bar, 47));
      } else {
        dnote(7 * d ~/ 2, _openHat, c.vel(82, 3, bar, 47), d ~/ 3);
      }
      // Engine room: claves on the 3+3+2 anchor — 1, 2&, 4.
      dnote(0, _claves, 90);
      dnote(d + d ~/ 2, _claves, 90);
      dnote(3 * d, _claves, 90);
      for (var k = 0; k < 8; k++) {
        dnote(k * d ~/ 2, _maracas, c.vel(k.isEven ? 55 : 70, 4, bar, 50 + k));
      }
      // Cowbell, 2-bar loop.
      if (evenBar) {
        dnote(d ~/ 2, _cowbell, c.vel(78, 3, bar, 60));
        dnote(d + d ~/ 2, _cowbell, c.vel(78, 3, bar, 61));
        dnote(3 * d, _cowbell, c.vel(82, 3, bar, 62));
      } else {
        dnote(d + d ~/ 2, _cowbell, c.vel(78, 3, bar, 60));
        dnote(3 * d, _cowbell, c.vel(82, 3, bar, 61));
        dnote(3 * d + d ~/ 2, _cowbell, c.vel(75, 3, bar, 62));
      }
      if (phase == 7) {
        dnote(3 * d + d ~/ 4, _snare, 70);
        dnote(3 * d + d ~/ 2, _snare, 85);
        dnote(3 * d + 3 * d ~/ 4, _snare, 95);
      }
    }
    if (phase == 0 && bar != c.firstBar) {
      dnote(0, _crash, 95, d);
    }
  }
}

// ---------------------------------------------------------------------------
// Voicing helpers
// ---------------------------------------------------------------------------

/// The [table] tones of [chord], each transposed by octaves into the band
/// starting at [low] (low..low+11), deduplicated, low to high.
List<int> _voice(Map<String, List<int>> table, _Chord chord, int low) {
  final tones = table[chord.quality] ?? table['']!;
  final pitches = <int>{
    for (final interval in tones) low + (chord.rootPc + interval) % 12,
  };
  return pitches.toList()..sort();
}

/// [pitchOrPc] transposed by octaves into the bass band (36..47 ⊂ 36..50).
int _voiceBass(int pitchOrPc) => _bassLow + ((pitchOrPc % 12) + 12) % 12;

/// The notes of the melody channel — the sounding non-percussion channel with
/// the highest average pitch (ties: most notes, then lowest channel number) —
/// in the order they appear in the file.
List<_NoteEvent> _melodyNotes(_Song song) {
  final counts = <int, int>{};
  final sums = <int, int>{};
  for (final note in song.notes) {
    if (note.channel == _percussionChannel) continue;
    counts[note.channel] = (counts[note.channel] ?? 0) + 1;
    sums[note.channel] = (sums[note.channel] ?? 0) + note.pitch;
  }
  if (counts.isEmpty) {
    throw const FormatException('No melody notes to arrange');
  }
  int? melodyChannel;
  for (final channel in counts.keys.toList()..sort()) {
    if (melodyChannel == null) {
      melodyChannel = channel;
      continue;
    }
    final avg = sums[channel]! / counts[channel]!;
    final bestAvg = sums[melodyChannel]! / counts[melodyChannel]!;
    if (avg > bestAvg ||
        (avg == bestAvg && counts[channel]! > counts[melodyChannel]!)) {
      melodyChannel = channel;
    }
  }
  return [
    for (final note in song.notes)
      if (note.channel == melodyChannel) note,
  ];
}

// ---------------------------------------------------------------------------
// SMF writing
// ---------------------------------------------------------------------------

/// One scheduled event: [priority] orders same-tick events (note-offs first so
/// repeated pitches re-strike, then meta, programs, and note-ons); [seq]
/// keeps insertion order among equals, so output is deterministic.
class _Event {
  _Event(this.tick, this.priority, this.seq, this.bytes);

  final int tick;
  final int priority;
  final int seq;
  final List<int> bytes;
}

/// Collects events at absolute ticks and serializes them as one MTrk body
/// with correct variable-length deltas and a closing FF 2F.
class _Track {
  final List<_Event> _events = [];
  int _seq = 0;

  void _add(int tick, int priority, List<int> bytes) =>
      _events.add(_Event(tick, priority, _seq++, bytes));

  /// [bytes] is a complete meta event (0xFF, type, length, payload).
  void meta(int tick, List<int> bytes) => _add(tick, 1, bytes);

  void program(int tick, int channel, int program) =>
      _add(tick, 2, [0xC0 | channel, program]);

  void note(int tick, int channel, int pitch, int velocity, int length) {
    _add(tick, 3, [0x90 | channel, pitch & 0x7F, velocity.clamp(1, 127)]);
    final end = length > 0 ? tick + length : tick + 1;
    _add(end, 0, [0x80 | channel, pitch & 0x7F, 0x40]);
  }

  Uint8List serialize() {
    final sorted = [..._events]..sort((a, b) {
        if (a.tick != b.tick) return a.tick - b.tick;
        if (a.priority != b.priority) return a.priority - b.priority;
        return a.seq - b.seq;
      });
    final out = BytesBuilder(copy: false);
    var at = 0;
    for (final e in sorted) {
      _writeVarLen(out, e.tick - at);
      at = e.tick;
      out.add(e.bytes);
    }
    _writeVarLen(out, 0);
    out.add(const [0xFF, 0x2F, 0x00]); // end of track
    return out.toBytes();
  }
}

/// A fresh format-1 SMF at [division] from the serialized [tracks].
Uint8List _writeSmf(int division, List<_Track> tracks) {
  final out = BytesBuilder(copy: false);
  out.add('MThd'.codeUnits);
  out.add([0, 0, 0, 6, 0, 1, (tracks.length >> 8) & 0xFF, tracks.length & 0xFF]);
  out.add([(division >> 8) & 0xFF, division & 0xFF]);
  for (final track in tracks) {
    final data = track.serialize();
    out.add('MTrk'.codeUnits);
    out.add([
      (data.length >> 24) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
    ]);
    out.add(data);
  }
  return out.toBytes();
}

/// Writes [value] as an SMF variable-length quantity.
void _writeVarLen(BytesBuilder out, int value) {
  assert(value >= 0);
  final bytes = <int>[value & 0x7F];
  var v = value >> 7;
  while (v > 0) {
    bytes.add((v & 0x7F) | 0x80);
    v >>= 7;
  }
  out.add(bytes.reversed.toList());
}

// ---------------------------------------------------------------------------
// SMF parsing (same shapes as midi_transform.dart / chord_detect.dart)
// ---------------------------------------------------------------------------

/// One matched note with absolute ticks.
class _NoteEvent {
  _NoteEvent(this.channel, this.pitch, this.velocity, this.startTick);

  final int channel;
  final int pitch;
  final int velocity;
  final int startTick;
  int endTick = 0;
}

/// Everything [arrangeStyle] needs from the original file.
class _Song {
  _Song(this.division);

  final int division;
  final List<_NoteEvent> notes = [];
  final List<(int tick, int usPerQuarter)> tempi = [];

  /// Tempo/time-signature/key-signature meta events, verbatim, at their ticks.
  final List<(int, Uint8List)> metas = [];
}

/// Parses [bytes], collecting all notes with absolute ticks, the tempo list,
/// and the conductor meta events. Throws [FormatException] on malformed input
/// or an SMPTE-timed file.
_Song _parseSong(Uint8List bytes) {
  final chunks = _readChunks(bytes);
  final header = chunks.firstWhere((c) => c.id == 'MThd',
      orElse: () => throw const FormatException('Missing MThd'));
  if (header.data.length < 6) throw const FormatException('Short MThd');
  final division = (header.data[4] << 8) | header.data[5];
  if (division == 0 || division & 0x8000 != 0) {
    throw const FormatException('Unsupported SMF division');
  }

  final song = _Song(division);
  for (final chunk in chunks) {
    if (chunk.id != 'MTrk') continue;
    var tick = 0;
    final open = <int, List<_NoteEvent>>{}; // channel<<8 | pitch -> open notes
    for (final e in _trackEvents(chunk.data)) {
      tick += e.delta;
      final hi = e.status & 0xF0;
      final ch = e.status & 0x0F;
      if (hi == 0x90 && e.body[1] > 0) {
        final note = _NoteEvent(ch, e.body[0], e.body[1], tick);
        (open[ch << 8 | e.body[0]] ??= []).add(note);
        song.notes.add(note);
      } else if (hi == 0x80 || hi == 0x90) {
        final pending = open[ch << 8 | e.body[0]];
        if (pending != null && pending.isNotEmpty) {
          pending.removeAt(0).endTick = tick;
        }
      } else if (e.status == 0xFF) {
        final type = e.body[0];
        if (type == 0x51) {
          final (len, at) = _readVarLen(e.body, 1);
          if (len >= 3) {
            song.tempi.add((
              tick,
              (e.body[at] << 16) | (e.body[at + 1] << 8) | e.body[at + 2],
            ));
          }
        }
        if (type == 0x51 || type == 0x58 || type == 0x59) {
          song.metas.add((tick, Uint8List.fromList([0xFF, ...e.body])));
        }
      }
    }
    // Notes still sounding when the track ends get closed there.
    for (final pending in open.values) {
      for (final note in pending) {
        note.endTick = tick;
      }
    }
  }
  for (final note in song.notes) {
    if (note.endTick <= note.startTick) note.endTick = note.startTick + 1;
  }
  return song;
}

class _MidiEvent {
  _MidiEvent(this.delta, this.status, this.body);

  final int delta;
  final int status;
  final Uint8List body;
}

List<({String id, Uint8List data})> _readChunks(Uint8List bytes) {
  if (bytes.length < 8 || String.fromCharCodes(bytes, 0, 4) != 'MThd') {
    throw const FormatException('Not a Standard MIDI File (missing MThd)');
  }
  final chunks = <({String id, Uint8List data})>[];
  var i = 0;
  while (i < bytes.length) {
    if (i + 8 > bytes.length) {
      throw const FormatException('Truncated chunk header');
    }
    final id = String.fromCharCodes(bytes, i, i + 4);
    final len = (bytes[i + 4] << 24) |
        (bytes[i + 5] << 16) |
        (bytes[i + 6] << 8) |
        bytes[i + 7];
    i += 8;
    if (i + len > bytes.length) {
      throw const FormatException('Chunk overruns file');
    }
    chunks.add((id: id, data: Uint8List.sublistView(bytes, i, i + len)));
    i += len;
  }
  return chunks;
}

Iterable<_MidiEvent> _trackEvents(Uint8List data) sync* {
  var i = 0;
  var running = 0;
  while (i < data.length) {
    final (delta, afterDelta) = _readVarLen(data, i);
    i = afterDelta;
    if (i >= data.length) throw const FormatException('Truncated event');
    final hasStatusByte = data[i] & 0x80 != 0;
    if (!hasStatusByte && running == 0) {
      throw const FormatException('Running status with no prior status byte');
    }
    final status = hasStatusByte ? data[i++] : running;
    final bodyStart = i;
    if (status == 0xFF) {
      running = 0; // meta events cancel running status
      if (i >= data.length) throw const FormatException('Truncated meta event');
      i++; // meta type
      final (len, afterLen) = _readVarLen(data, i);
      i = afterLen + len;
    } else if (status == 0xF0 || status == 0xF7) {
      running = 0; // so do sysex events
      final (len, afterLen) = _readVarLen(data, i);
      i = afterLen + len;
    } else if (status >= 0x80 && status < 0xF0) {
      running = status;
      final hi = status & 0xF0;
      i += (hi == 0xC0 || hi == 0xD0) ? 1 : 2;
    } else {
      throw FormatException(
          'Unexpected status byte 0x${status.toRadixString(16)}');
    }
    if (i > data.length) throw const FormatException('Event overruns track');
    yield _MidiEvent(delta, status, Uint8List.sublistView(data, bodyStart, i));
  }
}

/// Reads a variable-length quantity at [i]; returns (value, next index).
(int, int) _readVarLen(Uint8List data, int i) {
  var value = 0;
  for (var n = 0; n < 4; n++) {
    if (i >= data.length) {
      throw const FormatException('Truncated variable-length value');
    }
    final b = data[i++];
    value = (value << 7) | (b & 0x7F);
    if (b & 0x80 == 0) return (value, i);
  }
  throw const FormatException('Variable-length value too long');
}

/// Piecewise tick/ms map built from the FF 51 list — the same construction as
/// chord detection's, plus the inverse [tickOf] used to recover beat indices
/// from [ChordEvent.beatMs]. Single-tempo hymns reduce to
/// tick = ms * 1000 * division / usPerQuarter, but multi-tempo files (the
/// hymnal has ritardandos) stay correct segment by segment.
class _TempoMap {
  _TempoMap(List<(int tick, int usPerQuarter)> tempi, int division) {
    final sorted = [for (var i = 0; i < tempi.length; i++) (i, tempi[i])]
      ..sort((a, b) => a.$2.$1 != b.$2.$1 ? a.$2.$1 - b.$2.$1 : a.$1 - b.$1);
    _ticks.add(0);
    _msStarts.add(0);
    _msPerTick.add(_defaultUsPerQuarter / division / 1000);
    for (final (_, (tick, usPerQuarter)) in sorted) {
      final rate = usPerQuarter / division / 1000;
      if (tick == _ticks.last) {
        _msPerTick[_msPerTick.length - 1] = rate;
      } else {
        _msStarts.add(_msStarts.last + (tick - _ticks.last) * _msPerTick.last);
        _ticks.add(tick);
        _msPerTick.add(rate);
      }
    }
  }

  final List<int> _ticks = [];
  final List<double> _msStarts = [];
  final List<double> _msPerTick = [];

  /// Fractional tick of media-time [ms]; the caller rounds to a beat index.
  double tickOf(int ms) {
    var lo = 0, hi = _ticks.length - 1, best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_msStarts[mid] <= ms) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return _ticks[best] + (ms - _msStarts[best]) / _msPerTick[best];
  }
}
