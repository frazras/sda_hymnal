import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/additional_readings.dart';
import 'package:sdahymnal/ui/report_error.dart';
import 'package:sdahymnal/ui/service_reader.dart';
import 'package:sdahymnal/models/service_playlist.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';

void main() {
  final catalog = AdditionalReadingCatalog([
    AdditionalReading(
        id: 'first',
        edition: 'new',
        order: 0,
        number: 700,
        title: 'Corazón de oración',
        category: 'Oración',
        scriptureReference: 'Juan 3:16',
        segments: [
          for (var i = 0; i < 12; i++)
            ReadingSegment(
                role: i.isEven ? 'leader' : 'congregation',
                text: 'Texto original $i: paz, corazón y esperanza.'),
        ]),
    const AdditionalReading(
        id: 'second',
        edition: 'new',
        order: 1,
        number: 701,
        title: 'Paz',
        category: 'Oración',
        segments: [
          ReadingSegment(
              role: 'leader', text: 'Texto original de la segunda lectura.')
        ]),
  ]);
  for (final locale in AppLocalizations.supportedLocales) {
    for (final classic in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
            'reading search and controls retain source locale=${locale.languageCode} classic=$classic dark=$dark',
            (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
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
            home: AdditionalReadingsPage(catalog: catalog),
          ));
          await tester.pumpAndSettle();
          final text =
              tester.element(find.byType(AdditionalReadingsPage)).appText;
          expect(find.text(text.additionalReadingsTitle), findsOneWidget);
          expect(find.text(text.searchReadings), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'corazon');
          await tester.pumpAndSettle();
          expect(find.text('700  Corazón de oración'), findsOneWidget);
          expect(find.text('701  Paz'), findsNothing);
          await tester.enterText(find.byType(TextField), 'missing');
          await tester.pumpAndSettle();
          expect(find.text(text.noMatchingReadings), findsOneWidget);
          await tester.enterText(find.byType(TextField), '');
          await tester.pumpAndSettle();
          final chip = find.widgetWithText(ChoiceChip, 'Oración');
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
          await tester.tap(find.text('700  Corazón de oración'));
          await tester.pumpAndSettle();
          expect(find.text(text.categoryPosition('Oración', 1, 2)),
              findsOneWidget);
          expect(find.text(text.readingScripture('Juan 3:16')), findsOneWidget);
          final leader = tester.widget<Text>(
              find.text(catalog.readings.first.segments.first.text));
          expect(leader.style?.fontWeight, FontWeight.w400);
          await tester.tap(find.text(text.startAutoScroll));
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.text(text.pauseReading), findsOneWidget);
          await tester.tap(find.text(text.pauseReading));
          await tester.pumpAndSettle();
          expect(find.text(text.startAutoScroll), findsOneWidget);
          await tester.tap(find.byTooltip(text.readingOptions));
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.reportErrors));
          await tester.pumpAndSettle();
          final report =
              tester.widget<ReportErrorPage>(find.byType(ReportErrorPage));
          expect(report.subject.kind, 'reading');
          expect(report.subject.title, 'Corazón de oración');
          expect(report.subject.itemId, 'first');
          expect(report.subject.number, 700);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          await tester.drag(
              find.byKey(const ValueKey('additional-reading-scroll')),
              const Offset(-300, 0));
          await tester.pumpAndSettle();
          expect(find.text(text.categoryPosition('Oración', 2, 2)),
              findsOneWidget);
          expect(find.text('Texto original de la segunda lectura.'),
              findsOneWidget);
          await tester.drag(
              find.byKey(const ValueKey('additional-reading-scroll')),
              const Offset(-300, 0));
          await tester.pumpAndSettle();
          expect(find.text(text.categoryPosition('Oración', 1, 2)),
              findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
      'service reading buttons and position labels fit all interface languages',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = HymnalRepository(
        editions: const [HymnalEdition.englishNew],
        hymns: const [],
        readings: catalog.readings);
    final playlist =
        ServicePlaylist(id: 'service', name: 'Oración — сердце', entries: [
      for (final reading in catalog.readings)
        ServiceEntry(id: reading.id, ref: reading.ref)
    ]);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
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
              home: ServiceReader(playlist: playlist, repository: repository)
                  .page(0)));
          await tester.pumpAndSettle();
          final text =
              tester.element(find.byType(AdditionalReadingPage)).appText;
          expect(find.text(text.servicePosition(playlist.name, 1, 2)),
              findsOneWidget);
          expect(
              tester
                  .widget<TextButton>(
                      find.widgetWithText(TextButton, text.previousControl))
                  .onPressed,
              isNull);
          await tester.tap(find.text(text.nextControl));
          await tester.pumpAndSettle();
          expect(find.text('701  Paz'), findsOneWidget);
          expect(find.text(text.servicePosition(playlist.name, 2, 2)),
              findsOneWidget);
          expect(
              tester
                  .widget<TextButton>(
                      find.widgetWithText(TextButton, text.nextControl))
                  .onPressed,
              isNull);
          await tester.tap(find.text(text.previousControl));
          await tester.pumpAndSettle();
          expect(find.text('700  Corazón de oración'), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
  });
}
