import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/ui/music_options.dart';
import 'package:sdahymnal/ui/instrument_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('part controls are opt-in and allow mute, solo and reset',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await MusicOptions.instance.load();
    final hymn = Hymn(number: 1, title: '', body: '', version: 'old');
    final player = MidiPlayer.instance;
    player.parts.value =
        midiParts(File('assets/midi/C001.mid').readAsBytesSync());
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ChoirPartsButton(hymn: hymn))));
    expect(find.byKey(const ValueKey('choir-parts')), findsNothing);
    await MusicOptions.instance.setChoirPractice(true);
    await tester.pump();
    expect(find.byKey(const ValueKey('choir-parts')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choir-parts')));
    await tester.pumpAndSettle();
    expect(find.text('Soprano'), findsOneWidget);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final path = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      return ByteData.sublistView(File(path).readAsBytesSync());
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    final initialHeight = tester.getSize(find.byType(Card).first).height;
    await tester.tap(find.byType(InstrumentPicker).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cello'));
    await tester.pumpAndSettle();
    expect(MusicOptions.instance.trackPrograms('old:1'), {1: 42});
    expect(
        tester
            .widget<InstrumentPicker>(find.byType(InstrumentPicker).first)
            .program,
        42);
    expect(tester.getSize(find.byType(Card).first).height, initialHeight);
    expect(initialHeight, lessThanOrEqualTo(208));

    await tester.tap(find.text('Mute').first);
    await tester.pumpAndSettle();
    expect(player.mutedParts.value, {1});
    await tester.tap(find.text('Solo').first);
    await tester.pumpAndSettle();
    expect(player.soloParts.value, {1});
    await tester.scrollUntilVisible(
        find.text('Reset mix • Hear all parts'), 200);
    await tester.tap(find.text('Reset mix • Hear all parts'));
    await tester.pumpAndSettle();
    expect(player.mutedParts.value, isEmpty);
    expect(player.soloParts.value, isEmpty);
  });
}
