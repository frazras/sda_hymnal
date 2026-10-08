import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/services/app_language.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/musical_style_sheet.dart';
import 'package:sdahymnal/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'interface preference is independent of books and preserves unknown data',
      () async {
    SharedPreferences.setMockInitialValues({
      'selectedHymnal': 'spanish',
      AppLanguage.preferenceKey: 'future-language'
    });
    await AppLanguage.instance.load();
    expect(AppLanguage.instance.value.languageCode, 'en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppLanguage.preferenceKey), 'future-language');
    await AppLanguage.instance.set('ru');
    await AppLanguage.instance.load();
    expect(AppLanguage.instance.value.languageCode, 'ru');
    expect(prefs.getString('selectedHymnal'), 'spanish');
    await expectLater(AppLanguage.instance.set('invalid'), throwsArgumentError);
    expect(AppLanguage.instance.value.languageCode, 'ru');
    await Future.wait(
        [AppLanguage.instance.set('pt'), AppLanguage.instance.set('es')]);
    expect(AppLanguage.instance.value.languageCode, 'es');
    expect(prefs.getString(AppLanguage.preferenceKey), 'es');
  });

  testWidgets(
      'delegates render each interface language without changing content',
      (tester) async {
    for (final (code, expected) in [
      ('en', 'Search'),
      ('es', 'Buscar'),
      ('pt', 'Buscar'),
      ('ru', 'Поиск')
    ]) {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
            builder: (context) => Scaffold(
                    body: Column(children: [
                  Text(context.appText.search),
                  const Text('Abre tu corazón'),
                ]))),
      ));
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget);
      expect(find.text('Abre tu corazón'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('translated navigation and style sheet fit compact screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          late BuildContext screenContext;
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
              child: child!,
            ),
            home: Builder(builder: (context) {
              screenContext = context;
              return Scaffold(
                body: const Text('Abre tu corazón'),
                bottomNavigationBar:
                    HymnalBottomNav(active: 0, onSelect: (_) {}),
              );
            }),
          ));
          await tester.pumpAndSettle();
          final text = screenContext.appText;
          expect(find.text(text.numbers), findsOneWidget);
          expect(find.text(text.settings), findsOneWidget);
          showMusicalStyleSheet(screenContext);
          await tester.pumpAndSettle();
          expect(find.text(text.musicalStyle.toUpperCase()), findsOneWidget);
          expect(find.text(text.jazz), findsOneWidget);
          expect(find.text('Abre tu corazón'), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
          Navigator.of(screenContext).pop();
          await tester.pumpAndSettle();
        }
      }
    }
  });
}
