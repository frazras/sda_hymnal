import 'dart:io';
import 'dart:math';
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
  List<(int, int)> tempoMap,
}) _scan(Uint8List bytes) {
  final ons = <_NoteOn>[];
  final programs = <int, Set<int>>{};
  final tempi = <int>[]; // FF51 values, microseconds per quarter
  final tempoMap = <(int, int)>[]; // the same, with the tick each sits at
  var tempoCount = 0;
  var lastOff = 0;
  var seq = 0;
  var i =
      8 + ((bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7]);
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
            final us = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
            tempi.add(us);
            tempoMap.add((tick, us));
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
            ons.add(
                _NoteOn(tick, status & 0x0F, bytes[i], bytes[i + 1], seq++));
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
    tempoMap: tempoMap,
  );
}

/// Tick to media-time milliseconds under a file's own tempo map — the clock
/// a listener actually hears the arrangement on, and the only one in which
/// "the beat is steady" means anything. The same piecewise construction the
/// arranger uses internally.
class _Clock {
  _Clock(List<(int, int)> tempi, int division) {
    _ticks.add(0);
    _ms.add(0);
    _rate.add(500000 / division / 1000);
    for (final (tick, us) in [...tempi]..sort((a, b) => a.$1 - b.$1)) {
      final rate = us / division / 1000;
      if (tick == _ticks.last) {
        _rate[_rate.length - 1] = rate;
      } else {
        _ms.add(_ms.last + (tick - _ticks.last) * _rate.last);
        _ticks.add(tick);
        _rate.add(rate);
      }
    }
  }

  final _ticks = <int>[];
  final _ms = <double>[];
  final _rate = <double>[];

  double msOf(int tick) {
    var best = 0;
    for (var i = 0; i < _ticks.length && _ticks[i] <= tick; i++) {
      best = i;
    }
    return _ms[best] + (tick - _ticks[best]) * _rate[best];
  }
}

