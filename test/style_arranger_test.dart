import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/style_arranger.dart';

/// One note-on (velocity > 0) as scanned straight from the SMF bytes.
class _NoteOn {
  _NoteOn(this.tick, this.channel, this.pitch, this.seq);

  final int tick;
  final int channel;
  final int pitch;
  final int seq;
}

/// Minimal SMF scan: every note-on with its absolute tick and channel, plus
/// the last note-off tick in the file (0x80, or 0x90 with velocity 0).
({List<_NoteOn> ons, int lastOffTick}) _scan(Uint8List bytes) {
  final ons = <_NoteOn>[];
  var lastOff = 0;
  var seq = 0;
  var i = 8 + ((bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7]);
  while (i < bytes.length) {
    final id = String.fromCharCodes(bytes, i, i + 4);
    final len = (bytes[i + 4] << 24) |
        (bytes[i + 5] << 16) |
        (bytes[i + 6] << 8) |
        bytes[i + 7];
    final end = i + 8 + len;
    i += 8;
    if (id == 'MTrk') {
      var tick = 0;
      var running = 0;
      while (i < end) {
        var delta = 0;
        while (true) {
          final b = bytes[i++];
          delta = (delta << 7) | (b & 0x7F);
          if (b & 0x80 == 0) break;
        }
        tick += delta;
        final status = bytes[i] & 0x80 != 0 ? bytes[i++] : running;
        if (status == 0xFF) {
          i++; // meta type
          var len = 0;
          while (true) {
            final b = bytes[i++];
            len = (len << 7) | (b & 0x7F);
            if (b & 0x80 == 0) break;
          }
          i += len;
          running = 0;
        } else if (status == 0xF0 || status == 0xF7) {
          var len = 0;
          while (true) {
            final b = bytes[i++];
            len = (len << 7) | (b & 0x7F);
            if (b & 0x80 == 0) break;
          }
          i += len;
          running = 0;
        } else {
          running = status;
          final hi = status & 0xF0;
          if (hi == 0x90 && bytes[i + 1] > 0) {
            ons.add(_NoteOn(tick, status & 0x0F, bytes[i], seq++));
          } else if (hi == 0x80 || hi == 0x90) {
            if (tick > lastOff) lastOff = tick;
          }
          i += (hi == 0xC0 || hi == 0xD0) ? 1 : 2;
        }
      }
    }
    i = end;
  }
  ons.sort((a, b) => a.tick != b.tick ? a.tick - b.tick : a.seq - b.seq);
  return (ons: ons, lastOffTick: lastOff);
}

/// SMF division (ticks per quarter note) straight from the header.
int _division(Uint8List bytes) => (bytes[12] << 8) | bytes[13];

/// The input channel the arranger treats as the melody: highest average
/// pitch, ties broken by note count, then by lowest channel number.
int _melodyChannel(Uint8List bytes) {
  final stats = channelStats(bytes);
  var best = -1;
  for (final ch in stats.keys.toList()..sort()) {
    if (best < 0 ||
        stats[ch]!.avgPitch > stats[best]!.avgPitch ||
        (stats[ch]!.avgPitch == stats[best]!.avgPitch &&
            stats[ch]!.notes > stats[best]!.notes)) {
      best = ch;
    }
  }
  return best;
}

/// The chord root governing each of the first [count] measure starts that
/// carry harmony, sampled at the same media-time instants for both tracks.
List<int> _barStartRoots(ChordTrack track, List<int> measureStartMs, int count) {
  final roots = <int>[];
  for (final ms in measureStartMs) {
    if (roots.length >= count) break;
    final i = track.indexAt(ms);
    if (i >= 0) roots.add(track.chords[i].rootPc);
  }
  return roots;
}

/// `id` + big-endian length + data.
List<int> _chunk(String id, List<int> data) => [
      ...id.codeUnits,
      (data.length >> 24) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 8) & 0xFF,
      data.length & 0xFF,
      ...data,
    ];

/// Format-1 SMF, division 96, from raw track bodies.
Uint8List _smf(List<List<int>> tracks) => Uint8List.fromList([
      ..._chunk('MThd',
          [0x00, 0x01, tracks.length >> 8, tracks.length & 0xFF, 0x00, 0x60]),
      for (final t in tracks) ..._chunk('MTrk', t),
    ]);

