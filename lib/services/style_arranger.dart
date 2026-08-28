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
  /// beat 1 kick-free), offbeat piano skank, drawbar-organ bubble, riff
  /// bass with structural rests. Gentle global swing on the offbeats, and
  /// one flat tempo across the whole hymn (see [_arrangedTempi]).
  reggae,

  /// Trinidadian calypso: Rhodes lead (the same keyboard voice as the
  /// reggae lead) over an offbeat steel-pan strum, calypso bass on the
  /// 3+3+2 tresillo, kit plus an engine room of claves, maracas and
  /// cowbell — backing at the lead's own level. Straight sixteenths, no
  /// swing, and one flat tempo across the whole hymn (see [_arrangedTempi]).
  calypso,
}

/// MIDI percussion channel (0-based).
const int _percussionChannel = 9;

/// Default tempo (microseconds per quarter note) when a file has no FF 51.
const int _defaultUsPerQuarter = 500000;

// GM programs (0-indexed program-change bytes).
const int _rhodesProgram = 4; // Electric Piano 1
const int _pianoProgram = 0; // Acoustic Grand Piano
const int _fingerBassProgram = 33; // Electric Bass (finger)
const int _acousticBassProgram = 32; // Acoustic Bass
const int _drawbarOrganProgram = 16; // Drawbar Organ
const int _steelDrumsProgram = 114; // Steel Drums
const int _vibraphoneProgram = 11; // Vibraphone

// GM percussion keys.
const int _acousticKick = 35; // Acoustic Bass Drum — the deeper GM kick
const int _kick = 36; // Bass Drum 1 — the tighter one
const int _sidestick = 37;
const int _snare = 38;
const int _hiBongo = 60;
const int _loBongo = 61;
const int _closedHat = 42;
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

