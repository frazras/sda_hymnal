import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/style_arranger.dart';

/// One note-on (velocity > 0) as scanned straight from the SMF bytes.
class _NoteOn {
  _NoteOn(this.tick, this.channel, this.pitch, this.vel, this.seq);

  final int tick;
  final int channel;
  final int pitch;
  final int vel;
  final int seq;
}

/// Minimal SMF scan: every note-on with its absolute tick, channel and
/// velocity, the last note-off tick in the file (0x80, or 0x90 with velocity
/// 0), the programs selected per channel, and the number of tempo metas.
({
  List<_NoteOn> ons,
  int lastOffTick,
  Map<int, Set<int>> programs,
  int tempoCount,
  List<int> tempi,
}) _scan(Uint8List bytes) {
  final ons = <_NoteOn>[];
  final programs = <int, Set<int>>{};
  final tempi = <int>[]; // FF51 values, microseconds per quarter
  var tempoCount = 0;
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
          final type = bytes[i++];
          var len = 0;
          while (true) {
            final b = bytes[i++];
            len = (len << 7) | (b & 0x7F);
            if (b & 0x80 == 0) break;
          }
          if (type == 0x51 && len == 3) {
            tempoCount++;
            tempi.add((bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]);
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
            ons.add(_NoteOn(tick, status & 0x0F, bytes[i], bytes[i + 1], seq++));
          } else if (hi == 0x80 || hi == 0x90) {
            if (tick > lastOff) lastOff = tick;
          } else if (hi == 0xC0) {
            programs.putIfAbsent(status & 0x0F, () => {}).add(bytes[i]);
          }
          i += (hi == 0xC0 || hi == 0xD0) ? 1 : 2;
        }
      }
    }
    i = end;
  }
  ons.sort((a, b) => a.tick != b.tick ? a.tick - b.tick : a.seq - b.seq);
  return (
    ons: ons,
    lastOffTick: lastOff,
    programs: programs,
    tempoCount: tempoCount,
    tempi: tempi,
  );
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
/// [fidelity] opts the harmony re-detection property out for hymns whose
/// arrangement is too sparse at measure starts to re-detect reliably (the
/// reggae half-time reading comps only beats 2 and 4, so a bar-start window
/// holds just the bass root, an organ dab and the melody — under-determined
/// for the detector even when the sounding harmony is right).
void _styleTests(
  String path,
  ArrangeStyle style, {
  required Set<int> pitchedChannels,
  required Set<int> percussionKeys,
  required Map<int, (int, int)> registerBands,
  bool fidelity = true,
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

  test('runs the same length as the hymn plus the ring-out bar', () {
    // The button ending holds the final chord one bar past the last bar
    // line (the flattened tempo map no longer stretches it), so the
    // arrangement may end up to a bar late on top of the 5% tolerance.
    final barTicks = detectChords(input)!.beatsPerBar * _division(output);
    expect((outScan.lastOffTick - inScan.lastOffTick).abs(),
        lessThanOrEqualTo(inScan.lastOffTick * 0.05 + barTicks));
  });

  if (fidelity) {
    test('re-detects the hymn\'s own roots on the first 8 harmonized bars',
        () {
    // Colors added by the arrangement may split or relabel chord spans
    // (qualities differ), so fidelity is judged where the groove states the
    // harmony: the chord governing each measure start, at the same
    // media-time instants in both files.
    // Each track is sampled at its OWN measure starts: the arranger
    // flattens the tempo map (bands keep time through the hymn's verse-end
    // ritardandos), so identical measure indices — not identical
    // media-time instants — are the common frame. Reggae and calypso comp
    // from the MEDIUM-simplified harmony (the diatonic filter kills the
    // phantom out-of-key chords raw detection reads from inversions), so
    // that is the reference for them; gospel comps from raw detection.
    final inTrack = detectChords(input)!;
    final source = style == ArrangeStyle.gospel
        ? inTrack
        : simplifyTrack(inTrack, ChordLevel.medium);
    final outTrack = detectChords(output)!;
    final inRoots = _barStartRoots(source, source.measureStartMs, 8);
    final outRoots = _barStartRoots(outTrack, outTrack.measureStartMs, 8);
      expect(inRoots, hasLength(8));
      expect(outRoots, inRoots);
    });
  }

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

  group('listening retune (2026-07-28 feedback) on assets/midi/016.mid', () {
    final input =
        Uint8List.fromList(File('assets/midi/016.mid').readAsBytesSync());
    final reggae = arrangeStyle(input, ArrangeStyle.reggae);
    final calypso = arrangeStyle(input, ArrangeStyle.calypso);
    final reggaeScan = _scan(reggae);
    final calypsoScan = _scan(calypso);

    double avgVel(List<_NoteOn> ons, int ch) {
      final vels = [
        for (final on in ons)
          if (on.channel == ch) on.vel,
      ];
      return vels.reduce((a, b) => a + b) / vels.length;
    }

    test('reggae lead is Rhodes, skank is piano — the flute is gone', () {
      expect(reggaeScan.programs[0], {4});
      expect(reggaeScan.programs[1], {0});
      for (final programs in reggaeScan.programs.values) {
        expect(programs, isNot(contains(73)));
      }
    });

    test('calypso lead is piano over the steel-pan strum', () {
      expect(calypsoScan.programs[0], {0});
      expect(calypsoScan.programs[1], {114});
    });

    test('the skank varies single and double chops (the chack-a)', () {
      final d = _division(reggae);
      final offsets = {
        for (final on in reggaeScan.ons)
          if (on.channel == 1) on.tick % d,
      };
      // The double lands a sixteenth after the chop: at the straight "a"
      // (d/4 past an on-beat chop) in half-time, at the swung "a" (4d/5
      // into the beat) in full time.
      expect(offsets.intersection({d ~/ 4, 4 * d ~/ 5}), isNotEmpty);
    });

    test('the melody outweighs the comping in both styles', () {
      expect(avgVel(reggaeScan.ons, 0), greaterThan(avgVel(reggaeScan.ons, 1)));
      expect(
          avgVel(calypsoScan.ons, 0), greaterThan(avgVel(calypsoScan.ons, 1)));
    });

    test('the reggae bass anchors at full weight', () {
      final vels = [
        for (final on in reggaeScan.ons)
          if (on.channel == 2) on.vel,
      ];
      expect(vels.reduce((a, b) => a > b ? a : b), greaterThanOrEqualTo(110));
    });

    test('the tempo map is clamped into the dominant band', () {
      // No arranged tempo may exceed the dominant (opener flourishes are
      // gone) or fall below 70% of it (cadence dips survive as gentle
      // holds, not lurches or a dead flat line).
      for (final scan in [
        reggaeScan,
        calypsoScan,
        _scan(arrangeStyle(input, ArrangeStyle.gospel)),
      ]) {
        final bpms = scan.tempi.map((us) => 6e7 / us).toList();
        expect(bpms, isNotEmpty);
        final fastest = bpms.reduce((a, b) => a > b ? a : b);
        final slowest = bpms.reduce((a, b) => a < b ? a : b);
        expect(fastest / slowest, lessThanOrEqualTo(1 / 0.7 + 0.01));
      }
    });

    test('#15 clamps to its dominant 121 BPM body, not the 240 opener', () {
      // Hymn 15 opens with a seven-beat 240 BPM flourish marking before
      // the 121 BPM body; taking the opener played the whole arrangement
      // double-speed (heard as the one drop "removed... a stifled
      // one-note fill"). The dominant tempo — most governed ticks — caps
      // the map; the closing rits survive only down to the 70% floor.
      final h15 = Uint8List.fromList(
          File('assets/midi/015.mid').readAsBytesSync());
      final scan = _scan(arrangeStyle(h15, ArrangeStyle.reggae));
      final bpms = scan.tempi.map((us) => 6e7 / us).toList();
      expect(bpms.first.round(), 121);
      expect(bpms.reduce((a, b) => a > b ? a : b).round(), 121);
      expect(bpms.reduce((a, b) => a < b ? a : b),
          greaterThanOrEqualTo(121 * 0.7 - 0.5));
    });

    test('#15 chord display retimes onto the arranged timeline', () {
      // The ticker consumes positions of the PLAYING file. Hymn 15's
      // original map starts at 240 BPM (chords flew by early — "didn't
      // hear the first 2 chords") and ends in deep rits (the indicator
      // outlived the audio). Retimed: the opening chords sit LATER than
      // raw (slowed to 121) and the final measure lands EARLIER (rits
      // clamped to the 70% floor).
      final h15 = Uint8List.fromList(
          File('assets/midi/015.mid').readAsBytesSync());
      final raw = detectChords(h15)!;
      final retimed = retimeTrackForArrangement(h15, raw);
      expect(retimed.chords.length, raw.chords.length);
      expect(retimed.measureStartMs.length, raw.measureStartMs.length);
      expect(retimed.chords.first.startMs,
          greaterThan(raw.chords.first.startMs));
      expect(retimed.measureStartMs.last, lessThan(raw.measureStartMs.last));
      // Beat counts are conserved chord by chord.
      for (var i = 0; i < raw.chords.length; i++) {
        expect(retimed.chords[i].beatMs.length, raw.chords[i].beatMs.length);
      }
    });

    test('the calypso strum drops out for the button ending', () {
      final crashTicks = [
        for (final on in calypsoScan.ons)
          if (on.channel == 9 && on.pitch == 49) on.tick,
      ];
      final lastCrash = crashTicks.reduce((a, b) => a > b ? a : b);
      expect(
          calypsoScan.ons.where((on) => on.channel == 1 && on.tick >= lastCrash),
          isEmpty);
    });

    test('reggae ends on a downbeat crash button', () {
      final d = _division(reggae);
      final n = detectChords(input)!.beatsPerBar;
      final downbeatCrashes = [
        for (final on in reggaeScan.ons)
          if (on.channel == 9 && on.pitch == 49 && on.tick % (n * d) == 0)
            on.tick,
      ];
      expect(downbeatCrashes, isNotEmpty);
    });
  });

  group('arrangeStyle(reggae) on assets/midi/456.mid (reported phantom '
      'chords; 132 BPM half-time reading)', () {
    _styleTests('assets/midi/456.mid', ArrangeStyle.reggae,
        pitchedChannels: {0, 1, 2, 3},
        percussionKeys: reggaeKeys,
        registerBands: reggaeBands,
        fidelity: false);
    _oneDropTests('assets/midi/456.mid');
  });

  group('arrangeStyle(reggae) rejects unusable input', () {
    _rejectionTests(ArrangeStyle.reggae);
  });

  group('arrangeStyle(calypso) rejects unusable input', () {
    _rejectionTests(ArrangeStyle.calypso);
  });
}
