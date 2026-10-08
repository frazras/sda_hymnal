import 'dart:typed_data';

import 'package:sdahymnal/services/midi_transform.dart';

/// Pure-Dart chord detection for the bundled hymn tunes (assets/midi/NNN.mid):
/// extracts every sounding note, weighs the pitch classes beat by beat against
/// a small set of chord templates, and merges the winners into a timed
/// [ChordTrack] the player can follow.

/// MIDI percussion channel (0-based); never contributes to harmony.
const int _percussionChannel = 9;

/// Default tempo (microseconds per quarter note) when a file has no FF 51.
const int _defaultUsPerQuarter = 500000;

/// Chromatic root names by pitch class, flat and sharp spellings.
const List<String> _flatNames = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
];
const List<String> _sharpNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
];

/// Chord templates scored per beat window: quality suffix and the semitone
/// intervals above the root.
const List<(String, List<int>)> _templates = [
  ('', [0, 4, 7]),
  ('m', [0, 3, 7]),
  ('7', [0, 4, 7, 10]),
  ('maj7', [0, 4, 7, 11]),
  ('m7', [0, 3, 7, 10]),
  ('dim', [0, 3, 6]),
  ('sus4', [0, 5, 7]),
  ('aug', [0, 4, 8]),
];

/// One detected chord, in media time of the rendered file.
class ChordEvent {
  const ChordEvent({
    required this.startMs,
    required this.durationMs,
    required this.rootPc,
    required this.quality,
    required this.beatMs,
  });

  /// Media-time ms in the rendered file.
  final int startMs;
  final int durationMs;

  /// 0..11 pitch class of the chord root (untransposed).
  final int rootPc;

  /// '', 'm', '7', 'maj7', 'm7', 'dim', 'sus4' or 'aug'.
  final String quality;

  /// Media-time ms of every beat onset the chord is held through, the first
  /// being [startMs] itself — a 4-beat hold has 4 entries. The player strip
  /// shows one dot per repeat (entries beyond the first) and lights each dot
  /// as its beat strikes.
  final List<int> beatMs;
}

/// The detected harmony of one MIDI file: merged chords in chronological
/// order plus the grid of measures they sit on.
class ChordTrack {
  ChordTrack({
    required this.chords,
    required this.key,
    required this.beatsPerBar,
    this.denominator = 4,
    required this.measureStartMs,
  });

  /// Chronological, merged, non-empty.
  final List<ChordEvent> chords;

  /// Written key from the file's FF 59, when present.
  final MidiKey? key;

  /// Time-signature numerator (default 4).
  final int beatsPerBar;

  /// Time-signature beat unit, retained for compound-meter chart labels.
  final int denominator;

  String get meterLabel => '$beatsPerBar/$denominator';

  /// Media-time ms of each measure start, from the start of the file.
  final List<int> measureStartMs;

  /// Index of the last chord with `startMs <= positionMs`; -1 before the
  /// first chord.
  int indexAt(int positionMs) =>
      _lastAtOrBefore(chords.length, (i) => chords[i].startMs, positionMs);

  /// Index of the last measure starting at or before [positionMs]; -1 before
  /// the first.
  int measureAt(int positionMs) => _lastAtOrBefore(
      measureStartMs.length, (i) => measureStartMs[i], positionMs);
}