/// The property suite every style must satisfy, mirroring the gospel one:
/// valid SMF with the hymn's meter and key, the expected channel layout,
/// melody preserved verbatim on channel 0, per-part register bands, the
/// style's signature percussion voices present, same length, the hymn's own
/// harmony re-detected at bar starts, and byte-identical determinism.
void _styleTests(
  String path,
  ArrangeStyle style, {
  required Set<int> pitchedChannels,
  required Set<int> percussionKeys,
  required Map<int, (int, int)> registerBands,
}) {
  final input = Uint8List.fromList(File(path).readAsBytesSync());
  final output = arrangeStyle(input, style);
  final inScan = _scan(input);
  final outScan = _scan(output);
  final outStats = channelStats(output);

  test('output is a valid SMF with detectable harmony', () {
    final inTrack = detectChords(input)!;
    final outTrack = detectChords(output);
    expect(outTrack, isNotNull);
    expect(outTrack!.beatsPerBar, inTrack.beatsPerBar);
  });

  test('preserves the key signature', () {
    final inKey = readKeySignature(input)!;
    final outKey = readKeySignature(output)!;
    expect(outKey.sf, inKey.sf);
    expect(outKey.minor, inKey.minor);
  });

  test('plays exactly channels $pitchedChannels plus percussion on 9', () {
    expect(outStats.keys.toSet(), pitchedChannels);
    expect(outScan.ons.where((on) => on.channel == 9), isNotEmpty);
  });

  test('copies the melody onto channel 0', () {
    final melodyCh = _melodyChannel(input);
    expect(outStats[0]!.notes, channelStats(input)[melodyCh]!.notes);
    final inMelody = [
      for (final on in inScan.ons)
        if (on.channel == melodyCh) on.pitch,
    ];
    final outMelody = [
      for (final on in outScan.ons)
        if (on.channel == 0) on.pitch,
    ];
    expect(outMelody.first, inMelody.first);
    expect(outMelody.last, inMelody.last);
  });

  test('keeps every backing part in its register band', () {
    expect(outStats[2]!.avgPitch, lessThan(50)); // bass
    for (final MapEntry(key: ch, value: (lo, hi)) in registerBands.entries) {
      for (final on in outScan.ons.where((on) => on.channel == ch)) {
        expect(on.pitch, inInclusiveRange(lo, hi),
            reason: 'channel $ch note ${on.pitch} out of band');
      }
    }
  });

  test('sounds the style\'s signature percussion voices', () {
    final keys = {
      for (final on in outScan.ons)
        if (on.channel == 9) on.pitch,
    };
    for (final key in percussionKeys) {
      expect(keys, contains(key));
    }
  });

  test('runs the same length as the hymn (last note-off within 5%)', () {
    expect((outScan.lastOffTick - inScan.lastOffTick).abs(),
        lessThanOrEqualTo(inScan.lastOffTick * 0.05));
  });

  test('re-detects the hymn\'s own roots on the first 8 harmonized bars', () {
    // Colors added by the arrangement may split or relabel chord spans
    // (qualities differ), so fidelity is judged where the groove states the
    // harmony: the chord governing each measure start, at the same
    // media-time instants in both files.
    final inTrack = detectChords(input)!;
    final outTrack = detectChords(output)!;
    final inRoots = _barStartRoots(inTrack, inTrack.measureStartMs, 8);
    final outRoots = _barStartRoots(outTrack, inTrack.measureStartMs, 8);
    expect(inRoots, hasLength(8));
    expect(outRoots, inRoots);
  });

  test('is deterministic: two runs are byte-identical', () {
    expect(arrangeStyle(input, style), output);
  });
}

/// Reggae-only structural assertions: the one drop. Beat 1 of every bar is
/// kick-free and sparser than beat 3, where kick and sidestick land together.
void _oneDropTests(String path) {
  final input = Uint8List.fromList(File(path).readAsBytesSync());
  final output = arrangeStyle(input, ArrangeStyle.reggae);
  final outScan = _scan(output);
  final d = _division(output);
  final n = detectChords(input)!.beatsPerBar;
  final barTicks = n * d;
  final drumOns = [
    for (final on in outScan.ons)
      if (on.channel == 9) on,
  ];

  test('one drop: every kick lands on beat 3, never beat 1', () {
    final kicks = drumOns.where((on) => on.pitch == 36).toList();
    expect(kicks, isNotEmpty);
    for (final on in kicks) {
      expect(on.tick % barTicks, 2 * d);
    }
  });

  test('one drop: kick and sidestick strike beat 3 together', () {
    final kickTicks = {
      for (final on in drumOns)
        if (on.pitch == 36) on.tick,
    };
    final stickTicks = {
      for (final on in drumOns)
        if (on.pitch == 37) on.tick,
    };
    expect(stickTicks.containsAll(kickTicks), isTrue);
  });

  test('one drop: beat 1 is structurally lighter than beat 3', () {
    final beat1 = drumOns.where((on) => on.tick % barTicks == 0).length;
    final beat3 = drumOns.where((on) => on.tick % barTicks == 2 * d).length;
    expect(beat1, lessThan(beat3));
  });
}

