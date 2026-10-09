import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_occasion.dart';
import 'package:sdahymnal/services/trends.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/additional_readings.dart';
import 'package:sdahymnal/ui/hymn_occasions.dart';

import 'trends_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hymns = [
    Hymn(number: 1, version: 'new', title: 'Corazón — source', body: 'Source'),
    Hymn(number: 2, version: 'old', title: 'Old source', body: 'Source'),
  ];
  const reading = AdditionalReading(
      id: 'source-reading',
      edition: 'new',
      order: 0,
      number: 701,
      title: 'Source reading',
      category: 'Source category',
      scriptureReference: 'Juan 3:16',
      segments: [ReadingSegment(role: 'leader', text: 'Source reading body.')]);
  const catalog = AdditionalReadingCatalog([reading]);
  const topic = HymnOccasion(
      id: 'source-topic',
      title: 'Celebración',
      description: 'Source description.',
      newNumbers: [1],
      oldNumbers: [2],
      newReadingNumbers: [701]);

  for (final locale in AppLocalizations.supportedLocales) {
    for (final classic in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
            'topic controls preserve source assignments locale=${locale.languageCode} classic=$classic dark=$dark',
            (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            TrendsRepository.cacheKey: fixture(),
            TrendsRepository.fetchedKey: DateTime.now().millisecondsSinceEpoch,
          });
          Widget app(Widget page) => MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: buildHymnalTheme(
                  dark ? HymnalTokens.dark : HymnalTokens.light,
                  classic: classic),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.3)),
                  child: child!),
              home: page);
          await tester.pumpWidget(app(HymnOccasionsPage(hymns: hymns)));
          await tester.pumpAndSettle();
          final text = tester.element(find.byType(HymnOccasionsPage)).appText;
          expect(find.text(text.hymnsByOccasion), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Prayer meetings');
          await tester.pumpAndSettle();
          expect(find.text('Meditation and Prayer'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'not a topic');
          await tester.pumpAndSettle();
          expect(find.text(text.noMatchingTopics), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(app(OccasionHymnsPage(
              occasion: topic, hymns: hymns, readingCatalog: catalog)));
          await tester.pumpAndSettle();
          expect(find.text('Celebración'), findsOneWidget);
          expect(
              find.textContaining(
                  '${text.hymnCount(1)} • ${text.topicReadingCount(1)}'),
              findsOneWidget);
          expect(find.text('Corazón — source'), findsOneWidget);
          await tester.tap(find.text(text.oldHymnal));
          await tester.pumpAndSettle();
          expect(find.text('Old source'), findsOneWidget);
          expect(find.text('Corazón — source'), findsNothing);
          expect(
              find.textContaining(
                  '${text.hymnCount(1)} • ${text.topicReadingCount(0)}'),
              findsOneWidget);
          await tester.tap(find.text(text.newHymnal));
          await tester.pumpAndSettle();
          final scroll = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(find.text('Source reading'), 200,
              scrollable: scroll);
          await tester.pumpAndSettle();
          expect(find.text(text.scriptureReadings), findsOneWidget);
          expect(find.text('${text.reading} • Juan 3:16'), findsOneWidget);
          await tester.tap(find.text('Source reading'));
          await tester.pumpAndSettle();
          final page = tester.widget<AdditionalReadingPage>(
              find.byType(AdditionalReadingPage));
          expect(page.reading, same(reading));
          expect(page.categoryTitle, 'Celebración');
          expect(find.text(text.categoryPosition('Celebración', 1, 1)),
              findsOneWidget);
          expect(find.text('Source reading body.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
      'reading load failure offers translated retry and recovers source data',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var fail = true;
    var requests = 0;
    Completer<ByteData?>? loading;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = const StringCodec().decodeMessage(message);
      if (key == 'assets/additional_readings.json') {
        requests++;
        if (loading != null) return loading.future;
        if (fail) return null;
        return ByteData.sublistView(File(key!).readAsBytesSync());
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMessageHandler('flutter/assets', null);
      rootBundle.evict('assets/additional_readings.json');
    });
    final readingOnly =
        hymnOccasions.singleWhere((o) => o.title == 'Christian Life');
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues({
        TrendsRepository.cacheKey: fixture(),
        TrendsRepository.fetchedKey: DateTime.now().millisecondsSinceEpoch,
      });
      rootBundle.evict('assets/additional_readings.json');
      fail = true;
      final previousRequests = requests;
      loading = Completer<ByteData?>();
      await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildHymnalTheme(HymnalTokens.dark),
          home: OccasionHymnsPage(occasion: readingOnly, hymns: hymns)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final text = tester.element(find.byType(OccasionHymnsPage)).appText;
      expect(find.textContaining(text.topicReadingsLoading), findsOneWidget);
      loading.complete(null);
      loading = null;
      await tester.pumpAndSettle();
      expect(find.text(text.readingsLoadRetry), findsOneWidget);
      expect(
          find.textContaining(text.topicReadingsUnavailable), findsOneWidget);
      fail = false;
      await tester.tap(find.text(text.readingsLoadRetry));
      await tester.pump();
      // The real catalog is large enough for AssetBundle to decode in an isolate.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Blessed is the Man'), findsOneWidget);
      expect(requests, previousRequests + 2);
      expect(find.textContaining(text.topicReadingsUnavailable), findsNothing);
      expect(find.text(text.readingsLoadRetry), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