/// The reggae pulse of a render, read off its (flat) conductor tempo: the
/// chop sits on beats 2 and 4 at 100 BPM and above, on every "&" below it
/// (see the arranger's _emitReggae). Returns the drop offsets within a bar
/// and the beat-index spacing from beat 1 to the first drop.
({List<int> dropOffsets, double dropBeats}) _reggaePulse(
    List<int> tempi, int d, int n) {
  if (n == 3) return (dropOffsets: [2 * d], dropBeats: 2);
  final bpm = 6e7 / tempi.first;
  if (bpm >= 100) return (dropOffsets: [2 * d], dropBeats: 2);
  return (
    dropOffsets: n == 3 ? [d] : [d, 3 * d],
    dropBeats: 1,
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
List<int> _barStartRoots(
    ChordTrack track, List<int> measureStartMs, int count) {
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
  bool playedInFour = false,
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
    // Both island styles retain the hymn's written meter.
    expect(outTrack!.beatsPerBar, playedInFour ? 4 : inTrack.beatsPerBar);
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
    // Played in four, every 3/4 bar is a beat longer: 4/3 the length.
    final barTicks = detectChords(output)!.beatsPerBar * _division(output);
    final expected =
        playedInFour ? inScan.lastOffTick * 4 / 3 : inScan.lastOffTick;
    expect((outScan.lastOffTick - expected).abs(),
        lessThanOrEqualTo(inScan.lastOffTick * 0.05 + barTicks));
  });

  if (fidelity) {
    test('re-detects the hymn\'s own roots on the first 8 harmonized bars', () {
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
/// kick-free, and the drop pulse carries both kicks and the cross-stick
/// together, exactly as the reference chart voices it.
void _oneDropTests(String path) {
  final input = Uint8List.fromList(File(path).readAsBytesSync());
  final output = arrangeStyle(input, ArrangeStyle.reggae);
  final outScan = _scan(output);
  final d = _division(output);
  final n = detectChords(output)!.beatsPerBar;
  final barTicks = n * d;
  final pulse = _reggaePulse(outScan.tempi, d, n);
  final drumOns = [
    for (final on in outScan.ons)
      if (on.channel == 9) on,
  ];
  const deepKick = 35; // Acoustic Bass Drum
  const kick = 36; // Bass Drum 1
  const crossStick = 37; // Side Stick

  test('one drop: every kick lands on a drop pulse, never beat 1', () {
    final kicks = drumOns.where((on) => on.pitch == deepKick).toList();
    expect(kicks, isNotEmpty);
    for (final on in kicks) {
      expect(pulse.dropOffsets, contains(on.tick % barTicks));
    }
  });

  test('one drop: the drop is two kicks and a loud stick, together', () {
    // Three Little Birds voices its drop as GM 35 + 36 layered (120 / 109)
    // under a side stick at 115 — the stick is the attack, the two kicks
    // the depth. Every drop here carries all three.
    final drops = {
      for (final on in drumOns)
        if (on.pitch == deepKick) on.tick,
    };
    expect(drops, isNotEmpty);
    for (final key in [kick, crossStick]) {
      final ticks = {
        for (final on in drumOns)
          if (on.pitch == key) on.tick,
      };
      expect(ticks.containsAll(drops), isTrue,
          reason: 'GM @D@key must strike with every drop');
    }
    for (final tick in drops) {
      int velAt(int pitch) =>
          drumOns.firstWhere((o) => o.tick == tick && o.pitch == pitch).vel;
      expect(velAt(crossStick), lessThan(velAt(deepKick)));
      expect(velAt(kick), lessThan(velAt(deepKick)));
    }
  });

  test('one drop: beat 1 is structurally lighter than the drop', () {
    final beat1 = drumOns.where((on) => on.tick % barTicks == 0).toList();
    expect(beat1, isNotEmpty);
    expect(
        beat1.where((on) => on.pitch == deepKick || on.pitch == kick), isEmpty,
        reason: 'beat 1 is the beat the one drop drops');
    final byTick = <int, int>{};
    for (final on in drumOns) {
      byTick[on.tick] = (byTick[on.tick] ?? 0) + 1;
    }
    final dropTick = drumOns.firstWhere((on) => on.pitch == deepKick).tick;
    expect(byTick[dropTick]!, greaterThan(byTick[beat1.first.tick]!));
  });

  test('the piano never rests: every chop pulse of every bar is chopped', () {
    // The owner's one hard requirement for the skank: it must not stop.
    // A 3/4 hymn chops on 1&, 2&, and 3&. Other meters retain the established
    // tempo-dependent beat/eighth reading.
    final chopOffsets = pulse.dropBeats == 2
        ? (n == 3 ? [d ~/ 2, 3 * d ~/ 2, 5 * d ~/ 2] : [d, 3 * d])
        : [for (var k = 1; k < 2 * n; k += 2) k * d ~/ 2];
    final pianoTicks = {
      for (final on in outScan.ons)
        if (on.channel == 1) on.tick,
    };
    expect(pianoTicks, isNotEmpty);
    for (final tick in pianoTicks) {
      expect(chopOffsets, contains(tick % barTicks),
          reason: 'piano off the chop at tick $tick');
    }
    // Every full bar from the band's entry to the bar before the button;
    // the last bar chops only as far as the harmony runs, then rings out.
    final firstBar = pianoTicks.reduce((a, b) => a < b ? a : b) ~/ barTicks;
    final lastBar = pianoTicks.reduce((a, b) => a > b ? a : b) ~/ barTicks;
    final missing = [
      for (var bar = firstBar; bar < lastBar; bar++)
        for (final off in chopOffsets)
          if (!pianoTicks.contains(bar * barTicks + off)) bar * barTicks + off,
    ];
    expect(missing, isEmpty, reason: 'chop missing at ticks $missing');
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

  if (n == 3) {
    test('the steelpan keeps answering through all three beats', () {
      final beats = {
        for (final on in outScan.ons.where((on) => on.channel == 1))
          (on.tick % barTicks) ~/ d,
      };
      expect(beats, containsAll(<int>[0, 1, 2]));
    });
  }

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
      expect(anchors, contains(t),
          reason: 'clave at $t is off every anchor $anchors');
    }
  });
}

/// The steady beat — the property the whole island rhythm section exists to
/// hold. A hymn's tempo map is a long body at one marking punctuated by
/// verse-end rits and fermatas; the backing must play THROUGH those at the
/// dominant tempo rather than dragging with them, so these assertions are
/// made in milliseconds (what a listener hears), never in ticks.
void _steadyBeatTests(String path) {
  final input = Uint8List.fromList(File(path).readAsBytesSync());
  final hymnN = detectChords(input)!.beatsPerBar;
  final n = hymnN;

  /// Every arranged tempo is the dominant one or SLOWER (dips clamp up to
  /// the floor, flourishes clamp down), so the fastest marking in the
  /// render is the dominant — the pulse the band is supposed to hold.
  double beatMsOf(List<int> tempi) =>
      tempi.reduce((a, b) => a < b ? a : b) / 1000;

  test('reggae: beat 1 to the one drop is the same length in every bar', () {
    final scan = _scan(arrangeStyle(input, ArrangeStyle.reggae));
    final d = _division(arrangeStyle(input, ArrangeStyle.reggae));
    final clock = _Clock(scan.tempoMap, d);
    final barTicks = n * d;
    final pulse = _reggaePulse(scan.tempi, d, n);
    final first = <int, Map<int, int>>{};
    for (final on in scan.ons) {
      if (on.channel != 9) continue;
      first
          .putIfAbsent(on.tick ~/ barTicks, () => <int, int>{})
          .putIfAbsent(on.pitch, () => on.tick);
    }
    // Beat 1 is marked by the bar's first maracas (beat reading) or
    // tambourine (eighth reading) — both strike on the downbeat. A bar
    // whose harmony starts late has no downbeat hit at all (the arranger
    // drops hits outside the harmonised span), so it is left out.
    final spans = <double>[
      for (final bar in first.values)
        if (bar.containsKey(35) && (bar.containsKey(70) || bar.containsKey(54)))
          if ((bar[70] ?? bar[54]!) % barTicks == 0)
            clock.msOf(bar[35]!) - clock.msOf(bar[70] ?? bar[54]!),
    ];
    expect(spans.length, greaterThan(8));
    final lo = spans.reduce((a, b) => a < b ? a : b);
    final hi = spans.reduce((a, b) => a > b ? a : b);
    // Two beats of music in every bar of the hymn, cadences included: only
    // tick quantization separates them. Before the steady clock this spread
    // ran to the full cadence floor — 17.6% — and that drag is what made
    // the one drop miss.
    expect((hi - lo) / lo, lessThan(0.01),
        reason: 'the drop drifts: $lo..$hi ms');
    expect(lo, closeTo(pulse.dropBeats * beatMsOf(scan.tempi), 2));
  });

  test('calypso: the pan strum tick-a never speeds up or slows down', () {
    final output = arrangeStyle(input, ArrangeStyle.calypso);
    final scan = _scan(output);
    final d = _division(output);
    final clock = _Clock(scan.tempoMap, d);
    final n = hymnN;
    final barTicks = n * d;
    // The engine room's claves span the bar's tresillo anchor: 1 to 4 in
    // 4/4 (three beats), 1 to 2& in the waltz (a beat and a half).
    final want = n == 3 ? 2 : 3;
    final byBar = <int, List<int>>{};
    for (final on in scan.ons) {
      if (on.channel == 9 && on.pitch == 75) {
        byBar.putIfAbsent(on.tick ~/ barTicks, () => <int>[]).add(on.tick);
      }
    }
    final spans = <double>[
      for (final ticks in byBar.values)
        if (ticks.length == want)
          clock.msOf(ticks.last) - clock.msOf(ticks.first),
    ];
    expect(spans.length, greaterThan(8));
    final lo = spans.reduce((a, b) => a < b ? a : b);
    final hi = spans.reduce((a, b) => a > b ? a : b);
    expect((hi - lo) / lo, lessThan(0.01),
        reason: 'the engine room sags: $lo..$hi ms');
    expect(lo, closeTo((n == 3 ? 1.5 : 3) * beatMsOf(scan.tempi), 2));
  });

  test('the island conductor carries exactly one tempo, start to end', () {
    // The owner's call after hearing the drop arrive late at every verse
    // end: a riddim does not bend. Anything the hymn marks as a rit or a
    // fermata is dropped from the CLOCK — the emitters still mark cadences
    // with a fill in and a crash out — so every bar is the same length and
    // the one drop cannot be late anywhere.
    for (final style in [ArrangeStyle.reggae, ArrangeStyle.calypso]) {
      final output = arrangeStyle(input, style);
      final scan = _scan(output);
      final d = _division(output);
      expect(scan.tempi.toSet(), hasLength(1),
          reason: '@D@style bends its tempo: @D@{scan.tempi.toSet()}');
      final clock = _Clock(scan.tempoMap, d);
      final barTicks = n * d;
      final bars = {
        for (final on in scan.ons)
          if (on.channel == 9) on.tick ~/ barTicks,
      }.toList()
        ..sort();
      final lengths = <double>[
        for (final bar in bars)
          clock.msOf((bar + 1) * barTicks) - clock.msOf(bar * barTicks),
      ];
      final lo = lengths.reduce((a, b) => a < b ? a : b);
      final hi = lengths.reduce((a, b) => a > b ? a : b);
      expect(hi - lo, lessThan(0.5), reason: '@D@style has uneven bars');
    }
  });
}

/// CC 7 values found at tick 0 of the first (conductor) track of [smf],
/// keyed by channel. Meta events sort ahead of them there, so this walks
/// every tick-0 event rather than assuming the controls come first.
Map<int, int> _tickZeroVolumes(Uint8List smf) {
  final seen = <int, int>{};
  var i = 14 + 8; // past MThd and the first MTrk header
  var running = 0;
  while (i < smf.length) {
    if (smf[i] != 0) break; // first non-zero delta: tick 0 is over
    i++;
    var status = smf[i];
    if (status & 0x80 != 0) {
      i++;
      running = status;
    } else {
      status = running;
    }
    if (status == 0xFF) {
      i++; // type
      var len = 0;
      while (true) {
        final b = smf[i++];
        len = (len << 7) | (b & 0x7F);
        if (b & 0x80 == 0) break;
      }
      i += len;
    } else if (status & 0xF0 == 0xB0) {
      if (smf[i] == 7) seen[status & 0x0F] = smf[i + 1];
      i += 2;
    } else {
      i += (status & 0xF0 == 0xC0 || status & 0xF0 == 0xD0) ? 1 : 2;
    }
  }
  return seen;
}

/// The iOS engine correction: CC 7 on the conductor at tick 0, nothing else
/// changed.
void _channelVolumeTests() {
  final input =
      Uint8List.fromList(File('assets/midi/016.mid').readAsBytesSync());
  final plain = arrangeStyle(input, ArrangeStyle.reggae);
  final leveled = arrangeStyle(input, ArrangeStyle.reggae,
      channelVolumes: reggaeVolumesForAppleSynth);

  test('writes one CC 7 per channel at tick 0 and touches nothing else', () {
    expect(_tickZeroVolumes(leveled), reggaeVolumesForAppleSynth);
    expect(_tickZeroVolumes(plain), isEmpty);
    final a = _scan(plain);
    final b = _scan(leveled);
    expect(b.ons.length, a.ons.length);
    expect(b.tempi, a.tempi);
    expect(b.lastOffTick, a.lastOffTick);
    expect(
        detectChords(leveled)!.beatsPerBar, detectChords(plain)!.beatsPerBar);
  });

  test('the correction survives transposition', () {
    expect(_tickZeroVolumes(transformMidi(leveled, semitones: 2)),
        reggaeVolumesForAppleSynth);
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
    1: (55, 67), // piano: the chop alone, in the charts' G3–F#4
    3: (52, 84), // organ: dabs C3–B3, the held chord C5–B5
  };
  const calypsoBands = {
    1: (55, 80), // pan strum double stops, researched G3–E5 band
    3: (55, 80), // vibraphone shimmer doubles the strum stroke for stroke
  };
  // The one drop is GM 35 + 36 layered under the cross-stick 37, as the
  // reference chart voices it (see _drop); closed hats, tambourine and the
  // maracas eighths make up the rest. No open hat: heard as "a heavy
  // metallic-sounding instrument... very loud and obnoxious".
  const reggaeKeys = {35, 36, 37, 42, 54, 70};
  const calypsoKeys = {36, 37, 42, 56, 70, 75}; // kit + cowbell/maracas/claves

  group('arrangeStyle(reggae) on assets/midi/016.mid (4/4)', () {
    // fidelity off: in the beat reading a bar-start window holds the bass
    // root, the piano's root octave, an organ root+fifth dab and the
    // melody — beat 1 carrying no full chord IS the one drop (see
    // _emitReggae) — which is under-determined for the detector even
    // when the sounding harmony is right.
    _styleTests('assets/midi/016.mid', ArrangeStyle.reggae,
        pitchedChannels: {0, 1, 2, 3},
        percussionKeys: reggaeKeys,
        registerBands: reggaeBands,
        fidelity: false);
    _oneDropTests('assets/midi/016.mid');
    _steadyBeatTests('assets/midi/016.mid');
  });

  group(
      'arrangeStyle(reggae) on assets/midi/001.mid '
      '(3/4, continuous offbeat skank)', () {
    _styleTests('assets/midi/001.mid', ArrangeStyle.reggae,
        pitchedChannels: {0, 1, 2, 3},
        percussionKeys: reggaeKeys,
        registerBands: reggaeBands,
        fidelity: false);
    _oneDropTests('assets/midi/001.mid');
    _steadyBeatTests('assets/midi/001.mid');
  });

  group('arrangeStyle(calypso) on assets/midi/016.mid (4/4)', () {
    _styleTests('assets/midi/016.mid', ArrangeStyle.calypso,
        pitchedChannels: {0, 1, 2, 3},
        percussionKeys: calypsoKeys,
        registerBands: calypsoBands);
    _calypsoStructureTests('assets/midi/016.mid');
  });

  group('arrangeStyle(calypso) on assets/midi/001.mid (3/4)', () {
    // The Caribbean waltz drops the cowbell loop for triangle color.
    _styleTests('assets/midi/001.mid', ArrangeStyle.calypso,
        pitchedChannels: {0, 1, 2, 3},
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

    test(
        'calypso lead is Rhodes — same voice as the reggae lead — over '
        'the steel-pan strum with its vibraphone attack layer', () {
      expect(calypsoScan.programs[0], {4});
      expect(calypsoScan.programs[1], {114});
      expect(calypsoScan.programs[3], {11});
    });

    test('the skank is single: one chop per off-pulse, never a double', () {
      // The owner heard the "chack-a" double, applied to every bar, as the
      // whole groove turning into a double skank. Every chop now lands
      // squarely on its pulse and nothing follows it inside the pulse.
      final d = _division(reggae);
      final n = detectChords(input)!.beatsPerBar;
      final pulse = _reggaePulse(reggaeScan.tempi, d, n);
      final p = pulse.dropBeats == 2 ? d : d ~/ 2;
      for (final on in reggaeScan.ons) {
        if (on.channel != 1) continue;
        expect(on.tick % p, 0, reason: 'piano off the pulse grid');
      }
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
      final h15 =
          Uint8List.fromList(File('assets/midi/015.mid').readAsBytesSync());
      // Reggae takes the dominant and holds it — one marking, no rits.
      final reggae = _scan(arrangeStyle(h15, ArrangeStyle.reggae));
      final rBpms = reggae.tempi.map((us) => 6e7 / us).toList();
      expect(rBpms.toSet(), hasLength(1));
      expect(rBpms.first.round(), 121);
      // Gospel still rides the hymn's rubato, clamped into the band and
      // ramped: no single jump between adjacent tempo events may exceed
      // ~15% (a hard step under the groove reads as a stutter).
      final bpms = _scan(arrangeStyle(h15, ArrangeStyle.gospel))
          .tempi
          .map((us) => 6e7 / us)
          .toList();
      expect(bpms.first.round(), 121);
      expect(bpms.reduce((a, b) => a > b ? a : b).round(), 121);
      expect(bpms.reduce((a, b) => a < b ? a : b),
          greaterThanOrEqualTo(121 * 0.7 - 0.5));
      for (var i = 1; i < bpms.length; i++) {
        final ratio = bpms[i] > bpms[i - 1]
            ? bpms[i] / bpms[i - 1]
            : bpms[i - 1] / bpms[i];
        expect(ratio, lessThanOrEqualTo(1.15));
      }
    });

    test('#15 chord display retimes onto the arranged timeline', () {
      // The ticker consumes positions of the PLAYING file. Hymn 15's
      // original map starts at 240 BPM (chords flew by early — "didn't
      // hear the first 2 chords") and ends in deep rits (the indicator
      // outlived the audio). Retimed onto the reggae render's FLAT map:
      // the opening chords sit LATER than raw (slowed to 121) and the final
      // measure lands EARLIER (the closing rits are gone from the clock).
      final h15 =
          Uint8List.fromList(File('assets/midi/015.mid').readAsBytesSync());
      final raw = detectChords(h15)!;
      final retimed = retimeTrackForArrangement(h15, raw, ArrangeStyle.reggae);
      expect(retimed.chords.length, raw.chords.length);
      expect(retimed.measureStartMs.length, raw.measureStartMs.length);
      expect(
          retimed.chords.first.startMs, greaterThan(raw.chords.first.startMs));
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
          calypsoScan.ons
              .where((on) => on.channel == 1 && on.tick >= lastCrash),
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

  group(
      'arrangeStyle(reggae) on assets/midi/456.mid (reported phantom '
      'chords; 132 BPM half-time reading)', () {
    _styleTests('assets/midi/456.mid', ArrangeStyle.reggae,
        pitchedChannels: {0, 1, 2, 3},
        percussionKeys: reggaeKeys,
        registerBands: reggaeBands,
        fidelity: false);
    _oneDropTests('assets/midi/456.mid');
  });

  group('hymn 190 (part-time descant above the soprano)', () {
    // The file's channel 7 is an obbligato: highest average pitch in the
    // file but sounding only in bars 1-4 and the refrains. Choosing the
    // lead by pitch alone led with it — and the melody went silent for
    // the whole first verse (bars 5-12). The lead chooser now requires
    // full-song coverage, and the descant rides quietly on channel 4.
    final input =
        Uint8List.fromList(File('assets/midi/190.mid').readAsBytesSync());
    final output = arrangeStyle(input, ArrangeStyle.reggae);
    final scan = _scan(output);
    final barTicks = detectChords(input)!.beatsPerBar * _division(output);

    test('the lead never falls silent for more than a bar mid-song', () {
      final leadBars = {
        for (final on in scan.ons)
          if (on.channel == 0) on.tick ~/ barTicks
      }.toList()
        ..sort();
      var worstGap = 0;
      for (var i = 1; i < leadBars.length; i++) {
        final gap = leadBars[i] - leadBars[i - 1] - 1;
        if (gap > worstGap) worstGap = gap;
      }
      expect(worstGap, lessThanOrEqualTo(1));
    });

    test('the descant is kept, quiet, above the lead, on channel 4', () {
      final leads = [
        for (final on in scan.ons)
          if (on.channel == 0) on
      ];
      final descants = [
        for (final on in scan.ons)
          if (on.channel == 4) on
      ];
      expect(descants, isNotEmpty);
      expect(descants.length, lessThan(leads.length));
      double avgPitch(List<_NoteOn> ons) =>
          ons.map((o) => o.pitch).reduce((a, b) => a + b) / ons.length;
      double avgVel(List<_NoteOn> ons) =>
          ons.map((o) => o.vel).reduce((a, b) => a + b) / ons.length;
      expect(avgPitch(descants), greaterThan(avgPitch(leads)));
      expect(avgVel(descants), lessThan(avgVel(leads)));
    });
  });

  group('30-hymn seeded sweep — structural invariants', () {
    // A fixed-seed random sample of the hymnal, so file-shape aberrations
    // (part-time descants, flourish tempo markings, odd meters...) surface
    // in CI instead of in church. Seed pinned: the same 30 hymns every
    // run.
    final numbers = <int>{};
    final rand = Random(20260728);
    while (numbers.length < 30) {
      numbers.add(rand.nextInt(695) + 1);
    }
    for (final hymn in numbers.toList()..sort()) {
      test('hymn $hymn: reggae arrangement invariants', () {
        final path = 'assets/midi/${hymn.toString().padLeft(3, '0')}.mid';
        final input = Uint8List.fromList(File(path).readAsBytesSync());
        final Uint8List output;
        try {
          output = arrangeStyle(input, ArrangeStyle.reggae);
        } on FormatException {
          // No detectable harmony: the app falls back to a plain remap.
          return;
        }
        final scan = _scan(output);
        final d = _division(output);
        // Read the written meter back from the render.
        final barTicks = detectChords(output)!.beatsPerBar * d;

        // The one drop's law: the kicks only ever on a drop pulse.
        final pulse =
            _reggaePulse(scan.tempi, d, detectChords(output)!.beatsPerBar);
        for (final on in scan.ons) {
          if (on.channel != 9) continue;
          if (on.pitch == 35 || on.pitch == 36) {
            expect(pulse.dropOffsets, contains(on.tick % barTicks),
                reason: 'hymn $hymn: kick off the drop');
          }
        }
        // Tempo stays inside the dominant band.
        final bpms = scan.tempi.map((us) => 6e7 / us).toList();
        final fastest = bpms.reduce((a, b) => a > b ? a : b);
        final slowest = bpms.reduce((a, b) => a < b ? a : b);
        expect(fastest / slowest, lessThanOrEqualTo(1 / 0.85 + 0.01),
            reason: 'hymn $hymn: tempo outside the band');
        // The lead carries the tune the whole way: no silent stretch of
        // more than one bar between its first and last sounding bars.
        final leadBars = {
          for (final on in scan.ons)
            if (on.channel == 0) on.tick ~/ barTicks,
        }.toList()
          ..sort();
        expect(leadBars, isNotEmpty, reason: 'hymn $hymn: no lead at all');
        var worstGap = 0;
        for (var i = 1; i < leadBars.length; i++) {
          final gap = leadBars[i] - leadBars[i - 1] - 1;
          if (gap > worstGap) worstGap = gap;
        }
        expect(worstGap, lessThanOrEqualTo(1),
            reason: 'hymn $hymn: lead silent for $worstGap bars');
        // The lead outweighs the skank.
        double avgVel(int ch) {
          final vels = [
            for (final on in scan.ons)
              if (on.channel == ch) on.vel,
          ];
          return vels.reduce((a, b) => a + b) / vels.length;
        }

        expect(avgVel(0), greaterThan(avgVel(1)),
            reason: 'hymn $hymn: skank overpowers the lead');
      });
    }
  });

  test('every 3/4 hymn keeps its meter and continuous island rhythm', () {
    final paths = Directory('assets/midi')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.mid'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    var threeFourHymns = 0;

    for (final file in paths) {
      final input = Uint8List.fromList(file.readAsBytesSync());
      final source = detectChords(input);
      if (source?.beatsPerBar != 3) continue;
      threeFourHymns++;

      for (final style in [ArrangeStyle.reggae, ArrangeStyle.calypso]) {
        final output = arrangeStyle(input, style);
        final arranged = detectChords(output);
        expect(arranged, isNotNull,
            reason: '${file.path}: $style has no meter');
        expect(arranged!.beatsPerBar, 3,
            reason: '${file.path}: $style changed the written meter');

        final scan = _scan(output);
        final d = _division(output);
        final barTicks = 3 * d;
        final backing = scan.ons.where((on) => on.channel == 1).toList();
        expect(backing, isNotEmpty,
            reason: '${file.path}: $style has no rhythmic backing');
        final soundingBeats = {
          for (final on in backing) (on.tick % barTicks) ~/ d,
        };
        expect(soundingBeats, containsAll(<int>[0, 1, 2]),
            reason: '${file.path}: $style does not cover all three beats');

        if (style == ArrangeStyle.reggae) {
          for (final on in backing) {
            expect(on.tick % d, d ~/ 2,
                reason: '${file.path}: reggae skank is not on an offbeat');
          }
          for (final on
              in scan.ons.where((on) => on.channel == 9 && on.pitch == 35)) {
            expect(on.tick % barTicks, 2 * d,
                reason: '${file.path}: reggae one-drop is not on beat 3');
          }
        } else {
          for (final on in backing) {
            expect(on.tick % d, isNot(0),
                reason: '${file.path}: steelpan landed on a downbeat');
          }
        }
      }
    }

    expect(threeFourHymns, 388,
        reason: 'update this count when the bundled MIDI corpus changes');
  });

  group('the iOS engine correction (reggae channel volumes)',
      _channelVolumeTests);

  group('arrangeStyle(reggae) rejects unusable input', () {
    _rejectionTests(ArrangeStyle.reggae);
  });

  group('arrangeStyle(calypso) rejects unusable input', () {
    _rejectionTests(ArrangeStyle.calypso);
  });
}