/// The hollow root+fifth of Three Little Birds' organ dabs (A3+E4).
const Map<String, List<int>> _rootFifth = {
  '': [0, 7],
  'm': [0, 7],
  '7': [0, 7],
  'maj7': [0, 7],
  'm7': [0, 7],
  'dim': [0, 6],
  'sus4': [0, 7],
  'aug': [0, 8],
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

/// Reggae chop band, G3–F#4: exactly where both reference charts put the
/// chop — Over the Rainbow's piano voices C as G3 C4 E4, Three Little Birds'
/// guitar voices A as A3 C#4 E4. Under the Rhodes melody, not above it.
const int _skankLow = 55;

/// Organ bubble right hand: triads C3–C4 (48..59).
const int _bubbleLow = 52; // organ dabs / bubble, C3–B3
const int _reggaeBassLow = 31; // G1: the charts' bass sits A1–A2, an octave under the shared floor
const int _organStabLow = 72; // organ stabs and the held chord, C5–B5

/// Calypso strum band (60..71 ⊂ the researched G3–E5).
const int _strumLow = 60;

/// Bass notes live in this octave band.
const int _bassLow = 36;

/// One detected chord as it governs a beat.
typedef _Chord = ({int rootPc, String quality});

int _fifth(String quality) => switch (quality) {
      'dim' => 6,
      'aug' => 8,
      _ => 7,
    };

/// Whether [style] plays a 3/4 hymn in 4/4 by holding each bar's third beat
/// through a fourth (see [_stretchWaltz]). Reggae only: its one-drop cycle
/// is four pulses, and a three-pulse reading of it was heard as "does not
/// work" on hymn 1; the calypso waltz stands.
bool _playsWaltzInFour(ArrangeStyle style, int beatsPerBar) =>
    style == ArrangeStyle.reggae && beatsPerBar == 3;

/// Tick [t] of a 3/4 hymn moved onto a 4/4 grid: each bar's three beats
/// keep their places and a fourth beat is opened after them. A tick ON a
/// bar line maps to the next 4/4 bar line, so a note that runs to the end of
/// its bar is HELD through the new fourth beat — the "Happy birth-day to
/// yoooou" conversion — and a note that ends early keeps its rest.
int _stretchTick(int t, int d) => (t ~/ (3 * d)) * 4 * d + t % (3 * d);

/// Beat index [k] of a 3/4 hymn on the 4/4 grid.
int _stretchBeat(int k) => (k ~/ 3) * 4 + k % 3;

/// [song] (in 3/4) re-timed onto a 4/4 grid by [_stretchTick]: notes and
/// metas move, the time-signature meta is rewritten to 4/4, and every note
/// that reached its bar line now holds through the added beat.
_Song _stretchWaltz(_Song song) {
  final d = song.division;
  final out = _Song(d);
  for (final note in song.notes) {
    final start = _stretchTick(note.startTick, d);
    // Engraved hymn files end a note a tick or two before the next begins,
    // so "reaches its bar line" means within a sixteenth of it; those are
    // snapped to the line first so the hold takes.
    final barLine = (note.endTick ~/ (3 * d) + 1) * 3 * d;
    final reaches = note.endTick > barLine - d ~/ 4 && note.endTick <= barLine;
    final end = _stretchTick(reaches ? barLine : note.endTick, d);
    out.notes.add(
        _NoteEvent(note.channel, note.pitch, note.velocity, start)
          ..endTick = end > start ? end : start + 1);
  }
  for (final (tick, us) in song.tempi) {
    out.tempi.add((_stretchTick(tick, d), us));
  }
  for (final (tick, bytes) in song.metas) {
    if (bytes.length >= 4 && bytes[1] == 0x58) {
      final four = Uint8List.fromList(bytes);
      four[3] = 4; // numerator: the hymn now plays in four
      out.metas.add((_stretchTick(tick, d), four));
    } else {
      out.metas.add((_stretchTick(tick, d), bytes));
    }
  }
  return out;
}

/// Per-channel MIDI volume (CC 7) that makes Apple's AVMIDIPlayer engine
/// reproduce the reggae balance GeneralUser GS actually specifies.
///
/// Measured 2026-08-23 by rendering the same hymn-15 file through both
/// engines: against a reference SF2 renderer the original Grand Piano came out
/// +17.0 dB, the Rhodes +12.5, the Tonewheel Organ +11.2, the finger bass
/// -0.1 and the kit -2.6 — the piano chop alone clipping at +5 dBFS. The
/// owner heard exactly that as "loud and obnoxious... not a regular piano"
/// through a week of velocity changes that could never reach it. The engine's
/// CC 7 follows 40·log10(v/127), with the kit as the mix anchor.
///
/// The Caribbean Choruses investigation (2026-08-27) isolated an additional
/// cause: Apple's importer expands disjoint piano sample ranges, stacking
/// long-release voices until notes drop. The compatible bank fixes those
/// ranges without changing samples or envelopes. Removing the excess layers
/// reduces piano power by about 12 dB, so its former CC7=41 becomes 82
/// (+12.04 dB). Do not apply this value with the old bank. Other corrections
/// remain as measured; see docs/midi-playback.md for evidence and scope.
///
/// Applied by the iOS player only; Android's synth is a different engine with
/// a different bank, and the gospel and calypso balances were set by ear on
/// the phone and already absorb its gain.
const Map<int, int> reggaeVolumesForAppleSynth = {
  0: 53, // Rhodes lead:   -15.1 dB
  4: 53, // descant, same voice
  1: 82, // piano chop:     -7.6 dB, with the compatible piano bank
  3: 57, // organ:         -13.8 dB
  2: 109, // bass:          -2.6 dB
  9: 127, // kit: the anchor
};

/// Rewrites the hymn SMF in [originalBytes] as a generated arrangement in
/// [style]. All styles share the same skeleton:
///
/// * conductor track — the original tempo (FF 51), time-signature (FF 58)
///   and key-signature (FF 59) meta events, copied verbatim at their ticks;
/// * channel 0 — the melody (the full-coverage input channel with the
///   highest average pitch; see [_leadAndDescants]), notes copied verbatim
///   on the style's lead instrument with velocities NORMALIZED to the
///   style's target level (gospel 90, others 100; relative dynamics kept)
///   — the hymnal's engraved levels range from whisper to forte and a
///   band balances to the room. Part-time voices pitched above the lead
///   (hymn 190's obbligato) ride quietly on channel 4;
/// * style-specific comp/bass/percussion tracks generated bar by bar from
///   the chord detected on each hit's own beat.
///
/// Throws [FormatException] when [originalBytes] is not a well-formed SMF or
/// contains no detectable harmony (the caller falls back to a plain remap).
///
/// [channelVolumes] — MIDI channel to CC 7 value — is written at tick 0 on the
/// conductor track; see [reggaeVolumesForAppleSynth] for why a player would
/// pass it.
Uint8List arrangeStyle(Uint8List originalBytes, ArrangeStyle style,
    {Map<int, int> channelVolumes = const {}}) {
  final original = _parseSong(originalBytes);
  var chordTrack = detectChords(originalBytes);
  if (chordTrack == null) {
    throw const FormatException('No detectable harmony to arrange');
  }
  // Reggae and calypso comp from the MEDIUM-simplified harmony: raw
  // per-beat detection occasionally reads an inversion or passing tones as
  // a phantom out-of-key chord (heard in #456), and the diatonic filter
  // built for the chord tabs kills exactly those. Gospel keeps the raw
  // colors the owner has approved.
  if (style != ArrangeStyle.gospel) {
    chordTrack = simplifyTrack(chordTrack, ChordLevel.medium);
  }

  final d = original.division; // ticks per beat (quarter note)
  // A 3/4 hymn under reggae is played in four (see [_stretchWaltz]); the
  // beat map below is built on the ORIGINAL timeline, where detection ran,
  // and moved onto the 4/4 grid beat by beat.
  final stretch = _playsWaltzInFour(style, chordTrack.beatsPerBar);
  final song = stretch ? _stretchWaltz(original) : original;
  final n = stretch ? 4 : chordTrack.beatsPerBar;
  final tempo = _TempoMap(original.tempi, d);

  // Chord governing each beat index: detection windows start at k*division
  // ticks, so every beatMs maps back onto an exact beat via the tempo map.
  final beatChords = <int, _Chord>{};
  for (final chord in chordTrack.chords) {
    for (final ms in chord.beatMs) {
      final beat = (tempo.tickOf(ms) / d).round();
      final chordAt = (rootPc: chord.rootPc, quality: chord.quality);
      if (!stretch) {
        beatChords[beat] = chordAt;
        continue;
      }
      final moved = _stretchBeat(beat);
      beatChords[moved] = chordAt;
      // The held fourth beat carries its bar's last harmony.
      if (beat % 3 == 2) beatChords[moved + 1] = chordAt;
    }
  }
  var firstBeat = beatChords.keys.first;
  var lastBeat = firstBeat;
  for (final beat in beatChords.keys) {
    if (beat < firstBeat) firstBeat = beat;
    if (beat > lastBeat) lastBeat = beat;
  }

  // The half-time decision and the tempo clamp both key off the hymn's
  // DOMINANT tempo; see [_arrangedTempi].
  final (usPerQuarter, arrangedTempi, _) = _arrangedTempi(original, style);

  final ctx = _Ctx(
    d: d,
    n: n,
    beatChords: beatChords,
    firstBeat: firstBeat,
    lastBeat: lastBeat,
    seed: _fnv(originalBytes),
    bpm: 60e6 / usPerQuarter,
  );

  // Bands keep time — but they breathe at cadences. The conductor carries
  // the CLAMPED tempo map from [_arrangedTempi] instead of the original
  // (lurching) one or a flat line (which deleted the fermatas some files
  // encode purely as tempo dips, so verse ends rushed and stuttered —
  // listening feedback). Time-signature and key metas are kept verbatim.
  final conductor = _Track();
  for (final entry in channelVolumes.entries) {
    conductor.control(0, entry.key, 7, entry.value);
  }
  for (final (tick, us) in arrangedTempi) {
    conductor.meta(
        tick,
        Uint8List.fromList([
          0xFF, 0x51, 0x03, //
          (us >> 16) & 0xFF,
          (us >> 8) & 0xFF,
          us & 0xFF,
        ]));
  }
  for (final (tick, bytes) in song.metas) {
    if (bytes.length > 1 && bytes[1] == 0x51) continue;
    conductor.meta(tick, bytes);
  }

  // Reggae AND calypso lead on Rhodes — the keyboardist's melody voice the
  // owner settled on after the flute (non-idiomatic), steel pan (decays
  // under the strum), trumpet (reads as a bagpipe on this synth) and
  // acoustic piano were all heard and rejected for the calypso lead.
  final melodyProgram = switch (style) {
    ArrangeStyle.gospel => _rhodesProgram,
    ArrangeStyle.reggae => _rhodesProgram,
    ArrangeStyle.calypso => _rhodesProgram,
  };
  final gospel = style == ArrangeStyle.gospel;
  final melodyCap = gospel ? 112 : 120;
  final (leadChannel, descantChannels) = _leadAndDescants(song, n * d);
  final melodyNotes = [
    for (final note in song.notes)
      if (note.channel == leadChannel) note,
  ];
  var lastMelodyStart = 0;
  var velocitySum = 0;
  for (final note in melodyNotes) {
    if (note.startTick > lastMelodyStart) lastMelodyStart = note.startTick;
    velocitySum += note.velocity;
  }
  // A band balances to the room, not to the engraving: the hymnal ships
  // some melodies at average velocity 35-48 (hymns 30, 354, 662 in the
  // sweep) and the fixed-level backing drowned them. The lead is
  // NORMALIZED so its average lands on the style's target level — gospel
  // sits in the bed, reggae and calypso ride on top — with the file's
  // relative dynamics preserved.
  final targetLevel = gospel ? 90.0 : 100.0;
  final norm = targetLevel * melodyNotes.length / velocitySum;
  final melody = _Track()..program(0, 0, melodyProgram);
  for (final note in melodyNotes) {
    final velocity = (note.velocity * norm).round().clamp(1, melodyCap);
    var length = note.endTick - note.startTick;
    // The closing ritardando is flattened away with the rest of the tempo
    // map, which clipped the final chord's ring — so the last melody note
    // (like the button-ending voices) holds one extra bar past the final
    // bar line.
    if (!gospel && note.startTick == lastMelodyStart) length += n * d;
    melody.note(note.startTick, 0, note.pitch, velocity, length);
  }

  // The descant rides above the tune on channel 4 in the lead's own voice,
  // quiet — the church sound of a choir's descant on the refrains, kept
  // rather than discarded.
  final descant = _Track()..program(0, 4, melodyProgram);
  for (final note in song.notes) {
    if (!descantChannels.contains(note.channel)) continue;
    final velocity = (note.velocity * norm * 0.7).round().clamp(1, 96);
    descant.note(note.startTick, 4, note.pitch, velocity,
        note.endTick - note.startTick);
  }
  final lead = descantChannels.isEmpty ? [melody] : [melody, descant];

  switch (style) {
    case ArrangeStyle.gospel:
      final comp = _Track()..program(0, 1, _rhodesProgram);
      final bass = _Track()..program(0, 2, _fingerBassProgram);
      final drums = _Track();
      _emitGospel(ctx, comp, bass, drums);
      return _writeSmf(d, [conductor, ...lead, comp, bass, drums]);
    case ArrangeStyle.reggae:
      final skank = _Track()..program(0, 1, _pianoProgram);
      final bass = _Track()..program(0, 2, _fingerBassProgram);
      final organ = _Track()..program(0, 3, _drawbarOrganProgram);
      final drums = _Track();
      _emitReggae(ctx, skank, bass, organ, drums);
      return _writeSmf(d, [conductor, ...lead, skank, bass, organ, drums]);
    case ArrangeStyle.calypso:
      final strum = _Track()..program(0, 1, _steelDrumsProgram);
      final shimmer = _Track()..program(0, 3, _vibraphoneProgram);
      final bass = _Track()..program(0, 2, _acousticBassProgram);
      final drums = _Track();
      _emitCalypso(ctx, strum, shimmer, bass, drums);
      return _writeSmf(d, [conductor, ...lead, strum, shimmer, bass, drums]);
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

  /// The chord governing [beat] — the one detected there, or failing that
  /// the last one heard, up to two bars back. Detection currently marks
  /// every beat of every hymn in the corpus, so the hold-over never fires
  /// today; it is here so that a hymn which ever does leave a beat
  /// unharmonized makes the comping repeat a chord rather than fall silent.
  /// A skank with holes in it is not a skank.
  _Chord? chordAt(int beat) {
    if (!inSpan(beat)) return null;
    for (var b = beat; b >= firstBeat && b > beat - 2 * n; b--) {
      final chord = beatChords[b];
      if (chord != null) return chord;
    }
    return null;
  }

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

/// Tempo-policy tunables — the veteran-band feel in three numbers. Raise
/// the floor toward 1.0 for a stiffer band, widen the ramp for lazier
/// transitions, add steps for finer grades; nothing else needs touching.
const double _cadenceFloorSpeed = 0.85; // holds ease to 85% speed, no lower
const int _rampBeats = 2; // each transition spreads across 2 beats
const int _rampSteps = 8; // in 8 micro-steps (≈2% each)

/// The arranged tempo policy for [song]: the DOMINANT tempo (the marking
/// governing the most ticks — hymn 15 opens with a seven-beat 240 BPM
/// flourish before its 121 BPM body, so "first FF51" is a trap) and the
/// CLAMPED tempo map the arrangement plays under. Anything faster than the
/// dominant clamps down to it (opener flourishes disappear); anything
/// slower than [_cadenceFloorSpeed] clamps up to that floor — so the
/// fermatas some files encode purely as tempo dips survive as subtle
/// breaths, never lurches — and every remaining transition is smoothed
/// into a [_rampSteps]-step ramp across the [_rampBeats] preceding beats
/// (the adaptive beat: hard tempo steps under a groove read as stutters).
(int, List<(int, int)>, List<int>) _arrangedTempi(_Song song, ArrangeStyle style) {
  var songEnd = 0;
  for (final note in song.notes) {
    if (note.endTick > songEnd) songEnd = note.endTick;
  }
  var usPerQuarter = _defaultUsPerQuarter;
  final ordered = [...song.tempi]..sort((a, b) => a.$1.compareTo(b.$1));
  if (ordered.isNotEmpty) {
    final governed = <int, int>{}; // usPerQuarter -> ticks it governs
    for (var i = 0; i < ordered.length; i++) {
      final (tick, us) = ordered[i];
      final until = i + 1 < ordered.length ? ordered[i + 1].$1 : songEnd;
      if (until > tick) {
        governed[us] = (governed[us] ?? 0) + (until - tick);
      }
    }
    // Strict > keeps the earliest marking on ties — deterministic.
    var bestTicks = -1;
    for (final (_, us) in ordered) {
      final ticks = governed[us] ?? 0;
      if (ticks > bestTicks) {
        bestTicks = ticks;
        usPerQuarter = us;
      }
    }
  }
  final slowest = (usPerQuarter / _cadenceFloorSpeed).round();
  final tempi = <(int, int)>[(0, usPerQuarter)];
  final dipTicks = <int>[];
  for (final (tick, us) in ordered) {
    if (us > slowest) dipTicks.add(tick); // a marked hold — see doc above
    if (style != ArrangeStyle.gospel) continue; // the island band plays flat
    final clamped = us.clamp(usPerQuarter, slowest);
    if (tick == 0) {
      tempi[0] = (0, clamped);
    } else if (clamped != tempi.last.$2) {
      tempi.add((tick, clamped));
    }
  }
  // The island styles take ONE tempo for the whole hymn and never bend it.
  // A riddim is a riddim: the owner's call after hearing the drop arrive
  // late at every verse end. The hymn's fermatas survive as [dipTicks], and
  // the emitters still mark them — with the sticks, not the clock.
  if (style != ArrangeStyle.gospel) {
    return (usPerQuarter, [(0, usPerQuarter)], dipTicks);
  }
  // The ADAPTIVE beat: a clamped map that still stepped straight between
  // tempos read as a stutter under the groove (listening feedback). Every
  // transition now eases in across the beat before its marking — four
  // sub-steps of linear interpolation — so the band decelerates into a
  // cadence hold and picks back up smoothly, the way a drummer follows a
  // conductor rather than a click switch.
  final smoothed = <(int, int)>[tempi.first];
  for (var i = 1; i < tempi.length; i++) {
    final (tick, us) = tempi[i];
    final prevUs = tempi[i - 1].$2;
    var rampStart = tick - _rampBeats * song.division;
    if (rampStart <= tempi[i - 1].$1) rampStart = tempi[i - 1].$1 + 1;
    for (var s = 1; s < _rampSteps; s++) {
      final st = rampStart + (tick - rampStart) * s ~/ _rampSteps;
      final su = prevUs + (us - prevUs) * s ~/ _rampSteps;
      if (st > smoothed.last.$1 && su != smoothed.last.$2) {
        smoothed.add((st, su));
      }
    }
    if (tick > smoothed.last.$1) {
      smoothed.add((tick, us));
    } else {
      smoothed[smoothed.length - 1] = (smoothed.last.$1, us);
    }
  }
  return (usPerQuarter, smoothed, dipTicks);
}

/// Remaps [track] — detected on [originalBytes] and therefore timed on the
/// hymn's ORIGINAL tempo map — onto the timeline of this hymn's arranged
/// render (the clamped map from [_arrangedTempi], which [arrangeStyle]
/// writes). The chord ticker and chart consume media-time positions of
/// whatever file is PLAYING; without this remap they drift on any hymn
/// whose map the arrangement reshapes (#15: chords ran ahead through the
/// 240 BPM opener and outlived the audio through the closing rits).
///
/// Throws [FormatException] when [originalBytes] is not a well-formed SMF.
ChordTrack retimeTrackForArrangement(
    Uint8List originalBytes, ChordTrack track, ArrangeStyle style) {
  final song = _parseSong(originalBytes);
  final (_, tempi, _) = _arrangedTempi(song, style);
  final original = _TempoMap(song.tempi, song.division);
  final arranged = _TempoMap(tempi, song.division);
  // A 3/4 hymn played in four (see [_stretchWaltz]) has every bar a beat
  // longer in the render; the ticker's positions follow the same map.
  final stretch = _playsWaltzInFour(style, track.beatsPerBar);
  final d = song.division;
  double moveTick(double tick) => stretch
      ? _stretchTick(tick.floor(), d) + (tick - tick.floor())
      : tick;
  int remap(int ms) => arranged.msOf(moveTick(original.tickOf(ms))).round();
  return ChordTrack(
    chords: [
      for (final e in track.chords)
        ChordEvent(
          startMs: remap(e.startMs),
          durationMs: remap(e.startMs + e.durationMs) - remap(e.startMs),
          rootPc: e.rootPc,
          quality: e.quality,
          beatMs: [for (final ms in e.beatMs) remap(ms)],
        ),
    ],
    key: track.key,
    beatsPerBar: stretch ? 4 : track.beatsPerBar,
    measureStartMs: [for (final ms in track.measureStartMs) remap(ms)],
  );
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

/// Where the reggae pulse flips from a beat to an eighth. See [_emitReggae].
const double _reggaeEighthsBelowBpm = 100;

/// Roots-reggae backing, transcribed from the two reference charts the owner
/// supplied — "Three Little Birds" (145 BPM) and a reggae "Over the Rainbow"
/// (82 BPM), both GM backing-track files — rather than written from
/// description. Read side by side they agree on something neither shows
/// alone: the chop lands every 0.7–0.85 SECONDS whatever the notation. At
/// 145 BPM that is beats 2 and 4; at 82 it is every "&". So the engine picks
/// its PULSE by tempo — a beat at [_reggaeEighthsBelowBpm] and above (chop on
/// 2 and 4, one drop a bar), an eighth below it (chop on every "&", the drop
/// on 2 and 4) — and the same cycle runs on that pulse: pulse 1 bare, pulse 2
/// chop, pulse 3 the drop, pulse 4 chop. The mid-tempo band (~96–115 BPM,
/// a third of the hymnal) sits between the two charts and grooves heavy
/// either way; see the note in the summary of this change.
///
/// The parts, per the charts:
///
/// * channel 1, piano — the skank: a close triad on pulses 2 and 4 in the
///   charts' own chop band (G3–F#4), every bar, and nothing else. A chop on
///   every "&" at 121 BPM is twice the charts' rate and was heard, correctly,
///   as a double skank; a root octave on 1 and 3 (Three Little Birds' piano
///   plays one in half its bars) was heard as a loud piano that "should have
///   been a bass guitar" — so 1 and 3 belong to the bass alone. Nothing else
///   sounds at the instant of a chop: the earlier organ-on-top-of-piano
///   composite is what read as "not a regular piano".
/// * channel 3, organ — the bubble. Beat reading: Three Little Birds'
///   rhythmic organ — root+fifth dabs on the swung "&" of pulses 1 and 2
///   and a HELD triad through pulse 3 under the drop (the chart's one long
///   note); its stabs on 2 and 4 are left to the piano, which here IS the
///   chop (the chart's chop is a guitar). Eighth reading: Over the
///   Rainbow's electric piano — a triad on the triplet "&" of every pulse,
///   never coinciding with the piano.
/// * channel 2, finger bass — root on 1 and 3, fifth on 2 and 4, LONG
///   (the charts' bass is legato, 0.75–1.0 of a pulse), in the charts'
///   A1–A2 register; a chromatic walk-up into the next root at phrase ends
///   only, and only where it does not rub the chord; the eighth reading
///   adds the root on 2& as Over the Rainbow does.
/// * channel 9 — the drop is kick 35 AND 36 layered under a loud side
///   stick (the chart voices it exactly so: 120/109/115). Beat reading:
///   quarter-note closed hats (the chart's open hat on 2 and 4 is a loud
///   metallic ring on this soundfont and is left out), maracas on every
///   eighth accented on the beat, tambourine on every beat with light
///   "&"s, a side stick on the swung "&" of 1 every other bar. Eighth
///   reading: hats on every "&" plus beats 3 and 4, tambourine sixteenths,
///   a stick accent on the "e" of 3 every other bar. A quiet crash on
///   section tops and a two-stroke answer at phrase ends; no snare in the
///   groove, because neither chart has one there.
///
/// 3/4 runs a three-pulse cycle: bare 1, chop 2, drop 3.
void _emitReggae(_Ctx c, _Track skank, _Track bass, _Track organ, _Track drums) {
  final d = c.d;
  final n = c.n;
  final waltz = n == 3;
  final eighths = c.bpm < _reggaeEighthsBelowBpm;
  final p = eighths ? d ~/ 2 : d; // ticks per pulse
  final pulses = n * d ~/ p; // pulses per bar: 4 / 8 / 3 / 6
  // Pulse roles within the bar (0-based pulse indices).
  final List<int> chops, drops, dabs, holds;
  // The organ never sounds at the instant of a piano chop: Three Little
  // Birds' organ does stab on 2 and 4, but there the GUITAR is the chop and
  // the piano comps; here the piano is the chop, and a tonewheel key-click
  // landing on a piano attack is what turned the chop into the hybrid the
  // owner heard as "not a regular piano". So the organ keeps its dabs
  // between the beats and its held chord under the drop, and the chop
  // stands alone.
  if (!eighths && !waltz) {
    chops = [1, 3]; drops = [2]; dabs = [0, 1]; holds = [2];
  } else if (!eighths) {
    // The waltz: one chop, on 2; the drop on 3 carries the bass and the
    // organ's hold, not a second chop.
    chops = [1]; drops = [2]; dabs = [0]; holds = [2];
  } else if (!waltz) {
    chops = [1, 3, 5, 7]; drops = [2, 6];
    dabs = [0, 1, 2, 3, 4, 5, 6, 7]; holds = const [];
  } else {
    chops = [1, 3, 5]; drops = [2];
    dabs = [0, 1, 2, 3, 4, 5]; holds = const [];
  }
  // The swung "&" of pulse [k]: 7/12 of the way in the beat reading (the
  // chart's +0.58), 2/3 in the eighth reading (its triplet bubble).
  int swung(int k) => k * p + (eighths ? 2 * p ~/ 3 : 7 * p ~/ 12);
  int beatOf(int pulse) => pulse * p ~/ d;
  // The chop: ~150 ms of real time at any tempo. Under ~100 ms a GM grand
  // is cut off inside its attack and reads as a click (the 83 ms chop of
  // the second cut); the charts' chops run 80–140 ms on guitar and piano.
  final chopLen = (0.15 * c.bpm / 60 * d).round();
  // Reggae bass register: each pitch class placed in [G1, G2).
  int vb(int pc) => _reggaeBassLow + ((pc - _reggaeBassLow) % 12 + 12) % 12;

  // The band comes in on the first full bar: a hymn's pickup beats stay
  // unaccompanied (as Three Little Birds' own intro bar is), rather than
  // opening the song with a fifth, or the drop, on the anacrusis.
  final entry = (c.firstBeat + n - 1) ~/ n;
  for (var bar = entry; bar <= c.lastBar; bar++) {
    final barStart = bar * n * d;
    final phase = (bar - entry) % 8;
    final odd = (bar - entry).isOdd;
    final last = bar == c.lastBar;

    void dnote(int offset, int key, int velocity, [int? length]) {
      if (!c.hit(bar, offset)) return;
      drums.note(barStart + offset, _percussionChannel, key, velocity,
          length ?? d ~/ 4);
    }

    _Chord? chordAtPulse(int k) => c.chordAt(bar * n + beatOf(k));

    // --- Piano: the chop, and only the chop -------------------------------
    // Three Little Birds' piano also plays a root octave on 1 and 3; the
    // first transcription copied that and the owner heard it as "the old
    // loud piano sound... it should have been a bass guitar, it comes right
    // before the skank and between each skank". The bass already owns 1 and
    // 3, so the piano plays the chop on 2 and 4 and nothing else. On the
    // last bar its final chop holds out with the band's chord — the piano's
    // button — so the skank is the last thing to stop, not the first.
    for (final k in chops) {
      final chord = chordAtPulse(k);
      if (chord == null || !c.hit(bar, k * p)) continue;
      final v = c.vel(92, 3, bar, 20 + k);
      final len = last && k == chops.last ? 2 * n * d : chopLen;
      for (final pitch in _voice(_triadIntervals, chord, _skankLow)) {
        skank.note(barStart + k * p, 1, pitch, v, len);
      }
    }

    // --- Organ: the bubble -------------------------------------------------
    if (last) {
      // The button: the organ holds the final chord out past the bar line.
      final chord = chordAtPulse(0) ?? chordAtPulse(1);
      if (chord != null) {
        for (final pitch in _voice(_triadIntervals, chord, _organStabLow)) {
          organ.note(barStart, 3, pitch, 78, 2 * n * d);
        }
      }
    } else {
      for (final k in dabs) {
        final chord = chordAtPulse(k);
        final offset = swung(k);
        if (chord == null || !c.hit(bar, offset)) continue;
        final v = c.vel(eighths ? 66 : 70, 3, bar, 30 + k);
        final table = eighths ? _triadIntervals : _rootFifth;
        for (final pitch in _voice(table, chord, _bubbleLow)) {
          organ.note(barStart + offset, 3, pitch, v, p ~/ 5);
        }
      }
      for (final k in holds) {
        final chord = chordAtPulse(k);
        if (chord == null || !c.hit(bar, k * p)) continue;
        for (final pitch in _voice(_triadIntervals, chord, _organStabLow)) {
          organ.note(barStart + k * p, 3, pitch, c.vel(80, 2, bar, 50 + k),
              17 * p ~/ 20);
        }
      }
    }

    // --- Bass: root and fifth, legato -----------------------------------
    if (last) {
      final chord = chordAtPulse(0) ?? chordAtPulse(1);
      if (chord != null) {
        bass.note(barStart, 2, vb(chord.rootPc), 112, 2 * n * d);
      }
    } else {
      final nextChord = c.chordAt((bar + 1) * n);
      // (pulse, role): r root, f fifth, a fifth-or-approach, o root on 2&.
      final shape = !eighths
          ? (waltz ? const [(0, 'r'), (1, 'f'), (2, 'r')]
                   : const [(0, 'r'), (1, 'f'), (2, 'r'), (3, 'a')])
          : (waltz ? const [(0, 'r'), (2, 'f'), (4, 'r'), (5, 'a')]
                   : const [(0, 'r'), (2, 'f'), (3, 'o'), (4, 'r'), (6, 'f'), (7, 'a')]);
      for (final (k, role) in shape) {
        final chord = chordAtPulse(k);
        if (chord == null || !c.hit(bar, k * p)) continue;
        final int pitch;
        var v = 104;
        var len = 3 * p ~/ 4;
        switch (role) {
          case 'r':
            pitch = vb(chord.rootPc);
            v = drops.contains(k) ? 104 : (k == 0 ? 108 : 106);
            len = 17 * p ~/ 20;
          case 'o':
            pitch = vb(chord.rootPc);
            v = 98;
            len = 3 * p ~/ 5;
          case 'a':
            // The fifth on the pulse — and, at a phrase end where the
            // harmony moves, a chromatic walk-up into the next root on the
            // back half of the pulse. Rationed, and checked: the charts use
            // the walk-in about once in seventeen bars, a hymn moves every
            // bar or two, and a leading tone a semitone from a chord tone
            // under a sustained melody (hymn 15, F# into G over a held F)
            // is a wrong note, not an approach.
            pitch = vb(chord.rootPc + _fifth(chord.quality));
            v = 102;
            len = 3 * p ~/ 4;
            final moving = nextChord != null && nextChord != chord;
            if (moving && (phase == 3 || phase == 7)) {
              final approach = (nextChord.rootPc + 11) % 12;
              final rubs = _voice(_triadIntervals, chord, 0).any((t) {
                final gap = ((t - approach) % 12 + 12) % 12;
                return gap == 1 || gap == 11;
              });
              if (!rubs) {
                len = p ~/ 2;
                bass.note(barStart + k * p + p ~/ 2, 2, vb(approach),
                    c.vel(98, 2, bar, 68 + k), p ~/ 2);
              }
            }
          default: // 'f'
            pitch = vb(chord.rootPc + _fifth(chord.quality));
            v = 104;
            len = 3 * p ~/ 4;
        }
        bass.note(barStart + k * p, 2, pitch, c.vel(v, 2, bar, 60 + k), len);
      }
    }

    // --- Drums ------------------------------------------------------------
    for (final k in drops) {
      _drop(dnote, k * p, d);
    }
    if (!eighths) {
      // Three Little Birds' kit. Quarter-note closed hats; maracas on every
      // eighth; tambourine on every beat, lighter under the chop. A swung
      // side stick on 1& every other bar.
      //
      // The chart also opens the hat on 2 or 4 most bars. On this
      // soundfont that is a long, bright cymbal landing on exactly half the
      // chops, and the owner heard it as "a heavy metallic-sounding
      // instrument that plays along with the skanks, but not on every
      // interval... very loud and obnoxious". It is gone: the hat stays
      // closed on every beat.
      for (var k = 0; k < pulses; k++) {
        final isDrop = drops.contains(k);
        dnote(k * p, _closedHat, c.vel(isDrop ? 90 : 84, 3, bar, 70 + k), p ~/ 5);
        dnote(k * p, _maracas, c.vel(k == 0 ? 58 : (isDrop ? 54 : 66), 3, bar, 80 + k), p ~/ 3);
        dnote(swung(k), _maracas, c.vel(35, 3, bar, 90 + k), p ~/ 5);
        dnote(k * p, _tambourine, c.vel(k == 0 ? 54 : (isDrop ? 60 : 56), 3, bar, 100 + k), p ~/ 4);
        if (k == 1 || (k == pulses - 1 && !odd)) {
          dnote(swung(k), _tambourine, c.vel(32, 3, bar, 110 + k), p ~/ 4);
        }
      }
      if (odd) dnote(swung(0), _sidestick, 92);
    } else {
      // Over the Rainbow's kit. Tambourine sixteenths; hats on every "&"
      // and on the beats after the drop; a stick accent on the "e" of the
      // pulse after the first drop every other bar.
      for (var s = 0; s < n * 4; s++) {
        dnote(s * d ~/ 4, _tambourine, c.vel(s % 4 == 0 ? 58 : 52, 3, bar, 70 + s), d ~/ 8);
      }
      // Hats on every "&", and on the beats after the first drop — the
      // chart's beat 3 at 58 and beat 4 (with the second drop) at 83.
      for (var k = 0; k < pulses; k++) {
        if (k.isOdd) {
          dnote(k * p, _closedHat, c.vel(70, 3, bar, 100 + k), p ~/ 3);
        } else if (k > 0 && k != drops.first) {
          dnote(k * p, _closedHat, c.vel(k == pulses - 2 ? 82 : 60, 3, bar, 100 + k), p ~/ 3);
        }
      }
      // The chart's stick accent on the "e" of the beat after the drop
      // (v100, three bars in four), and its ghost on the "a" of the drop
      // beat (v59) — alternated here bar by bar.
      if (!odd) {
        dnote(drops.first * p + 2 * p + p ~/ 2, _sidestick, 90);
      } else {
        dnote(drops.first * p + p + p ~/ 2, _sidestick, 56);
      }
    }
    // Section tops and phrase ends, both quiet: the chart's crash sits at
    // 70 and its fills are two timbale strokes.
    if (phase == 0 && bar != entry && !last) {
      dnote(0, _crash, 72, d);
    }
    if (phase == 7 && !last) {
      final at = (pulses - 1) * p;
      dnote(at + p ~/ 2, _sidestick, 66);
      dnote(at + 3 * p ~/ 4, _sidestick, 82);
    }
    if (last) dnote(0, _crash, 96, 2 * n * d);
  }
}

/// The one drop's voice — kick 35 and 36 layered under a loud cross-stick,
/// exactly as the reference chart plays it (120 / 109 / 115). The first cut
/// had the stick on its own over a single tight kick and was heard as
/// high-pitched; a later one pulled the stick down to a colour — the chart
/// says no, the stick IS the drop's attack, and the depth comes from the two
/// kicks together.
///
/// Levels: the chart's 120/109/115 are its own mix's numbers. Rendered
/// through the app's soundfont with the bass and the organ hold landing on
/// the same beat, that stack peaked at -0.1 to -1.2 dBFS on EVERY drop while
/// the chop beats sat at -6 — a mix clipping once a bar, which on a phone
/// speaker is heard as heavy and harsh. Velocity barely moves this
/// soundfont's kick samples (118 to 104 bought 2 dB), so the layer is
/// thinned instead: GM 35 carries the drop, GM 36 is a quiet body under it.
void _drop(void Function(int, int, int, [int?]) dnote, int offset, int d) {
  dnote(offset, _acousticKick, 100, d ~/ 2);
  dnote(offset, _kick, 72, d ~/ 2);
  dnote(offset, _sidestick, 94);
}

// ---------------------------------------------------------------------------
// Calypso
// ---------------------------------------------------------------------------

/// Steel-pan calypso backing (gospelypso register — dignified, side-stick
/// verses, no power-soca):
///
/// * channel 1, steel drums — the calypso strum: the genre's fingerprint,
///   double stops on the 2nd, 3rd and 4th sixteenth of each beat, RESTING
///   on every downbeat, accents on the "&"s (strongest on 2& and 4&). The
///   two notes of each stop land a hair apart with the hand alternating
///   low-first/high-first (no pan player strikes both notes as one), and
///   channel 3 doubles every stroke with a quiet vibraphone — the
///   metallic attack transient the synth's pan patch lacks (feedback:
///   "sounds more like a keyboard");
/// * channel 2, acoustic bass — tresillo bass: root on 1, fifth on 2&,
///   root on 3, pickup on 4& walking chromatically into chord changes;
/// * channel 9 — kit (syncopated kick 1 / 2& / 3, side-stick backbeat with
///   tambourine, offbeat-accented eighth hats with an open hat on 4& every
///   2nd bar) plus an engine room of claves on the 3+3+2 anchor (1, 2&, 4),
///   running maracas eighths, and a 2-bar cowbell loop; the 8-bar fill
///   alternates a snare pickup with a bongo lead-in, into a crash on the
///   following downbeat. The final bar is a button ending: kick + crash,
///   held bass root, strum silent — the Rhodes lead carries the tune out.
///
/// Everything is straight — the lilt comes from velocity shape and the
/// rests on the downbeats, not timing offsets — and everything is written
/// on ONE flat tempo (see [_arrangedTempi]), so the strum's tick-a never
/// speeds up or slows down anywhere in the hymn. 3/4 hymns get the Caribbean
/// waltz: strum resting on beat 1 and filling beats 2–3, claves on the
/// 1 / 2& hemiola, triangle color on 2 and 3.
void _emitCalypso(
    _Ctx c, _Track strum, _Track shimmer, _Track bass, _Track drums) {
  final d = c.d;
  final n = c.n;
  final waltz = n == 3;

  // Strum velocities per beat, for the 2nd/3rd/4th sixteenth of the beat —
  // at the lead's own level (listening feedback: "give the tiki taka sound
  // and backing tracks with drums the same volume as the lead"); the lead
  // stays on top only by its long sustains against the staccato chop.
  const strumVels44 = [[74, 90, 76], [74, 92, 76], [74, 90, 76], [74, 94, 80]];
  const strumVels34 = [[74, 90, 76], [74, 90, 76]];

  for (var bar = c.firstBar; bar <= c.lastBar; bar++) {
    final barStart = bar * n * d;
    final phase = (bar - c.firstBar) % 8;
    final evenBar = (bar - c.firstBar) % 2 == 0;

    void dnote(int offset, int key, int velocity, [int? length]) {
      if (!c.hit(bar, offset)) return;
      drums.note(barStart + offset, _percussionChannel, key, velocity,
          length ?? d ~/ 4);
    }

    // The button ending: kick + crash on the final downbeat, bass root
    // held past the bar line, the strum and engine room silent — the
    // Rhodes lead carries the tune out (listening feedback: the old
    // close-out read as a staggered stop).
    if (bar == c.lastBar) {
      dnote(0, _kick, 100);
      dnote(0, _crash, 96, 2 * n * d);
      final chord = c.chordAt(bar * n) ?? c.chordAt(bar * n + 1);
      if (chord != null) {
        bass.note(barStart, 2, _voiceBass(chord.rootPc), 104, 2 * n * d);
      }
      continue;
    }

    // --- Strum: rest on the beat, hit every e, &, a ---------------------
    final strumBeats = waltz ? [1, 2] : [0, 1, 2, 3];
    final vels = waltz ? strumVels34 : strumVels44;
    // Two sticks never land as one: the notes of each double stop spread
    // by a 128th, alternating low-first / high-first like real hands.
    final spread = d ~/ 32;
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
        final pitches = _voice(_guideTones, chord, _strumLow);
        final stroke = sub.isEven ? pitches : pitches.reversed.toList();
        for (final (j, pitch) in stroke.indexed) {
          final tick = barStart + offset + j * spread;
          strum.note(tick, 1, pitch, v, length);
          shimmer.note(tick, 3, pitch, (v - 25).clamp(1, 127), length);
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
      dnote(0, _kick, 102);
      dnote(d + d ~/ 2, _sidestick, 82);
      for (var k = 0; k < 5; k++) {
        dnote(k * d ~/ 2, _closedHat, c.vel(k.isEven ? 60 : 78, 3, bar, 40 + k));
      }
      if (evenBar) {
        dnote(5 * d ~/ 2, _closedHat, c.vel(78, 3, bar, 45));
      } else {
        dnote(5 * d ~/ 2, _openHat, c.vel(82, 3, bar, 45), d ~/ 3);
      }
      dnote(0, _claves, 92);
      dnote(d + d ~/ 2, _claves, 92); // the 3+3 hemiola over the bar
      dnote(d, _triangle, c.vel(60, 3, bar, 46));
      dnote(2 * d, _triangle, c.vel(60, 3, bar, 47));
      for (var k = 0; k < 6; k++) {
        dnote(k * d ~/ 2, _maracas, c.vel(k.isEven ? 58 : 74, 4, bar, 50 + k));
      }
      if (phase == 7) {
        dnote(2 * d + d ~/ 2, _snare, 80);
        dnote(2 * d + 3 * d ~/ 4, _snare, 92);
      }
    } else {
      dnote(0, _kick, 102);
      dnote(d + d ~/ 2, _kick, 90);
      dnote(2 * d, _kick, 98);
      dnote(d, _sidestick, 86);
      dnote(3 * d, _sidestick, 90);
      dnote(d, _tambourine, c.vel(76, 4, bar, 38));
      dnote(3 * d, _tambourine, c.vel(80, 4, bar, 39));
      for (var k = 0; k < 7; k++) {
        dnote(k * d ~/ 2, _closedHat, c.vel(k.isEven ? 64 : 82, 3, bar, 40 + k));
      }
      if (evenBar) {
        dnote(7 * d ~/ 2, _closedHat, c.vel(86, 3, bar, 47));
      } else {
        dnote(7 * d ~/ 2, _openHat, c.vel(86, 3, bar, 47), d ~/ 3);
      }
      // Engine room: claves on the 3+3+2 anchor — 1, 2&, 4.
      dnote(0, _claves, 92);
      dnote(d + d ~/ 2, _claves, 92);
      dnote(3 * d, _claves, 92);
      for (var k = 0; k < 8; k++) {
        dnote(k * d ~/ 2, _maracas, c.vel(k.isEven ? 58 : 74, 4, bar, 50 + k));
      }
      // Cowbell, 2-bar loop.
      if (evenBar) {
        dnote(d ~/ 2, _cowbell, c.vel(80, 3, bar, 60));
        dnote(d + d ~/ 2, _cowbell, c.vel(80, 3, bar, 61));
        dnote(3 * d, _cowbell, c.vel(84, 3, bar, 62));
      } else {
        dnote(d + d ~/ 2, _cowbell, c.vel(80, 3, bar, 60));
        dnote(3 * d, _cowbell, c.vel(84, 3, bar, 61));
        dnote(3 * d + d ~/ 2, _cowbell, c.vel(78, 3, bar, 62));
      }
      // The 8-bar fill alternates deterministically between the snare
      // pickup and a bongo lead-in (bongos are fills/lead-ins only, per
      // the research).
      if (phase == 7) {
        if (c.vel(0, 1, bar, 90) <= 0) {
          dnote(3 * d + d ~/ 4, _snare, 70);
          dnote(3 * d + d ~/ 2, _snare, 85);
          dnote(3 * d + 3 * d ~/ 4, _snare, 95);
        } else {
          dnote(3 * d, _hiBongo, 72, d ~/ 4);
          dnote(3 * d + d ~/ 4, _hiBongo, 64, d ~/ 4);
          dnote(3 * d + d ~/ 2, _loBongo, 84, d ~/ 4);
          dnote(3 * d + 3 * d ~/ 4, _hiBongo, 94, d ~/ 4);
        }
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
  // Each chord tone placed in the octave [low, low + 12). The floor need
  // not be a C: the first version added pitch classes straight onto [low],
  // which only works when low % 12 == 0 — moving the piano chop's floor to
  // E4 then transposed every chop up a major third (a C chord came out E,
  // A-flat, B), which is exactly the "weird, strange notes" the owner had
  // been hearing.
  final pitches = <int>{
    for (final interval in tones)
      low + ((chord.rootPc + interval - low) % 12 + 12) % 12,
  };
  return pitches.toList()..sort();
}

/// [pitchOrPc] transposed by octaves into the bass band (36..47 ⊂ 36..50).
int _voiceBass(int pitchOrPc) => _bassLow + ((pitchOrPc % 12) + 12) % 12;

/// The lead channel and any descant channels of [song].
///
/// The lead is the sounding non-percussion channel with the highest average
/// pitch AMONG channels that carry the tune the whole way through — bar
/// coverage within 70% of the best-covered channel (ties: most notes, then
/// lowest channel number). Coverage matters: hymn 190 carries a part-time
/// descant pitched ABOVE the soprano (an intro flourish plus refrains,
/// silence through whole verses); picking by pitch alone led with it and
/// the melody fell silent for the entire first verse.
///
/// Channels pitched above the chosen lead come back as the descants: a
/// choir doesn't discard its descant, it lets it ride quietly above the
/// tune — so the arrangement layers those instead of dropping (or leading
/// with) them.
(int, Set<int>) _leadAndDescants(_Song song, int barTicks) {
  final counts = <int, int>{};
  final sums = <int, int>{};
  final bars = <int, Set<int>>{};
  for (final note in song.notes) {
    if (note.channel == _percussionChannel) continue;
    counts[note.channel] = (counts[note.channel] ?? 0) + 1;
    sums[note.channel] = (sums[note.channel] ?? 0) + note.pitch;
    (bars[note.channel] ??= {}).add(note.startTick ~/ barTicks);
  }
  if (counts.isEmpty) {
    throw const FormatException('No melody notes to arrange');
  }
  var maxCoverage = 0;
  for (final covered in bars.values) {
    if (covered.length > maxCoverage) maxCoverage = covered.length;
  }
  int? lead;
  for (final channel in counts.keys.toList()..sort()) {
    if (bars[channel]!.length * 10 < maxCoverage * 7) continue; // part-time
    if (lead == null) {
      lead = channel;
      continue;
    }
    final avg = sums[channel]! / counts[channel]!;
    final bestAvg = sums[lead]! / counts[lead]!;
    if (avg > bestAvg || (avg == bestAvg && counts[channel]! > counts[lead]!)) {
      lead = channel;
    }
  }
  final leadAvg = sums[lead]! / counts[lead]!;
  final descants = <int>{
    for (final channel in counts.keys)
      if (channel != lead && sums[channel]! / counts[channel]! > leadAvg)
        channel,
  };
  return (lead!, descants);
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

  void control(int tick, int channel, int controller, int value) =>
      _add(tick, 2, [0xB0 | channel, controller & 0x7F, value.clamp(0, 127)]);

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

  /// Fractional media-time ms of a (possibly fractional) [tick].
  double msOf(double tick) {
    var lo = 0, hi = _ticks.length - 1, best = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_ticks[mid] <= tick) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return _msStarts[best] + (tick - _ticks[best]) * _msPerTick[best];
  }

  /// Fractional tick of media-time [ms]; the caller rounds to a beat index.
  /// Takes a [num] so the steady percussion clock — which works in
  /// fractional milliseconds — can invert the map without quantizing first.
  double tickOf(num ms) {
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