/// Binary search: greatest `i < length` with `startOf(i) <= positionMs`, or
/// -1 when even the first start is later.
int _lastAtOrBefore(int length, int Function(int) startOf, int positionMs) {
  var lo = 0, hi = length - 1, best = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (startOf(mid) <= positionMs) {
      best = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return best;
}

/// Label for a chord root+quality as the player should print it, e.g. 'G',
/// 'Em', 'D7', 'Bb', 'F#m7'. The root is shifted by [transposeSemitones];
/// spelling prefers flats when the (transposed) key is a flat key, sharps
/// when it is a sharp key, and sharps when [key] is null.
String chordLabel(
    int rootPc, String quality, MidiKey? key, int transposeSemitones) {
  final pc = ((rootPc + transposeSemitones) % 12 + 12) % 12;
  var flats = false;
  if (key != null) {
    final label = transposedKeyLabel(key, transposeSemitones);
    if (label.contains('b')) {
      flats = true;
    } else if (!label.contains('#')) {
      flats = _transposedSf(key.sf, transposeSemitones) < 0;
    }
  }
  return (flats ? _flatNames[pc] : _sharpNames[pc]) + quality;
}

/// New sharps/flats count after transposing, wrapped to -7..+7 the same way
/// transformMidi rewrites the FF 59 (ties prefer the flat spelling).
int _transposedSf(int sf, int semitones) {
  final x = (sf + 7 * semitones) % 12; // Dart %: always 0..11 here
  if (x == 6) return -6;
  return x > 6 ? x - 12 : x;
}

// ---------------------------------------------------------------------------
// Chord simplification
// ---------------------------------------------------------------------------

/// How much harmonic detail [simplifyTrack] keeps.
enum ChordLevel { simple, medium, original }

/// Colour-tone rewrites shared by both reduced levels. The two qualities that
/// need more than a suffix swap — '7' (context decides whether it survives at
/// medium) and 'dim' (its root moves) — are handled in [simplifyTrack].
const Map<String, String> _colorRemap = {
  'maj7': '', 'sus4': '', 'aug': '', 'm7': 'm', //
};

/// Semitones above the tonic of the seven major-scale degrees.
const List<int> _majorScaleDegrees = [0, 2, 4, 5, 7, 9, 11];

/// Degrees (semitones above the tonic) whose diatonic triad is minor in a
/// major key: ii, iii and vi.
const List<int> _minorTriadDegrees = [2, 4, 9];

/// Returns [track] reduced to [level]. Both reduced levels apply, in order:
///
/// 1. Vocabulary substitution — colour tones fall to their triad ('maj7'/
///    'sus4'/'aug' become major, 'm7' becomes minor), and a 'dim' is
///    replaced by the dominant it stands for: the diminished root is that
///    dominant's 3rd, so the root drops a major third (Bdim becomes G, not
///    the out-of-key Bm). A dominant '7' survives only at
///    [ChordLevel.medium] and only when it actually resolves — the next
///    event's (substituted) root a fourth above, the V7-to-I motion of C7
///    to F; every other '7' falls to plain major.
///
/// 2. Diatonic filter (skipped when [ChordTrack.key] is null) — the
///    detector sometimes misreads a thin passing beat as an out-of-key
///    chord (a G/B inversion in C scored as a B triad). Such artifacts are
///    removed by substitution toward the prevailing harmony: a chord whose
///    root lies outside the key's seven-tone scale or on its leading tone,
///    or a minor chord on a degree other than ii/iii/vi, extends the
///    previous kept chord instead (an artifact opening the track takes the
///    identity of the next kept chord). A major on any other scale root
///    passes, which keeps real secondary dominants like E major in G.
///
/// 3. Harmonic-rhythm quantization ([ChordLevel.simple] only) — harmony
///    snaps to the half-bar so beginners see at most two changes per bar:
///    each bar splits into a bucket of its first ceil(B/2) beats and one of
///    the rest, and every bucket sounds the chord governing the majority of
///    its beats (ties go to the chord on the bucket's earliest beat).
///    Pickup beats before the first measure keep their filtered chord.
///
/// Adjacent events left identical in (root, quality) merge: the run keeps
/// the first event's [ChordEvent.startMs], sums durations, and concatenates
/// [ChordEvent.beatMs] in time order, so the track's total beat count never
/// changes. [ChordLevel.original] returns [track] itself; the other levels
/// build a fresh track and leave the input untouched.
ChordTrack simplifyTrack(ChordTrack track, ChordLevel level) {
  if (level == ChordLevel.original) return track;

  // Vocabulary pass 1: substituted (root, quality) per event. Only 'dim'
  // moves the root; at this stage '7' marks a dominant candidate whose fate
  // pass 2 decides.
  final subs = <(int, String)>[
    for (final e in track.chords)
      e.quality == 'dim'
          ? ((e.rootPc + 8) % 12, '7')
          : (e.rootPc, _colorRemap[e.quality] ?? e.quality),
  ];

  // Vocabulary pass 2: settle the dominants. Simple has no '7' in its
  // vocabulary at all; medium keeps one only when the next event's root
  // (stable after pass 1) is a fourth up. Everything else falls to plain
  // major.
  for (var i = 0; i < subs.length; i++) {
    if (subs[i].$2 != '7') continue;
    final resolves = level == ChordLevel.medium &&
        i + 1 < subs.length &&
        subs[i + 1].$1 == (subs[i].$1 + 5) % 12;
    if (!resolves) subs[i] = (subs[i].$1, '');
  }

  var events = <ChordEvent>[
    for (var i = 0; i < subs.length; i++)
      ChordEvent(
        startMs: track.chords[i].startMs,
        durationMs: track.chords[i].durationMs,
        rootPc: subs[i].$1,
        quality: subs[i].$2,
        beatMs: List<int>.of(track.chords[i].beatMs),
      ),
  ];

  final key = track.key;
  if (key != null) events = _substituteNonDiatonic(events, key);
  if (level == ChordLevel.simple) events = _quantizeToHalfBars(events, track);

  return ChordTrack(
    chords: _mergeAdjacent(events),
    key: track.key,
    beatsPerBar: track.beatsPerBar,
    denominator: track.denominator,
    measureStartMs: track.measureStartMs,
  );
}

/// Replaces every non-diatonic event in [events] — a detection artifact —
/// with the surrounding harmony: it extends the previous kept event, or,
/// when it opens the track, takes the identity of the next kept event while
/// keeping its own start and beats. Returns [events] unchanged when nothing
/// diatonic remains to substitute toward.
List<ChordEvent> _substituteNonDiatonic(List<ChordEvent> events, MidiKey key) {
  // Major tonic pc via the circle of fifths. A minor key needs no separate
  // handling: the natural-minor scale of its relative minor (tonic + 9) is
  // the same pitch-class set, its i/iv/v minor triads sit on the very roots
  // that are ii/iii/vi of the relative major, and the harmonic-minor V major
  // is admitted by the any-scale-root rule for majors below.
  final tonic = (key.sf * 7) % 12;
  final scale = {for (final d in _majorScaleDegrees) (tonic + d) % 12};
  final minorRoots = {for (final d in _minorTriadDegrees) (tonic + d) % 12};
  final leadingTone = (tonic + 11) % 12;

  // Majors — and medium's dominant 7s — pass on any scale root except the
  // leading tone, keeping secondary dominants like E in G; degree vii's only
  // real harmony is the diminished chord the vocabulary already rewrote to
  // V, so a major there is the classic inversion misread (G/B in C scored
  // as a B triad). Minors are trusted only on ii/iii/vi — a detected minor
  // on I/IV/V is mode-mixture noise — and out-of-scale roots always fail.
  bool diatonic(ChordEvent e) =>
      scale.contains(e.rootPc) &&
      e.rootPc != leadingTone &&
      (e.quality != 'm' || minorRoots.contains(e.rootPc));

  final out = <ChordEvent>[];
  final leading = <ChordEvent>[]; // artifacts before the first kept chord
  for (final e in events) {
    if (diatonic(e)) {
      for (final artifact in leading) {
        out.add(ChordEvent(
          startMs: artifact.startMs,
          durationMs: artifact.durationMs,
          rootPc: e.rootPc,
          quality: e.quality,
          beatMs: artifact.beatMs,
        ));
      }
      leading.clear();
      out.add(e);
    } else if (out.isNotEmpty) {
      out[out.length - 1] = _joined(out.last, e);
    } else {
      leading.add(e);
    }
  }
  return out.isEmpty ? events : out;
}

/// Snaps the harmony of [events] to the half-bar grid of [track]: each beat
/// is assigned the chord of the majority of its half-bar bucket (ties go to
/// the bucket's earliest beat), while pickup beats before the first measure
/// keep their own chord. Returns beat-level events for [_mergeAdjacent] to
/// fuse; the total beat count and duration are conserved exactly.
List<ChordEvent> _quantizeToHalfBars(
    List<ChordEvent> events, ChordTrack track) {
  if (track.measureStartMs.isEmpty) return events;

  // One slice per beat onset; the last slice of an event runs to the
  // event's end, so slice durations sum to the event's duration.
  final slices = <ChordEvent>[];
  for (final e in events) {
    for (var i = 0; i < e.beatMs.length; i++) {
      final end =
          i + 1 < e.beatMs.length ? e.beatMs[i + 1] : e.startMs + e.durationMs;
      slices.add(ChordEvent(
        startMs: e.beatMs[i],
        durationMs: end - e.beatMs[i],
        rootPc: e.rootPc,
        quality: e.quality,
        beatMs: [e.beatMs[i]],
      ));
    }
  }

  // Bucket per slice: bar*2 for a bar's first ceil(B/2) beats, bar*2+1 for
  // the rest; -1 marks pickup beats before the first measure.
  final firstHalf = (track.beatsPerBar + 1) ~/ 2;
  final buckets = List<int>.filled(slices.length, -1);
  var bar = -1, beatInBar = 0;
  for (var i = 0; i < slices.length; i++) {
    final b = track.measureAt(slices[i].startMs);
    if (b != bar) {
      bar = b;
      beatInBar = 0;
    } else {
      beatInBar++;
    }
    if (b >= 0) buckets[i] = 2 * b + (beatInBar < firstHalf ? 0 : 1);
  }

  // Relabel each bucket's slices (contiguous, since slices are
  // chronological) to its governing chord.
  var i = 0;
  while (i < slices.length) {
    var j = i + 1;
    while (j < slices.length && buckets[j] == buckets[i]) {
      j++;
    }
    if (buckets[i] >= 0) {
      final counts = <(int, String), int>{};
      var bestCount = 0;
      for (var k = i; k < j; k++) {
        final id = (slices[k].rootPc, slices[k].quality);
        final c = (counts[id] ?? 0) + 1;
        counts[id] = c;
        if (c > bestCount) bestCount = c;
      }
      // Earliest beat whose chord reaches the majority count — on a tie
      // that is the chord sounding at the bucket's first beat.
      var winner = (slices[i].rootPc, slices[i].quality);
      for (var k = i; k < j; k++) {
        final id = (slices[k].rootPc, slices[k].quality);
        if (counts[id] == bestCount) {
          winner = id;
          break;
        }
      }
      for (var k = i; k < j; k++) {
        slices[k] = ChordEvent(
          startMs: slices[k].startMs,
          durationMs: slices[k].durationMs,
          rootPc: winner.$1,
          quality: winner.$2,
          beatMs: slices[k].beatMs,
        );
      }
    }
    i = j;
  }
  return slices;
}

/// Merges every run of adjacent events sharing (rootPc, quality) into one.
List<ChordEvent> _mergeAdjacent(List<ChordEvent> events) {
  final out = <ChordEvent>[];
  for (final e in events) {
    if (out.isNotEmpty &&
        out.last.rootPc == e.rootPc &&
        out.last.quality == e.quality) {
      out[out.length - 1] = _joined(out.last, e);
    } else {
      out.add(e);
    }
  }
  return out;
}

/// [a] extended through [b]: keeps a's identity and start, sums the
/// durations, and concatenates the beat onsets in time order.
ChordEvent _joined(ChordEvent a, ChordEvent b) => ChordEvent(
      startMs: a.startMs,
      durationMs: a.durationMs + b.durationMs,
      rootPc: a.rootPc,
      quality: a.quality,
      beatMs: [...a.beatMs, ...b.beatMs],
    );

/// Detects the chord track of the SMF in [midiBytes]; null when the bytes are
/// not a parseable SMF or contain no usable notes. Pure and synchronous.
ChordTrack? detectChords(Uint8List midiBytes) {
  final _Score score;
  try {
    score = _extract(midiBytes);
  } on FormatException {
    return null;
  }
  if (score.notes.isEmpty) return null;

  final tempo = _TempoMap(score.tempi, score.division);
  final chords = _detect(score, tempo);
  if (chords.isEmpty) return null;

  // Measures of beatsPerBar beats, each beat division*4/denominator ticks,
  // laid out from tick 0 across the full note span.
  final beatTicks = score.division * 4 ~/ score.denominator;
  final measureTicks = score.beatsPerBar * beatTicks;
  final measureStartMs = <int>[
    for (var t = 0; t < score.endTick; t += measureTicks) tempo.msOf(t),
  ];

  return ChordTrack(
    chords: chords,
    key: score.key,
    beatsPerBar: score.beatsPerBar,
    denominator: score.denominator,
    measureStartMs: measureStartMs,
  );
}

/// Scores each quarter-note window against the chord templates and merges
/// consecutive identical winners into [ChordEvent]s.
List<ChordEvent> _detect(_Score score, _TempoMap tempo) {
  // Compound meter needs eighth-note windows so harmony can change on the
  // second dotted-quarter pulse instead of being smeared across a quarter.
  final compound = score.denominator == 8 &&
      score.beatsPerBar >= 6 &&
      score.beatsPerBar % 3 == 0;
  final step = compound ? score.division ~/ 2 : score.division;
  final spans = <(int start, int end, int rootPc, String quality)>[];

  for (var w0 = 0; w0 < score.endTick; w0 += step) {
    final w1 = w0 + step;
    final wEnd = w1 < score.endTick ? w1 : score.endTick;

    // Pitch-class weights: overlap ticks of every note covering more than a
    // quarter of the window; the lowest such note is the bass.
    final weights = List<int>.filled(12, 0);
    var total = 0;
    int? bass;
    for (final n in score.notes) {
      if (n.endTick <= w0 || n.startTick >= w1) continue;
      final overlap = (n.endTick < w1 ? n.endTick : w1) - //
          (n.startTick > w0 ? n.startTick : w0);
      if (overlap * 4 <= step) continue;
      weights[n.pitch % 12] += overlap;
      total += overlap;
      if (bass == null || n.pitch < bass) bass = n.pitch;
    }

    // A lone pitch class is no harmony: extend the previous chord instead.
    if (weights.where((w) => w > 0).length < 2) {
      if (spans.isNotEmpty) {
        final last = spans.last;
        spans[spans.length - 1] = (last.$1, wEnd, last.$3, last.$4);
      }
      continue;
    }

    final bassPc = bass! % 12;
    var best = double.negativeInfinity;
    var bestRoot = 0;
    var bestQuality = '';
    for (var root = 0; root < 12; root++) {
      for (final (quality, intervals) in _templates) {
        var inChord = 0;
        for (final interval in intervals) {
          inChord += weights[(root + interval) % 12];
        }
        var s =
            inChord - 1.5 * (total - inChord) - 0.02 * intervals.length * step;
        if (bassPc == root) s += 0.3 * step;
        if (s > best) {
          best = s;
          bestRoot = root;
          bestQuality = quality;
        }
      }
    }

    if (spans.isNotEmpty &&
        spans.last.$3 == bestRoot &&
        spans.last.$4 == bestQuality) {
      final last = spans.last;
      spans[spans.length - 1] = (last.$1, wEnd, last.$3, last.$4);
    } else {
      spans.add((w0, wEnd, bestRoot, bestQuality));
    }
  }

  return [
    for (final (start, end, rootPc, quality) in spans)
      ChordEvent(
        startMs: tempo.msOf(start),
        durationMs: tempo.msOf(end) - tempo.msOf(start),
        rootPc: rootPc,
        quality: quality,
        // Spans start on a window boundary and grow in whole windows, so
        // stepping by the window size enumerates the beat onsets.
        beatMs: [for (var bt = start; bt < end; bt += step) tempo.msOf(bt)],
      ),
  ];
}

// ---------------------------------------------------------------------------
// SMF note extraction
// ---------------------------------------------------------------------------

class _Note {
  _Note(this.startTick, this.pitch);

  final int startTick;
  final int pitch;
  int endTick = 0;
}

/// Everything [detectChords] needs from one SMF.
class _Score {
  _Score(this.division);

  final int division;
  final List<_Note> notes = [];
  final List<(int tick, int usPerQuarter)> tempi = [];
  MidiKey? key;
  int beatsPerBar = 4;
  int denominator = 4;

  /// End of the last note, in ticks.
  int get endTick =>
      notes.fold(0, (max, n) => n.endTick > max ? n.endTick : max);
}

/// Parses [bytes], collecting notes (channels other than percussion), the
/// tempo map, and the first key and time signatures. Throws [FormatException]
/// on malformed input or an SMPTE-timed file.
_Score _extract(Uint8List bytes) {
  final chunks = _readChunks(bytes);
  final header = chunks.firstWhere((c) => c.id == 'MThd',
      orElse: () => throw const FormatException('Missing MThd'));
  if (header.data.length < 6) throw const FormatException('Short MThd');
  final division = (header.data[4] << 8) | header.data[5];
  if (division == 0 || division & 0x8000 != 0) {
    throw const FormatException('Unsupported SMF division');
  }

  final score = _Score(division);
  var sawTimeSignature = false;
  for (final chunk in chunks) {
    if (chunk.id != 'MTrk') continue;
    var tick = 0;
    final open = <int, List<_Note>>{}; // channel<<8 | pitch -> open notes
    for (final e in _trackEvents(chunk.data)) {
      tick += e.delta;
      final hi = e.status & 0xF0;
      final ch = e.status & 0x0F;
      if (hi == 0x90 && e.body[1] > 0) {
        if (ch == _percussionChannel) continue;
        final note = _Note(tick, e.body[0]);
        (open[ch << 8 | e.body[0]] ??= []).add(note);
        score.notes.add(note);
      } else if (hi == 0x80 || hi == 0x90) {
        if (ch == _percussionChannel) continue;
        final pending = open[ch << 8 | e.body[0]];
        if (pending != null && pending.isNotEmpty) {
          pending.removeAt(0).endTick = tick;
        }
      } else if (e.status == 0xFF) {
        final type = e.body[0];
        final (len, at) = _readVarLen(e.body, 1);
        if (type == 0x51 && len >= 3) {
          final us =
              (e.body[at] << 16) | (e.body[at + 1] << 8) | e.body[at + 2];
          score.tempi.add((tick, us));
        } else if (type == 0x59 && len >= 2 && score.key == null) {
          score.key =
              MidiKey(_signedByte(e.body[at]), minor: e.body[at + 1] == 1);
        } else if (type == 0x58 && len >= 2 && !sawTimeSignature) {
          sawTimeSignature = true;
          if (e.body[at] > 0) score.beatsPerBar = e.body[at];
          score.denominator = 1 << e.body[at + 1];
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
  score.notes.removeWhere((n) => n.endTick <= n.startTick);
  return score;
}

int _signedByte(int b) => b > 0x7F ? b - 0x100 : b;

/// Cumulative tick-to-milliseconds map built from the FF 51 tempo events;
/// each tempo takes effect at its own tick.
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

  int msOf(int tick) {
    final i = _lastAtOrBefore(_ticks.length, (i) => _ticks[i], tick);
    return (_msStarts[i] + (tick - _ticks[i]) * _msPerTick[i]).round();
  }
}

// ---------------------------------------------------------------------------
// SMF parsing (same shapes as midi_transform.dart, but deltas are decoded
// since no rewrite happens here)
// ---------------------------------------------------------------------------

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
