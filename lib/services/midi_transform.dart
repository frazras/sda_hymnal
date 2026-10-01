import 'dart:typed_data';

/// Pure-Dart Standard MIDI File (SMF) transformer for the bundled hymn tunes
/// (assets/midi/NNN.mid): transposes notes, retargets the GM instrument, and
/// updates the key signature, always emitting a valid SMF — running status is
/// preserved byte-for-byte and track lengths are recomputed when events are
/// inserted.

/// MIDI percussion channel (0-based); never transposed or re-programmed.
const int _percussionChannel = 9;

/// Chromatic tonic names, flat spellings preferred; index = pitch class.
const List<String> _flatNames = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
];

/// A key signature as stored in an FF 59 meta event.
class MidiKey {
  const MidiKey(this.sf, {this.minor = false});

  /// Sharps (positive) or flats (negative) on the staff, -7..+7.
  final int sf;
  final bool minor;

  static const List<String> _majors = [
    'Cb', 'Gb', 'Db', 'Ab', 'Eb', 'Bb', 'F', 'C', //
    'G', 'D', 'A', 'E', 'B', 'F#', 'C#',
  ];
  static const List<String> _minors = [
    'Abm', 'Ebm', 'Bbm', 'Fm', 'Cm', 'Gm', 'Dm', 'Am', //
    'Em', 'Bm', 'F#m', 'C#m', 'G#m', 'D#m', 'A#m',
  ];

  /// Conventional key name ('F', 'F#', 'Bb', 'Am', …); minor keys are named
  /// by their relative-minor tonic.
  String get label => (minor ? _minors : _majors)[sf.clamp(-7, 7).toInt() + 7];
}

