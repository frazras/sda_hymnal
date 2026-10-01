import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/services/midi_file.dart';
import 'package:sdahymnal/services/style_arranger.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/music_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Jazz melody defaults to 50 percent and mixer overrides persist',
      () async {
    final bytes = File('assets/midi/016.mid').readAsBytesSync();
    expect(
        renderHymnMidi(bytes, theme: 'jazz'),
        transformMidi(arrangeStyle(bytes, ArrangeStyle.jazz),
            channelVolumes: {0: 50}));
    SharedPreferences.setMockInitialValues({});
    final options = MusicOptions.instance;
    await options.load();
    expect(options.styleVolumes('jazz')[0], 50);
    await options.setCustomInstruments(true);
    expect(options.styleVolumes('jazz')[0], 50);
    await options.setStyleVolume('jazz', 0, 100);
    await options.load();
    expect(options.styleVolumes('jazz')[0], 100);
    await options.setStyleVolume('jazz', 0, 50);
    await options.load();
    expect(options.styleVolumes('jazz')[0], 50);
    expect(options.styleVolumes('gospel'), isEmpty);
  });

  test('Jazz is selectable with its own arrangement and mixer', () {
    expect(InstrumentTheme.themes, contains(('jazz', 'Jazz', null)));
    expect(arrangedMidiThemes.containsKey('jazz'), isTrue);
    expect(instrumentRoles('jazz')[2], 'Walking bass');
    expect(instrumentRoles('jazz')[9], 'Drum kit');
  });

  test('Jamaican Gospel is selectable with its own arrangement and mixer', () {
    expect(InstrumentTheme.themes,
        contains(('jamaican_gospel', 'Jamaican Gospel', null)));
    expect(arrangedMidiThemes.containsKey('jamaican_gospel'), isTrue);
    expect(instrumentRoles('jamaican_gospel')[1], 'Offbeat organ');
  });

  test(
      'muting every bundled track preserves conductor, duration and other parts',
      () {
    final counts = <String, int>{'old': 0, 'new': 0};
    for (final file in Directory('assets/midi')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mid'))) {
      final bytes = file.readAsBytesSync();
      final parts = midiParts(bytes);
      if (parts.length > 1) {
        counts[file.uri.pathSegments.last.startsWith('C') ? 'old' : 'new'] =
            counts[file.uri.pathSegments.last.startsWith('C')
                    ? 'old'
                    : 'new']! +
                1;
      }
      final silent = mixMidiParts(bytes, parts.map((p) => p.index).toSet());
      expect(midiParts(silent), isEmpty, reason: file.path);
      expect(readMidiDuration(silent), readMidiDuration(bytes),
          reason: file.path);
      if (parts.length > 1) {
        final solo =
            mixMidiParts(bytes, parts.skip(1).map((p) => p.index).toSet());
        expect(midiParts(solo), [parts.first], reason: file.path);
        expect(midiTrackChunks(solo)[parts.first.index],
            midiTrackChunks(bytes)[parts.first.index]);
        expect(midiTrackChunks(solo).first, midiTrackChunks(bytes).first);
      }
    }
    // Guard availability in both collections without assuming every tune is SATB.
    expect(counts['old'], greaterThan(600));
    expect(counts['new'], greaterThan(0));
  });

  test('Old 1 has named SATB and choir ignores style and instrument overrides',
      () {
    final bytes = File('assets/midi/C001.mid').readAsBytesSync();
    expect(midiParts(bytes).map((p) => p.name),
        ['Soprano', 'Alto', 'Tenor', 'Bass']);
    final muted = midiParts(bytes).skip(1).map((p) => p.index).toSet();
    for (final style in [
      'classic',
      'gospel',
      'reggae',
      'calypso',
      'jamaican_gospel',
      'jazz'
    ]) {
      expect(
          renderHymnMidi(bytes,
              theme: style,
              choirPractice: true,
              mutedTracks: muted,
              channelPrograms: {0: 114},
              semitones: 2),
          transformMidi(mixMidiParts(bytes, muted), semitones: 2));
    }
  });

  test(
      'muting running-status notes retains trailing rests and surviving events',
      () {
    final track = [
      0,
      0x90,
      60,
      100,
      10,
      64,
      100,
      10,
      60,
      0,
      0,
      64,
      0,
      10,
      0xff,
      0x2f,
      0
    ];
    final bytes = Uint8List.fromList([
      77,
      84,
      104,
      100,
      0,
      0,
      0,
      6,
      0,
      0,
      0,
      1,
      0,
      96,
      77,
      84,
      114,
      107,
      0,
      0,
      0,
      track.length,
      ...track
    ]);
    final silent = mixMidiParts(bytes, {0});
    expect(midiParts(silent), isEmpty);
    expect(readMidiDuration(silent), readMidiDuration(bytes));
    expect(midiTrackChunks(silent), hasLength(1));
  });

  test('custom ensemble programs retain notes, timing and other instruments',
      () {
    final bytes = File('assets/midi/016.mid').readAsBytesSync();
    for (final style in [
      'gospel',
      'reggae',
      'calypso',
      'jamaican_gospel',
      'jazz'
    ]) {
      final standard = renderHymnMidi(bytes, theme: style);
      final custom =
          renderHymnMidi(bytes, theme: style, channelPrograms: {0: 73, 2: 32});
      expect(custom, transformMidi(standard, channelPrograms: {0: 73, 2: 32}));
      expect(custom, isNot(standard));
      expect(channelStats(custom), channelStats(standard));
      expect(readMidiDuration(custom), readMidiDuration(standard));
    }
  });

  test(
      'settings default off, persist per style and preserve choices when disabled',
      () async {
    SharedPreferences.setMockInitialValues({});
    final options = MusicOptions.instance;
    await options.load();
    expect(options.choirPractice, false);
    expect(options.customInstruments, false);
    await options.setCustomInstruments(true);
    await options.setProgram('gospel', 0, 73);
    await options.setProgram('reggae', 0, 114);
    await options.renamePart('old:1', 1, 'Soprano rehearsal');
    await options.setChoirPractice(true);
    await options.load();
    expect(options.programs('gospel'), {0: 73});
    expect(options.programs('reggae'), {0: 114});
    expect(options.partName('old:1', 1, 'Soprano'), 'Soprano rehearsal');
    expect(options.partName('old:2', 1, 'Soprano'), 'Soprano');
    expect(options.choirPractice, true);
    await options.setCustomInstruments(false);
    expect(options.programs('gospel'), isEmpty);
    await options.setCustomInstruments(true);
    expect(options.programs('gospel'), {0: 73});
    await options.setProgram('gospel', 0, null);
    expect(options.programs('gospel'), isEmpty);
  });

  test('all four arranged styles can silence and solo their drum kit',
      () async {
    SharedPreferences.setMockInitialValues({});
    final options = MusicOptions.instance;
    await options.load();
    await options.setCustomInstruments(true);
    final source = File('assets/midi/108.mid').readAsBytesSync();
    for (final style in arrangedMidiThemes.keys) {
      expect(instrumentRoles(style)[9], 'Drum kit');
      final full = renderHymnMidi(source, theme: style);
      final noDrums =
          renderHymnMidi(source, theme: style, channelVolumes: {9: 0});
      expect(channelStats(noDrums), channelStats(full));
      expect(midiTrackChunks(noDrums).last, isNot(midiTrackChunks(full).last));
      expect(readMidiDuration(noDrums), readMidiDuration(full));
      await options.setStyleVolume(style, 9, 40);
      await options.setStyleSolo(style, 9, true);
      await options.load();
      expect(options.styleVolumes(style)[9], 40);
      expect(options.styleSolo(style), {9});
      final drumsOnly = renderHymnMidi(source,
          theme: style,
          mutedChannels:
              instrumentRoles(style).keys.where((ch) => ch != 9).toSet());
      expect(channelStats(drumsOnly), isEmpty);
      expect(midiTrackChunks(drumsOnly).last, midiTrackChunks(full).last);
      final melodyOnly = renderHymnMidi(source,
          theme: style,
          mutedChannels:
              instrumentRoles(style).keys.where((ch) => ch != 0).toSet());
      expect(channelStats(melodyOnly).keys, [0]);
    }
  });

  testWidgets('drum kit volume and solo controls are editable', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await MusicOptions.instance.load();
    await MusicOptions.instance.setCustomInstruments(true);
    await InstrumentTheme.instance.set('jamaican_gospel');
    await tester.pumpWidget(const MaterialApp(home: EnsembleInstrumentsPage()));
    final slider = find.byKey(const ValueKey('style-volume-9'));
    await tester.scrollUntilVisible(slider, 200);
    tester.widget<Slider>(slider).onChanged!(35);
    await tester.pumpAndSettle();
    final solo = find.byKey(const ValueKey('style-solo-9'));
    await tester.ensureVisible(solo);
    await tester.tap(solo);
    await tester.pumpAndSettle();
    expect(MusicOptions.instance.styleVolumes('jamaican_gospel')[9], 35);
    expect(MusicOptions.instance.styleSolo('jamaican_gospel'), {9});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await InstrumentTheme.instance.set('classic');
  });

  testWidgets('ensemble editor fits narrow screens with large text',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await MusicOptions.instance.load();
    await MusicOptions.instance.setCustomInstruments(true);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!),
      home: const EnsembleInstrumentsPage(),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.textContaining('All melodic parts'), 150);
    expect(find.textContaining('All melodic parts'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Preview • Amazing Grace'), 150);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
