import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/chord_detect.dart';

void main() {
  for (final file in ['388.mid', 'C653.mid', 'es-2009-230.mid']) {
    test('$file retains compound meter across chord difficulties', () {
      final track = detectChords(File('assets/midi/$file').readAsBytesSync())!;
      expect(track.beatsPerBar, 6);
      expect(track.denominator, 8);
      expect(track.meterLabel, '6/8');
      for (final level in ChordLevel.values) {
        final simplified = simplifyTrack(track, level);
        expect(simplified.meterLabel, '6/8');
        expect(simplified.measureStartMs, track.measureStartMs);
      }
    });
  }
  test('existing manually constructed quarter-note tracks retain 4/4', () {
    final track =
        ChordTrack(chords: [], key: null, beatsPerBar: 4, measureStartMs: []);
    expect(track.meterLabel, '4/4');
  });
}