/// Calypso-only structural assertions: the strum rests on every downbeat and
/// the claves hold the 3+3+2 tresillo anchor.
void _calypsoStructureTests(String path) {
  final input = Uint8List.fromList(File(path).readAsBytesSync());
  final output = arrangeStyle(input, ArrangeStyle.calypso);
  final outScan = _scan(output);
  final d = _division(output);
  final n = detectChords(input)!.beatsPerBar;
  final barTicks = n * d;

  test('the strum rests on every downbeat (all hits off the beat)', () {
    final strumOns = outScan.ons.where((on) => on.channel == 1).toList();
    expect(strumOns, isNotEmpty);
    for (final on in strumOns) {
      expect(on.tick % d, isNot(0));
    }
  });

  test('claves hold the tresillo anchor', () {
    final anchors = n == 3
        ? {0, 3 * d ~/ 2} // 1, 2& — the 3+3 hemiola of the Caribbean waltz
        : {0, 3 * d ~/ 2, 3 * d}; // 1, 2&, 4
    final claveTicks = [
      for (final on in outScan.ons)
        if (on.channel == 9 && on.pitch == 75) on.tick % barTicks,
    ];
    expect(claveTicks, isNotEmpty);
    for (final t in claveTicks) {
      expect(anchors, contains(t));
    }
  });
}

void _rejectionTests(ArrangeStyle style) {
  test('throws FormatException when no harmony is detectable', () {
    // A valid SMF with a conductor track but no notes: parseable, yet
    // detectChords returns null, so the caller must fall back.
    final noNotes = _smf([
      [
        0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20, // tempo 120bpm
        0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08, // 4/4
        0x00, 0xFF, 0x2F, 0x00, // end of track
      ],
    ]);
    expect(() => arrangeStyle(noNotes, style), throwsFormatException);
  });

  test('throws FormatException for non-MIDI bytes', () {
    expect(() => arrangeStyle(Uint8List.fromList([1, 2, 3]), style),
        throwsFormatException);
  });
}

void main() {
  const reggaeBands = {
    1: (55, 80), // skank guitar: top-string voicings around middle C
    3: (36, 64), // organ bubble: LH C2–B2, RH triads C3–C4
  };
  const calypsoBands = {
    1: (55, 80), // pan strum double stops, researched G3–E5 band
  };
  const reggaeKeys = {36, 37, 42, 44, 46, 54}; // kick, rim, hats, tambourine
  const calypsoKeys = {36, 37, 42, 56, 70, 75}; // kit + cowbell/maracas/claves

  group('arrangeStyle(reggae) on assets/midi/016.mid (4/4)', () {
    _styleTests('assets/midi/016.mid', ArrangeStyle.reggae,
        pitchedChannels: {0, 1, 2, 3},
        percussionKeys: reggaeKeys,
        registerBands: reggaeBands);
    _oneDropTests('assets/midi/016.mid');
  });

  group('arrangeStyle(reggae) on assets/midi/001.mid (3/4)', () {
    _styleTests('assets/midi/001.mid', ArrangeStyle.reggae,
        pitchedChannels: {0, 1, 2, 3},
        percussionKeys: reggaeKeys,
        registerBands: reggaeBands);
    _oneDropTests('assets/midi/001.mid');
  });

  group('arrangeStyle(calypso) on assets/midi/016.mid (4/4)', () {
    _styleTests('assets/midi/016.mid', ArrangeStyle.calypso,
        pitchedChannels: {0, 1, 2},
        percussionKeys: calypsoKeys,
        registerBands: calypsoBands);
    _calypsoStructureTests('assets/midi/016.mid');
  });

  group('arrangeStyle(calypso) on assets/midi/001.mid (3/4)', () {
    // The Caribbean waltz drops the cowbell loop for triangle color.
    _styleTests('assets/midi/001.mid', ArrangeStyle.calypso,
        pitchedChannels: {0, 1, 2},
        percussionKeys: {36, 37, 42, 70, 75, 81},
        registerBands: calypsoBands);
    _calypsoStructureTests('assets/midi/001.mid');
  });

  group('arrangeStyle(reggae) rejects unusable input', () {
    _rejectionTests(ArrangeStyle.reggae);
  });

  group('arrangeStyle(calypso) rejects unusable input', () {
    _rejectionTests(ArrangeStyle.calypso);
  });
}
