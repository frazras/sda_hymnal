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
}) {
  if (forceProgram != null) {
    RangeError.checkValueInInterval(forceProgram, 0, 127, 'forceProgram');
  }
  channelPrograms?.forEach((ch, program) {
    RangeError.checkValueInInterval(ch, 0, 15, 'channelPrograms key');
    RangeError.checkValueInInterval(program, 0, 127, 'channelPrograms value');
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
      data =
          _rewriteTrack(data, semitones, programFor, insertions[t] ?? const []);
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