/// The first FF 59 key-signature meta event in [bytes], or null when the file
/// has none (or cannot be parsed as an SMF).
MidiKey? readKeySignature(Uint8List bytes) {
  try {
    for (final chunk in _readChunks(bytes)) {
      if (chunk.id != 'MTrk') continue;
      for (final e in _trackEvents(chunk.data)) {
        if (e.status != 0xFF || e.body[0] != 0x59) continue;
        final (len, at) = _readVarLen(e.body, 1);
        if (len < 2) continue;
        return MidiKey(_signedByte(e.body[at]), minor: e.body[at + 1] == 1);
      }
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Full format-0/1 MIDI timeline at 1x speed, including trailing rests and
/// percussion. Integrates every tempo change across all tracks; absent tempo
/// events use the SMF default of 120 BPM. This does not require an audio engine.
/// Unsupported timing/formats and malformed data throw [FormatException].
Duration readMidiDuration(Uint8List bytes) {
  final chunks = _readChunks(bytes);
  final header = chunks.first.data;
  if (header.length < 6) throw const FormatException('Short MIDI header');
  final format = (header[0] << 8) | header[1];
  final count = (header[2] << 8) | header[3];
  final division = (header[4] << 8) | header[5];
  final tracks = chunks.where((c) => c.id == 'MTrk').toList();
  if (format > 1 ||
      count == 0 ||
      tracks.length != count ||
      (format == 0 && count != 1)) {
    throw const FormatException('Unsupported MIDI format or track count');
  }
  if (division == 0 || division & 0x8000 != 0) {
    throw const FormatException('Unsupported MIDI timing division');
  }
  final tempi = <({int tick, int micros, int order})>[];
  var endTick = 0;
  for (final track in tracks) {
    var tick = 0;
    for (final event in _trackEvents(track.data)) {
      tick += _readVarLen(event.delta, 0).$1;
      if (event.status != 0xff) continue;
      if (event.body[0] == 0x2f) break;
      if (event.body[0] != 0x51) continue;
      final (length, at) = _readVarLen(event.body, 1);
      if (length != 3) throw const FormatException('Invalid MIDI tempo');
      final micros = (event.body[at] << 16) |
          (event.body[at + 1] << 8) |
          event.body[at + 2];
      if (micros == 0) throw const FormatException('Zero MIDI tempo');
      tempi.add((tick: tick, micros: micros, order: tempi.length));
    }
    if (tick > endTick) endTick = tick;
  }
  tempi.sort((a, b) =>
      a.tick != b.tick ? a.tick.compareTo(b.tick) : a.order.compareTo(b.order));
  var tick = 0;
  var microsPerQuarter = 500000;
  // Accumulate integer tick*tempo products before dividing, avoiding drift
  // from rounding each tempo segment separately.
  var elapsed = 0;
  for (final tempo in tempi) {
    elapsed += (tempo.tick - tick) * microsPerQuarter;
    tick = tempo.tick;
    microsPerQuarter = tempo.micros;
  }
  elapsed += (endTick - tick) * microsPerQuarter;
  return Duration(microseconds: (elapsed / division).round());
}

/// Name of the key [semitones] above [original]. Transposed tonics prefer
/// flat spellings ([_flatNames]); [semitones] == 0 keeps the original name.
String transposedKeyLabel(MidiKey original, int semitones) {
  if (semitones == 0) return original.label;
  final tonic = (original.sf * 7 + (original.minor ? 9 : 0)) % 12;
  final name = _flatNames[(tonic + semitones) % 12];
  return original.minor ? '${name}m' : name;
}

/// Rewrites the SMF in [bytes]:
///
/// * [semitones] shifts every Note-Off/Note-On/Poly-Aftertouch note byte
///   (clamped 0..127) and the FF 59 key signature; the percussion channel is
///   left untouched.
/// * [forceProgram] (GM program 0..127) overwrites every Program-Change data
///   byte and inserts a delta-0 Program Change at the start of the first
///   track that plays notes on a channel having no Program Change of its own
///   (such channels otherwise default to program 0). Percussion is excluded.
///
/// Throws [FormatException] when [bytes] is not a well-formed SMF.
Uint8List transformMidi(
  Uint8List bytes, {
  int semitones = 0,
  int? forceProgram,
  Map<int, int>? channelPrograms,
  Map<int, int>? channelVolumes,
  Set<int>? mutedChannels,
}) {
  if (forceProgram != null) {
    RangeError.checkValueInInterval(forceProgram, 0, 127, 'forceProgram');
  }
  channelPrograms?.forEach((ch, program) {
    RangeError.checkValueInInterval(ch, 0, 15, 'channelPrograms key');
    RangeError.checkValueInInterval(program, 0, 127, 'channelPrograms value');
  });
  channelVolumes?.forEach((ch, volume) {
    RangeError.checkValueInInterval(ch, 0, 15, 'channelVolumes key');
    RangeError.checkValueInInterval(volume, 0, 100, 'channelVolumes value');
  });
  // Per-channel programs win over the blanket forceProgram.
  int? programFor(int ch) => channelPrograms?[ch] ?? forceProgram;
  final remapping = forceProgram != null ||
      (channelPrograms != null && channelPrograms.isNotEmpty);
  final chunks = _readChunks(bytes);

  // Which non-percussion channels play notes but never see a Program Change,
  // and which track first plays them — that's where the default PC goes.
  final insertions = <int, List<int>>{}; // MTrk index -> channels
  if (remapping) {
    final firstNoteTrack = <int, int>{};
    final pcChannels = <int>{};
    var t = 0;
    for (final chunk in chunks) {
      if (chunk.id != 'MTrk') continue;
      for (final e in _trackEvents(chunk.data)) {
        final hi = e.status & 0xF0;
        if (hi == 0x90) firstNoteTrack.putIfAbsent(e.status & 0x0F, () => t);
        if (hi == 0xC0) pcChannels.add(e.status & 0x0F);
      }
      t++;
    }
    firstNoteTrack.forEach((ch, track) {
      if (ch == _percussionChannel ||
          pcChannels.contains(ch) ||
          programFor(ch) == null) {
        return;
      }
      (insertions[track] ??= []).add(ch);
    });
    for (final channels in insertions.values) {
      channels.sort();
    }
  }

  final out = BytesBuilder(copy: false);
  var t = 0;
  for (final chunk in chunks) {
    var data = chunk.data;
    if (chunk.id == 'MTrk') {
      data = _rewriteTrack(data, semitones, programFor,
          insertions[t] ?? const [], channelVolumes, mutedChannels);
      t++;
    }
    out.add(_chunkHeader(chunk.id, data.length));
    out.add(data);
  }
  return out.toBytes();
}

Uint8List _rewriteTrack(
  Uint8List data,
  int semitones,
  int? Function(int channel) programFor,
  List<int> insertChannels,
  Map<int, int>? channelVolumes,
  Set<int>? mutedChannels,
) {
  final out = BytesBuilder(copy: false);
  for (final ch in insertChannels) {
    out.add([0x00, 0xC0 | ch, programFor(ch)!]); // delta 0, before first note
  }
  for (final e in _trackEvents(data)) {
    out.add(e.delta);
    if (e.hasStatusByte) out.addByte(e.status);
    final hi = e.status & 0xF0;
    final ch = e.status & 0x0F;
    final percussion = ch == _percussionChannel;
    var body = e.body;
    if (hi == 0x90 && body[1] > 0 && (mutedChannels?.contains(ch) ?? false)) {
      body = Uint8List.fromList([body[0], 0]);
    } else if (hi == 0x90 &&
        body[1] > 0 &&
        channelVolumes != null &&
        channelVolumes.containsKey(ch)) {
      final volume = channelVolumes[ch]!;
      body = Uint8List.fromList([
        body[0],
        volume == 0 ? 0 : (body[1] * volume / 100).round().clamp(1, 127)
      ]);
    }
    if ((hi == 0x80 || hi == 0x90 || hi == 0xA0) &&
        !percussion &&
        semitones != 0) {
      body = Uint8List.fromList(body);
      body[0] = (body[0] + semitones).clamp(0, 127);
    } else if (hi == 0xC0 && !percussion && programFor(ch) != null) {
      body = Uint8List.fromList(body);
      body[0] = programFor(ch)!;
    } else if (e.status == 0xFF && body[0] == 0x59 && semitones != 0) {
      final (len, at) = _readVarLen(body, 1);
      if (len >= 2) {
        body = Uint8List.fromList(body);
        body[at] = _transposeSf(_signedByte(body[at]), semitones) & 0xFF;
      }
    }
    out.add(body);
  }
  return out.toBytes();
}

/// New sharps/flats count after transposing: each semitone up moves the key
/// 7 steps along the circle of fifths; out-of-range results wrap to the
/// enharmonic spelling within -7..+7 (ties prefer the flat one, Gb over F#).
int _transposeSf(int sf, int semitones) {
  final x = (sf + 7 * semitones) % 12; // Dart %: always 0..11 here
  if (x == 6) return -6;
  return x > 6 ? x - 12 : x;
}

int _signedByte(int b) => b > 0x7F ? b - 0x100 : b;

/// Note statistics per sounding non-percussion channel: how many note-ons it
/// has and their average pitch — enough to tell a bass line from the voices.
Map<int, ({int notes, double avgPitch})> channelStats(Uint8List bytes) {
  final chunks = _readChunks(bytes);
  final counts = <int, int>{};
  final sums = <int, int>{};
  for (final chunk in chunks) {
    if (chunk.id != 'MTrk') continue;
    for (final e in _trackEvents(chunk.data)) {
      final hi = e.status & 0xF0;
      final ch = e.status & 0x0F;
      if (hi == 0x90 && ch != _percussionChannel && e.body[1] > 0) {
        counts[ch] = (counts[ch] ?? 0) + 1;
        sums[ch] = (sums[ch] ?? 0) + e.body[0];
      }
    }
  }
  return {
    for (final ch in counts.keys)
      ch: (notes: counts[ch]!, avgPitch: sums[ch]! / counts[ch]!),
  };
}

// ---------------------------------------------------------------------------
// SMF parsing
// ---------------------------------------------------------------------------

/// One track event, keeping the original bytes so a rewrite can be lossless:
/// [delta] is the raw variable-length delta time, [hasStatusByte] is false
/// when the event used running status, and [body] is everything after the
/// status position (channel data bytes; `type len payload` for FF meta;
/// `len payload` for F0/F7 sysex).
class _MidiEvent {
  _MidiEvent(this.delta, this.hasStatusByte, this.status, this.body);

  final Uint8List delta;
  final bool hasStatusByte;
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
    final deltaStart = i;
    final (_, afterDelta) = _readVarLen(data, i);
    i = afterDelta;
    final delta = Uint8List.sublistView(data, deltaStart, i);
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
    yield _MidiEvent(delta, hasStatusByte, status,
        Uint8List.sublistView(data, bodyStart, i));
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

Uint8List _chunkHeader(String id, int length) {
  final h = Uint8List(8);
  for (var i = 0; i < 4; i++) {
    h[i] = id.codeUnitAt(i);
  }
  h[4] = (length >> 24) & 0xFF;
  h[5] = (length >> 16) & 0xFF;
  h[6] = (length >> 8) & 0xFF;
  h[7] = length & 0xFF;
  return h;
}

/// Sounding source tracks only. Track names are evidence, never inferred SATB.
List<({int index, String name})> midiParts(Uint8List bytes) {
  final result = <({int index, String name})>[];
  var index = 0;
  for (final chunk in _readChunks(bytes)) {
    if (chunk.id != 'MTrk') continue;
    var name = '';
    var sounding = false;
    for (final event in _trackEvents(chunk.data)) {
      if (event.status == 0xff && event.body[0] == 3) {
        final (length, at) = _readVarLen(event.body, 1);
        name = String.fromCharCodes(event.body.sublist(at, at + length)).trim();
      }
      if (event.status & 0xf0 == 0x90 && event.body[1] > 0) sounding = true;
    }
    if (sounding) {
      name = switch (name.toLowerCase()) {
        'soprano' => 'Soprano',
        'alto' => 'Alto',
        'tenor' || 'ténor' => 'Tenor',
        'bass' || 'basse' => 'Bass',
        _ => name,
      };
      result.add((index: index, name: name.isEmpty ? 'Track $index' : name));
    }
    index++;
  }
  return result;
}

/// Silence note events, including note-offs, without changing any event time,
/// conductor data or other tracks. Explicit statuses avoid running-status
/// corruption when a note is replaced by an empty sequencer-specific event.
Uint8List mixMidiParts(Uint8List bytes, Set<int> mutedTracks) {
  final out = BytesBuilder(copy: false);
  var index = 0;
  for (final chunk in _readChunks(bytes)) {
    var data = chunk.data;
    if (chunk.id == 'MTrk') {
      if (mutedTracks.contains(index)) {
        final track = BytesBuilder(copy: false);
        for (final event in _trackEvents(data)) {
          track.add(event.delta);
          final hi = event.status & 0xf0;
          if (hi == 0x80 || hi == 0x90 || hi == 0xa0) {
            track.add([0xff, 0x7f, 0]);
          } else {
            track.addByte(event.status);
            track.add(event.body);
          }
        }
        data = track.toBytes();
      }
      index++;
    }
    out.add(_chunkHeader(chunk.id, data.length));
    out.add(data);
  }
  return out.toBytes();
}

/// Change instruments per source track. MIDI instruments belong to channels,
/// so shared channels must be split before assigning independent programs.
/// Channel-wide controls are copied to split channels at their original times.
Uint8List instrumentMidiParts(Uint8List bytes, Map<int, int> trackPrograms) {
  if (trackPrograms.isEmpty) return bytes;
  final chunks = _readChunks(bytes);
  final tracks = chunks.where((c) => c.id == 'MTrk').toList();
  final channels = <int, Set<int>>{};
  final reserved = <int>{9};
  for (var i = 0; i < tracks.length; i++) {
    for (final e in _trackEvents(tracks[i].data)) {
      if (e.status >= 0xf0) continue;
      final ch = e.status & 15;
      reserved.add(ch);
      if (e.status & 0xf0 == 0x90 && e.body[1] > 0 && ch != 9) {
        (channels[i] ??= {}).add(ch);
      }
    }
  }
  final assignments = <(int, int), int>{};
  final programs = <int, int>{};
  final copies = <int, Set<int>>{};
  final indices = trackPrograms.keys.toList()..sort();
  for (final index in indices) {
    final program = trackPrograms[index]!;
    RangeError.checkValueInInterval(program, 0, 127, 'track program');
    final sourceChannels = channels[index];
    if (sourceChannels == null) {
      throw const FormatException(
          'This track has no melodic instrument to change.');
    }
    for (final channel in sourceChannels.toList()..sort()) {
      final shared = channels.entries
          .any((e) => e.key != index && e.value.contains(channel));
      var target = channel;
      if (shared) {
        final free =
            List.generate(16, (i) => i).where((ch) => !reserved.contains(ch));
        if (free.isEmpty) {
          throw const FormatException(
              'This MIDI has no free channels for another independent instrument.');
        }
        target = free.first;
        reserved.add(target);
        (copies[channel] ??= {}).add(target);
      }
      assignments[(index, channel)] = target;
      programs[target] = program;
    }
  }
  final out = BytesBuilder(copy: false);
  var index = 0;
  for (final chunk in chunks) {
    var data = chunk.data;
    if (chunk.id == 'MTrk') {
      final track = BytesBuilder(copy: false);
      if (index == 0) {
        for (final entry in programs.entries) {
          track.add([
            0,
            0xb0 | entry.key,
            0,
            0,
            0,
            0xb0 | entry.key,
            32,
            0,
            0,
            0xc0 | entry.key,
            entry.value
          ]);
        }
      }
      for (final e in _trackEvents(data)) {
        track.add(e.delta);
        final hi = e.status & 0xf0;
        final ch = e.status & 15;
        if (e.status >= 0xf0) {
          track.addByte(e.status);
          track.add(e.body);
        } else if (hi == 0x80 || hi == 0x90 || hi == 0xa0) {
          track.addByte(hi | (assignments[(index, ch)] ?? ch));
          track.add(e.body);
        } else {
          var first = true;
          for (final target in {ch, ...?copies[ch]}) {
            if (!first) track.addByte(0);
            first = false;
            track.addByte(hi | target);
            final program = programs[target];
            if (program != null && hi == 0xc0) {
              track.addByte(program);
            } else if (program != null &&
                hi == 0xb0 &&
                (e.body[0] == 0 || e.body[0] == 32)) {
              track.add([e.body[0], 0]);
            } else {
              track.add(e.body);
            }
          }
        }
      }
      data = track.toBytes();
      index++;
    }
    out.add(_chunkHeader(chunk.id, data.length));
    out.add(data);
  }
  return out.toBytes();
}

/// Retrigger sustained steelpan notes with a gentle roll. Other programs and
/// short notes are unchanged. Tempo events determine real-time strike spacing;
/// the original note boundaries and total song duration are preserved.
Uint8List steelpanRolls(Uint8List bytes) {
  final chunks = _readChunks(bytes);
  final header = chunks.first.data;
  if (header.length < 6) throw const FormatException('Short MIDI header');
  final division = (header[4] << 8) | header[5];
  if (header[1] > 1 || division == 0 || division & 0x8000 != 0) return bytes;
  final tracks = <List<_RollEvent>>[];
  for (final chunk in chunks.where((c) => c.id == 'MTrk')) {
    var tick = 0;
    final events = <_RollEvent>[];
    for (final e in _trackEvents(chunk.data)) {
      tick += _readVarLen(e.delta, 0).$1;
      events.add(
          _RollEvent(tick, tracks.length, events.length, e.status, e.body));
    }
    tracks.add(events);
  }
  final timeline = tracks.expand((t) => t).toList()
    ..sort((a, b) => a.tick != b.tick
        ? a.tick.compareTo(b.tick)
        : a.track != b.track
            ? a.track.compareTo(b.track)
            : a.order.compareTo(b.order));
  final tempos = <({int tick, double time, int tempo})>[
    (tick: 0, time: 0, tempo: 500000)
  ];
  for (final e in timeline) {
    if (e.status != 0xff || e.body[0] != 0x51) continue;
    final (length, at) = _readVarLen(e.body, 1);
    if (length != 3) continue;
    final tempo = (e.body[at] << 16) | (e.body[at + 1] << 8) | e.body[at + 2];
    if (tempo == 0) continue;
    final previous = tempos.last;
    tempos.add((
      tick: e.tick,
      time:
          previous.time + (e.tick - previous.tick) * previous.tempo / division,
      tempo: tempo
    ));
  }
  double timeAt(int tick) {
    final t = tempos.lastWhere((t) => t.tick <= tick);
    return t.time + (tick - t.tick) * t.tempo / division;
  }

  int tickAt(double time) {
    final t = tempos.lastWhere((t) => t.time <= time);
    return t.tick + ((time - t.time) * division / t.tempo).round();
  }

  final programs = List<int>.filled(16, 0);
  final active = <int, List<_RollEvent>>{};
  final eligible = <_RollEvent>{};
  final additions = <int, List<_RollEvent>>{};
  for (final e in timeline) {
    final kind = e.status & 0xf0;
    final channel = e.status & 15;
    if (kind == 0xc0) {
      programs[channel] = e.body[0];
      eligible.removeWhere((note) => note.status & 15 == channel);
    }
    if (kind != 0x80 && kind != 0x90) continue;
    final key = channel * 128 + e.body[0];
    final held = active.putIfAbsent(key, () => []);
    if (kind == 0x90 && e.body[1] > 0) {
      if (held.isEmpty && channel != 9 && programs[channel] == 114) {
        eligible.add(e);
      } else {
        // Shared-channel unisons cannot safely receive additional note-offs.
        eligible.removeAll(held);
      }
      held.add(e);
    } else if (held.isNotEmpty) {
      final own = held.indexWhere((note) => note.track == e.track);
      final start = held.removeAt(own < 0 ? 0 : own);
      if (!eligible.remove(start)) continue;
      final from = timeAt(start.tick);
      final until = timeAt(e.tick);
      if (until - from < 240000) continue;
      var lastTick = start.tick;
      var strike = 0;
      const strikeInterval = 1000000 / 6;
      for (var time = from + strikeInterval;
          time <= until - 40000;
          time += strikeInterval) {
        final tick = tickAt(time);
        if (tick <= lastTick || tick >= e.tick) continue;
        lastTick = tick;
        final velocity = (start.body[1] * (strike++ % 2 == 0 ? .92 : .98))
            .round()
            .clamp(1, 127);
        final list = additions.putIfAbsent(start.track, () => []);
        list.add(_RollEvent(tick, start.track, -2, 0x80 | channel,
            Uint8List.fromList([e.body[0], 0])));
        list.add(_RollEvent(tick, start.track, -1, 0x90 | channel,
            Uint8List.fromList([e.body[0], velocity])));
      }
    }
  }
  if (additions.isEmpty) return bytes;
  final output = BytesBuilder(copy: false);
  var track = 0;
  for (final chunk in chunks) {
    var data = chunk.data;
    if (chunk.id == 'MTrk') {
      if (additions.containsKey(track)) {
        final events = [...tracks[track], ...additions[track]!]..sort((a, b) =>
            a.tick != b.tick
                ? a.tick.compareTo(b.tick)
                : a.order.compareTo(b.order));
        final encoded = BytesBuilder(copy: false);
        var previous = 0;
        for (final e in events) {
          var delta = e.tick - previous;
          final vlq = <int>[delta & 127];
          while ((delta >>= 7) > 0) {
            vlq.insert(0, (delta & 127) | 128);
          }
          encoded.add(vlq);
          encoded.addByte(e.status);
          encoded.add(e.body);
          previous = e.tick;
        }
        data = encoded.toBytes();
      }
      track++;
    }
    output.add(_chunkHeader(chunk.id, data.length));
    output.add(data);
  }
  return output.toBytes();
}

class _RollEvent {
  _RollEvent(this.tick, this.track, this.order, this.status, this.body);
  final int tick, track, order, status;
  final Uint8List body;
}

/// Relative track level (0–100%). Scale note-on strength per track rather than
/// channel volume so even voices sharing a MIDI channel remain independent.
/// Keep their written dynamics and event times; 0 removes the track's notes,
/// including note-offs, so it cannot cut off another voice's shared-channel note.
Uint8List volumeMidiParts(Uint8List bytes, Map<int, int> trackVolumes) {
  for (final volume in trackVolumes.values) {
    RangeError.checkValueInInterval(volume, 0, 100, 'track volume');
  }
  if (trackVolumes.values.every((v) => v == 100)) return bytes;
  final silent =
      trackVolumes.entries.where((e) => e.value == 0).map((e) => e.key).toSet();
  final source = silent.isEmpty ? bytes : mixMidiParts(bytes, silent);
  final out = BytesBuilder(copy: false);
  var index = 0;
  for (final chunk in _readChunks(source)) {
    var data = chunk.data;
    if (chunk.id == 'MTrk') {
      final volume = trackVolumes[index] ?? 100;
      if (volume > 0 && volume < 100) {
        final track = BytesBuilder(copy: false);
        for (final e in _trackEvents(data)) {
          track.add(e.delta);
          track.addByte(e.status);
          if (e.status & 0xf0 == 0x90 && e.body[1] > 0) {
            track.add(
                [e.body[0], (e.body[1] * volume / 100).round().clamp(1, 127)]);
          } else {
            track.add(e.body);
          }
        }
        data = track.toBytes();
      }
      index++;
    }
    out.add(_chunkHeader(chunk.id, data.length));
    out.add(data);
  }
  return out.toBytes();
}
