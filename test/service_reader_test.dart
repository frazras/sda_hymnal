import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_ref.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/service_playlist.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/additional_readings.dart';
import 'package:sdahymnal/ui/service_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hymn = Hymn(
      number: 7, version: 'new', title: 'Opening and closing', body: 'Lyrics');
  final spanish =
      Hymn(number: 7, version: 'sda-es-2009', title: 'Español', body: 'Letra');
  const reading = AdditionalReading(
      id: 'r701',
      edition: 'new',
      order: 0,
      number: 701,
      title: 'Reading',
      category: 'Worship',
      segments: [ReadingSegment(role: 'leader', text: 'Read together.')]);
  final repository = HymnalRepository(editions: const [
    HymnalEdition.englishNew,
    HymnalEdition(
        id: 'sda-es-2009',
        languageTag: 'es',
        displayName: 'Español',
        year: 2009)
  ], hymns: [
    hymn,
    spanish
  ], readings: [
    reading
  ]);
  ServiceReader reader(List<HymnRef> refs) => ServiceReader(
      repository: repository,
      playlist: ServicePlaylist(id: 'service', name: 'Sabbath', entries: [
        for (var i = 0; i < refs.length; i++)
          ServiceEntry(id: 'entry-$i', ref: refs[i]),
      ]));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await KeepScreenOn.instance.set(false);
    await Favorites.instance.load();
    await Recents.instance.load();
    await Autoplay.instance.set(false);
    MusicPlayerVisible.instance.value = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(channel), (_) async => null);
    }
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'];
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      return null;
    });
  });

  test('automatic continuation cannot skip a reading, missing item or media',
      () {
    for (final barrier in [
      reading.ref,
      spanish.ref,
      HymnRef(bookId: 'missing', itemId: '7')
    ]) {
      final session = reader([hymn.ref, barrier, hymn.ref]);
      final first = session.page(0) as HymnPage;
      expect(
          first.sequence!.page(1, continuation: HymnContinuation.midi), isNull);
      expect(first.sequence!.page(1, continuation: HymnContinuation.video),
          isNull);
      expect(first.sequence!.page(1), isNotNull);
    }
    final session = reader([hymn.ref, hymn.ref]);
    final first = session.page(0) as HymnPage;
    final repeat = first.sequence!.page(1, continuation: HymnContinuation.midi)
        as HymnPage;
    expect(repeat.key, isNot(first.key));
    expect(repeat.continuation, HymnContinuation.midi);
    expect(repeat.sequence!.page(1), isNull);
    expect(repeat.sequence!.label, contains('2 of 2'));
  });

  for (final classic in [false, true]) {
    testWidgets(
        'shared readers follow hymn-reading-repeat sequence classic=$classic',
        (tester) async {
      final session = reader([hymn.ref, reading.ref, hymn.ref]);
      await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
          home: session.page(0)));
      await tester.pumpAndSettle();
      expect(find.text('Service: Sabbath · 1 of 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.byType(AdditionalReadingPage), findsOneWidget);
      expect(find.text('Service: Sabbath · 2 of 3'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(HymnPage), findsOneWidget);
      expect(find.text('Service: Sabbath · 3 of 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Service: Sabbath · 3 of 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.byType(AdditionalReadingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
