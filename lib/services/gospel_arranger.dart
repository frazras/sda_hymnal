import 'dart:typed_data';

import 'package:sdahymnal/services/chord_detect.dart';

/// Gospel accompaniment engine for the bundled hymn tunes (assets/midi/NNN.mid):
/// keeps the hymn's melody line but replaces the written SATB accompaniment
/// with a generated modern-gospel backing — Rhodes stabs, finger bass with
/// chromatic walk-ins, and a subtle hat/kick/sidestick groove — driven by the
/// harmony that [detectChords] hears in the original file.
///
/// The output is a fresh format-1 SMF at the original division, with the
/// original tempo/time-signature/key-signature meta events copied into a
/// conductor track, so it plays at the same speed and key as the hymn it
/// replaces.

/// MIDI percussion channel (0-based).
const int _percussionChannel = 9;

/// Default tempo (microseconds per quarter note) when a file has no FF 51.
const int _defaultUsPerQuarter = 500000;

/// GM programs: Electric Piano 1 (Rhodes) and Finger Bass.
const int _rhodesProgram = 4;
const int _fingerBassProgram = 33;

/// GM percussion keys.
const int _kick = 36;
const int _sidestick = 37;
const int _closedHat = 42;

/// Stab intervals in semitones above the root, per detected chord quality.
/// The root is omitted everywhere — the bass owns it. Colors: every quality
/// gets the 9th; dominant/minor stabs carry their 7th.
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

/// Comp stabs live in this octave band (around middle C).
const int _stabLow = 60;

/// Bass notes live in this octave band.
const int _bassLow = 36;

/// One detected chord as it governs a beat.
typedef _Chord = ({int rootPc, String quality});

/// Rewrites the hymn SMF in [originalBytes] as a modern-gospel arrangement:
///
/// * conductor track — the original tempo (FF 51), time-signature (FF 58) and
///   key-signature (FF 59) meta events, copied verbatim at their ticks;
/// * channel 0, Rhodes — the melody (the input channel with the highest
///   average pitch), notes copied verbatim with velocities scaled to 0.9
///   (capped at 112) so the backing can sit around it;
/// * channel 1, Rhodes — rootless comp stabs on a beat-1 / off-beat / late-bar
///   pattern, voiced from the chord detected on each stab's own beat;
/// * channel 2, Finger Bass — root and fifth per bar, with a chromatic
///   approach note walking into every bar that changes chord;
/// * channel 9 — closed hat eighths with kick and sidestick, only across the
///   span where chords were detected.
///
/// Throws [FormatException] when [originalBytes] is not a well-formed SMF or
/// contains no detectable harmony (the caller falls back to the original).
Uint8List arrangeGospel(Uint8List originalBytes) {
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

  final conductor = _Track();
  for (final (tick, bytes) in song.metas) {
    conductor.meta(tick, bytes);
  }

  final melody = _Track()..program(0, 0, _rhodesProgram);
  for (final note in _melodyNotes(song)) {
    final velocity = (note.velocity * 0.9).round().clamp(1, 112);
    melody.note(note.startTick, 0, note.pitch, velocity,
        note.endTick - note.startTick);
  }

  final comp = _Track()..program(0, 1, _rhodesProgram);
  final bass = _Track()..program(0, 2, _fingerBassProgram);
  final drums = _Track();

  // (offset ticks, velocity, length ticks) per bar.
  final stabHits = n == 3
      ? [(0, 78, d), (3 * d ~/ 2, 64, d ~/ 2), (2 * d, 68, d ~/ 2)]
      : [(0, 78, d), (5 * d ~/ 2, 64, d ~/ 2), (3 * d, 70, d ~/ 2)];
  final kickHits = n == 3 ? [(0, 76)] : [(0, 78), (2 * d, 78)];
  final stickHits = n == 3 ? [(2 * d, 60)] : [(d, 66), (3 * d, 66)];

  for (var bar = firstBeat ~/ n; bar <= lastBeat ~/ n; bar++) {
    final barStart = bar * n * d;

    // Rhodes stabs: each hit sounds the chord governing its own beat, so a
    // mid-bar chord change (chords are beat-aligned) splits the pattern.
    for (final (offset, velocity, length) in stabHits) {
      final chord = beatChords[bar * n + offset ~/ d];
      if (chord == null) continue;
      for (final pitch in _voiceStab(chord)) {
        comp.note(barStart + offset, 1, pitch, velocity, length);
      }
    }

    // Bass: root on 1, fifth on 3, each from the chord on its own beat.
    final rootChord = beatChords[bar * n];
    if (rootChord != null) {
      bass.note(barStart, 2, _voiceBass(rootChord.rootPc), 92, 3 * d ~/ 2);
    }
    final fifthChord = beatChords[bar * n + 2];
    if (fifthChord != null) {
      bass.note(barStart + 2 * d, 2, _voiceBass(fifthChord.rootPc + 7),
          n == 3 ? 76 : 80, n == 3 ? d ~/ 2 : d);
    }

    // The classic walk-in: when the next bar opens on a different chord, the
    // last half-beat becomes a chromatic approach from below its root.
    final barEndChord = beatChords[bar * n + n - 1];
    final nextChord = beatChords[(bar + 1) * n];
    if (barEndChord != null && nextChord != null && nextChord != barEndChord) {
      bass.note(barStart + n * d - d ~/ 2, 2,
          _voiceBass(nextChord.rootPc + 11), 84, d ~/ 2);
    }

    // Drums, only where harmony exists: hat eighths plus kick and sidestick.
    for (var k = 0; k < 2 * n; k++) {
      final offset = k * d ~/ 2;
      if (!_inSpan(bar * n + offset ~/ d, firstBeat, lastBeat)) continue;
      final velocity = n == 3 ? 44 : (k.isEven ? 58 : 46);
      drums.note(barStart + offset, _percussionChannel, _closedHat, velocity,
          d ~/ 4);
    }
    for (final (offset, velocity) in kickHits) {
      if (!_inSpan(bar * n + offset ~/ d, firstBeat, lastBeat)) continue;
      drums.note(barStart + offset, _percussionChannel, _kick, velocity, d ~/ 4);
    }
    for (final (offset, velocity) in stickHits) {
      if (!_inSpan(bar * n + offset ~/ d, firstBeat, lastBeat)) continue;
      drums.note(
          barStart + offset, _percussionChannel, _sidestick, velocity, d ~/ 4);
    }
  }

  return _writeSmf(d, [conductor, melody, comp, bass, drums]);
}

bool _inSpan(int beat, int firstBeat, int lastBeat) =>
    beat >= firstBeat && beat <= lastBeat;

/// The stab tones of [chord], each transposed by octaves into the band
/// starting at [_stabLow] (60..71 ⊂ 60..75), deduplicated, low to high.
List<int> _voiceStab(_Chord chord) {
  final tones = _stabIntervals[chord.quality] ?? _stabIntervals['']!;
  final pitches = <int>{
    for (final interval in tones) _stabLow + (chord.rootPc + interval) % 12,
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

/// Everything [arrangeGospel] needs from the original file.
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
