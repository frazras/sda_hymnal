import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/services/trends.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/statistics.dart';

import 'trends_test.dart' show fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('localized statistics preserve data and fit compact layouts',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = jsonDecode(fixture()) as Map<String, dynamic>;
    for (final period in (data['periods'] as Map).values) {
      final song = (period['top_songs'] as List).single;
      song['title'] = 'Abre Tu Corazón — source title';
      song['count'] = int.parse((data['periods'] as Map)
              .entries
              .firstWhere((e) => identical(e.value, period))
              .key) *
          1234;
      period['repeat_songs'] = [
        {...song, 'count': 1}
      ];
      period['favorites'] = [
        {...song, 'count': 2}
      ];
      period['countries'] = [
        {
          'country': 'GB',
          'songs': [song]
        },
        {
          'country': 'XX',
          'songs': [song]
        },
      ];
    }
    final source = jsonEncode(data);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          var fail = true;
          final requests = <bool>[];
          await tester.pumpWidget(MaterialApp(
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
            home: StatisticsPage(
                hymns: const [],
                load: (force) async {
                  requests.add(force);
                  if (fail) throw const SocketException('offline');
                  return TrendsSnapshot.parse(source, offline: true);
                }),
          ));
          await tester.pumpAndSettle();
          final text = tester.element(find.byType(StatisticsPage)).appText;
          final scroll = find
              .descendant(
                  of: find.byKey(const ValueKey('statistics-list')),
                  matching: find.byType(Scrollable))
              .first;
          Future<void> reveal(Finder finder) async {
            await tester.scrollUntilVisible(finder, 200,
                scrollable: scroll, maxScrolls: 100);
            await tester.pumpAndSettle();
          }

          expect(find.text(text.statisticsTitle), findsOneWidget);
          await reveal(find.text(text.retry));
          fail = false;
          await tester.tap(find.text(text.retry));
          await tester.pumpAndSettle();
          expect(requests, [false, true]);
          await tester.drag(find.byKey(const ValueKey('statistics-list')),
              const Offset(0, 2000));
          await tester.pumpAndSettle();
          await reveal(find.text(text.lastWeek));
          await tester.tap(find.text(text.lastWeek));
          await tester.pumpAndSettle();
          expect(
              tester
                  .widget<ChoiceChip>(
                      find.widgetWithText(ChoiceChip, text.lastWeek))
                  .selected,
              isTrue);
          final dates = find.textContaining(
              statisticDate(DateTime(2026, 8, 10), text.localeName));
          await reveal(dates);
          expect(dates, findsOneWidget);
          await reveal(find.textContaining(text.savedReport));
          expect(find.textContaining(text.savedReport), findsOneWidget);
          await reveal(find.text(
              '${text.statisticsNewEdition} 1 · ${text.statisticsOpens(1234)}'));
          expect(find.text('Abre Tu Corazón — source title'), findsWidgets);
          for (final (heading, countText) in [
            (text.returningHymns, text.statisticsRepeatOpens(1)),
            (text.addedToFavorites, text.statisticsAdditions(2)),
          ]) {
            await reveal(find.text(heading));
            await reveal(
                find.text('${text.statisticsNewEdition} 1 · $countText'));
          }
          await reveal(find.text(text.whenHymnalOpened));
          await reveal(find.text(
              '${text.statisticsMorning} · ${text.statisticsOpens(250)}'));
          expect(
              find.text(
                  '${text.statisticsNight} · ${text.notEnoughPublishedData}'),
              findsOneWidget);
          await reveal(find.text(text.daysFilledWithSong));
          final saturday =
              DateFormat.EEEE(text.localeName).format(DateTime(2024, 1, 6));
          await reveal(find.text('$saturday · ${text.statisticsOpens(200)}'));
          await reveal(find.text(text.countryIsoCode));
          await reveal(find.text('${text.countryGB} (GB)'));
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('XX').last);
          await tester.pumpAndSettle();
          expect(
              tester
                  .widget<DropdownButtonFormField<String>>(
                      find.byType(DropdownButtonFormField<String>))
                  .initialValue,
              'XX');
          await reveal(find.text(text.statisticsExplanation));
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
          expect(jsonEncode(data), source);
        }
      }
    }
  });

  testWidgets('locale formatting and plural forms cover large and small counts',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: SizedBox()),
      ));
      await tester.pumpAndSettle();
      final text = tester.element(find.byType(Scaffold)).appText;
      expect(statisticNumber(1234567, text.localeName),
          NumberFormat.decimalPattern(text.localeName).format(1234567));
      for (final count in [0, 1, 2, 5, 21, 1234]) {
        expect(text.statisticsOpens(count),
            contains(statisticNumber(count, text.localeName)));
      }
      if (locale.languageCode == 'ru') {
        expect(text.statisticsOpens(1), '1 открытие');
        expect(text.statisticsOpens(2), '2 открытия');
        expect(text.statisticsOpens(5), '5 открытий');
        expect(text.statisticsOpens(21), '21 открытие');
      }
    }
  });
}
