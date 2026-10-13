import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Hymn hymn(String book, int n, String tag) => Hymn(
      number: n,
      version: book,
      languageTag: tag,
      title: '$book $n',
      body: 'Lyrics');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await RecordingVoice.instance.load();
    await KeepScreenOn.instance.set(false);
    MusicPlayerVisible.instance.value = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(channel), (_) async => null);
    }
  });

  for (final classic in [false, true]) {
    testWidgets(
        'paired recordings offer a sung/instrumental choice classic=$classic',
        (tester) async {
      final spanish = hymn('sda-es-2009', 100, 'es');
      expect(MidiPlayer.recordingKinds(spanish),
          [RecordingKind.instrumental, RecordingKind.sung]);
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
        home: HymnPage(hymn: spanish, hymns: [spanish]),
      ));
      await tester.pumpAndSettle();
      final pill = find.byKey(const ValueKey('hymn-recording-kind'));
      expect(pill, findsOneWidget);
      expect(find.text('Instr.'), findsOneWidget);
      await tester.tap(pill);
      await tester.pumpAndSettle();
      expect(RecordingVoice.instance.value, RecordingKind.sung);
      expect(find.text('Sung'), findsOneWidget);
      expect(
          (await SharedPreferences.getInstance()).getString('recordingVoice'),
          'sung');

      await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hymn-recording-choice')),
          findsOneWidget);
      await tester.tap(find.text('Instrumental'));
      await tester.pumpAndSettle();
      expect(RecordingVoice.instance.value, RecordingKind.instrumental);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('single-kind and verified-MIDI hymns show no recording choice',
      (tester) async {
    for (final item in [
      hymn('sda-pt-1996', 5, 'pt'),
      hymn('sda-ru-1997', 5, 'ru'),
      hymn('sda-es-2009', 303, 'es'),
    ]) {
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: HymnPage(hymn: item, hymns: [item]),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hymn-music-player')), findsOneWidget,
          reason: item.version);
      expect(find.byKey(const ValueKey('hymn-recording-kind')), findsNothing,
          reason: item.version);
      await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hymn-recording-choice')), findsNothing,
          reason: item.version);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
