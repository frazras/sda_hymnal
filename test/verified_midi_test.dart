import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/midi_cache.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/verified_midi.dart';

void main() {
  test('only the reviewed exact Spanish edition resolves', () {
    expect(hymnMidiAsset('sda-es-2009', 303), 'midi/es-2009-303.mid');
    for (final book in [
      'sda-es-1962',
      'sda-fr-hymnes-et-louanges',
      'unknown'
    ]) {
      expect(hymnMidiAsset(book, 303), isNull);
    }
    expect(hymnMidiAsset('sda-es-2009', 108), isNull);
    expect(hymnMidiAsset('sda-es-2009', 302), isNull);
    expect(hymnMidiAsset('new', 108), 'midi/108.mid');
    expect(hymnMidiAsset('old', 295), 'midi/C295.mid');
  });

  test('Spanish form has three verses and its own cache identity', () {
    final spanish = File('assets/midi/es-2009-303.mid').readAsBytesSync();
    final english = File('assets/midi/108.mid').readAsBytesSync();
    expect(readMidiDuration(spanish).inMilliseconds, closeTo(116418, 1));
    expect(readMidiDuration(english).inMilliseconds, closeTo(180700, 1));
    expect(readKeySignature(spanish).toString(),
        readKeySignature(english).toString());
    String cache(String book, int number) => MidiRenderCache.filename(
        hymnal: book,
        hymn: number,
        semitones: 0,
        theme: 'classic',
        forAppleSynth: true);
    expect(cache('sda-es-2009', 303), startsWith('sda-es-2009_303_'));
    expect(cache('sda-es-2009', 303), isNot(cache('new', 108)));
    expect(() => cache('sda-es-1962', 303), throwsArgumentError);
  });

  for (final style in ['classic', ...arrangedMidiThemes.keys]) {
    test('verified Spanish arrangement renders in $style with transposition',
        () {
      final bytes = File('assets/midi/es-2009-303.mid').readAsBytesSync();
      final rendered = renderHymnMidi(bytes,
          theme: style, semitones: 2, forAppleSynth: true);
      expect(readMidiDuration(rendered).inSeconds, greaterThan(60));
      expect(readMidiDuration(rendered).inSeconds, lessThan(180));
      expect(midiParts(rendered), isNotEmpty);
    });
  }
}
