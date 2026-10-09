import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final newHymns = [
    Hymn(
        number: 1,
        version: 'new',
        title: 'Source title — corazón',
        body: 'Source')
  ];
  final oldHymns = [
    Hymn(number: 1, version: 'old', title: 'Old source', body: 'Source')
  ];
  const readings = AdditionalReadingCatalog([
    AdditionalReading(
        id: 'source-reading',
        edition: 'new',
        order: 0,
        number: 701,
        title: 'Source reading',
        category: 'Source category',
        segments: []),
  ]);
  for (final locale in AppLocalizations.supportedLocales) {
    for (final classic in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
            'keypad messages and controls locale=${locale.languageCode} classic=$classic dark=$dark',
            (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            SharedPreferences.setMockInitialValues({});
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
                home: Scaffold(
                    body: Buttons(
                        hymnsNew: newHymns,
                        hymnsOld: oldHymns,
                        additionalReadings: readings))));
            await tester.pump(const Duration(milliseconds: 300));
            final text = tester.element(find.byType(Buttons)).appText;
            final hint = find.textContaining(classic
                ? text.enterHymnOrReadingNumber
                : text.previewHymnOrReadingHelp);
            await tester.ensureVisible(hint);
            await tester.pump(const Duration(milliseconds: 300));
            expect(hint, findsOneWidget);
            Future<void> digit(String value) async {
              final target = classic
                  ? find.widgetWithText(OutlinedButton, value)
                  : find.widgetWithText(Pressable, value).last;
              await tester.ensureVisible(target);
              await tester.pump(const Duration(milliseconds: 300));
              await tester.tap(target);
              await tester.pump(const Duration(milliseconds: 300));
            }

            await digit('7');
            await digit('0');
            await digit('1');
            final source = find.textContaining('Source reading');
            await tester.ensureVisible(source);
            await tester.pump(const Duration(milliseconds: 300));
            expect(source, findsOneWidget);
            expect(
                classic
                    ? find.textContaining('${text.reading.toUpperCase()}: 701')
                    : find.text(text.reading),
                findsOneWidget);
            final clear = find.bySemanticsLabel(text.clearNumber);
            await tester.ensureVisible(clear);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(clear);
            await tester.pump(const Duration(milliseconds: 300));
            await digit('1');
            expect(
                find.textContaining('Source title — corazón'), findsOneWidget);
            final back = find.bySemanticsLabel(text.deleteDigit);
            await tester.ensureVisible(back);
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(back);
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.textContaining('Source title — corazón'), findsNothing);
            expect(tester.takeException(), isNull);
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
                home: Scaffold(
                    body: Buttons(
                        english: false,
                        newLabel: 'Español · Nuevo',
                        oldLabel: 'Español · Antiguo',
                        hymnsNew: [
                      Hymn(
                          number: 1,
                          version: 'sda-es-2009',
                          title: 'Nuevo corazón',
                          body: 'Source')
                    ],
                        hymnsOld: [
                      Hymn(
                          number: 1,
                          version: 'sda-es-1962',
                          title: 'Antiguo corazón',
                          body: 'Source')
                    ]))));
            await tester.pump(const Duration(milliseconds: 300));
            final nativeHint = find.textContaining(
                classic ? text.enterHymnNumber : text.previewHymnHelp);
            await tester.ensureVisible(nativeHint);
            await tester.pump(const Duration(milliseconds: 300));
            expect(nativeHint, findsOneWidget);
            if (!classic) {
              expect(
                  find.textContaining(
                      'Español · Nuevo 1–1 · Español · Antiguo 1–1'),
                  findsOneWidget);
            }
            await digit('1');
            expect(find.textContaining('Nuevo corazón'), findsOneWidget);
            expect(find.textContaining('Antiguo corazón'), findsOneWidget);
            expect(find.text(text.additionalReadings), findsNothing);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }
}
