import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/midi_file.dart';
import 'package:sdahymnal/services/midi_render.dart';

import '../tool/export_midi.dart' as exporter;

void main() {
  late Directory directory;
  setUp(() async { directory = await Directory.systemTemp.createTemp('hymnal-export-test-'); });
  tearDown(() async => directory.delete(recursive: true));

  test('export is byte-identical to the app renderer and refuses overwrites', () {
    final output = File('${directory.path}/hymn.mid');
    final args = ['assets/midi/016.mid', output.path, '--ios-mix', '--transpose=2'];
    exporter.exportMidi(args);
    final expected = renderHymnMidi(File(args[0]).readAsBytesSync(),
        theme: 'reggae', forAppleSynth: true, semitones: 2);
    expect(output.readAsBytesSync(), expected);
    expect(() => exporter.exportMidi(args), throwsA(isA<FileSystemException>()));
    expect(output.readAsBytesSync(), expected);
  });

  test('portable and piano-only exports retain the exact requested tracks', () {
    final full = File('${directory.path}/full.mid');
    final solo = File('${directory.path}/piano.mid');
    exporter.exportMidi(['assets/midi/190.mid', full.path]);
    exporter.exportMidi(['assets/midi/190.mid', solo.path, '--piano-only']);
    expect(full.readAsBytesSync(), renderHymnMidi(
        File('assets/midi/190.mid').readAsBytesSync(), theme: 'reggae'));
    expect(solo.readAsBytesSync(), reggaePianoOnlyMidi(full.readAsBytesSync()));
    expect(() => exporter.exportMidi(['assets/midi/190.mid', '${directory.path}/bad.mid',
      '--style=calypso', '--piano-only']), throwsArgumentError);
  });
}
