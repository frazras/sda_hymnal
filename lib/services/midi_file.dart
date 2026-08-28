import 'dart:typed_data';

/// Splits complete Standard MIDI Files without decoding/re-writing events.
/// Returned chunks include their MTrk headers and are views of [bytes].
List<Uint8List> midiTrackChunks(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  if (bytes.length < 14 || data.getUint32(0) != 0x4d546864) {
    throw const FormatException('Missing MIDI header');
  }
  final headerLength = data.getUint32(4);
  final count = data.getUint16(10);
  if (headerLength < 6 || data.getUint16(8) > 2 || count == 0) {
    throw const FormatException('Invalid MIDI header');
  }
  var offset = 8 + headerLength;
  final tracks = <Uint8List>[];
  for (var index = 0; index < count; index++) {
    if (offset + 8 > bytes.length || data.getUint32(offset) != 0x4d54726b) {
      throw const FormatException('Missing MIDI track');
    }
    final end = offset + 8 + data.getUint32(offset + 4);
    if (end > bytes.length) {
      throw const FormatException('Truncated MIDI track');
    }
    tracks.add(Uint8List.sublistView(bytes, offset, end));
    offset = end;
  }
  if (offset != bytes.length) {
    throw const FormatException('Unexpected data after MIDI tracks');
  }
  return tracks;
}

/// Solo export of SDA's generated reggae piano, NOT the Caribbean layout.
/// Find its channel-1/program-0 setup instead of assuming a track index:
/// hymns with a descant insert another lead track ahead of the piano.
/// Conductor and piano bytes (including volume, note-offs and gates) survive
/// unchanged. This does not normalize, boost, re-voice, or repair the MIDI.
Uint8List reggaePianoOnlyMidi(Uint8List bytes) {
  final tracks = midiTrackChunks(bytes);
  final data = ByteData.sublistView(bytes);
  if (data.getUint16(8) != 1) {
    throw const FormatException('Expected a generated format-1 arrangement');
  }
  final piano = tracks.skip(1).where((track) =>
      track.length >= 11 &&
      track[8] == 0 && // tick-zero program change emitted by arrangeStyle
      track[9] == 0xc1 &&
      track[10] == 0).toList();
  if (piano.length != 1) {
    throw const FormatException('Expected one SDA reggae piano track');
  }
  final header = Uint8List.fromList(bytes.sublist(0, 8 + data.getUint32(4)));
  ByteData.sublistView(header).setUint16(10, 2);
  return (BytesBuilder(copy: false)
        ..add(header)
        ..add(tracks.first)
        ..add(piano.single))
      .toBytes();
}
