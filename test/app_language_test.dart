import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/services/app_language.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/musical_style_sheet.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymnlist.dart';
import 'package:sdahymnal/ui/hymnal_browser.dart';
import 'package:sdahymnal/models/hymn.dart';

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
  testWidgets(
      'localized search retains accent ranking and fits compact filters',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hymns = [
      Hymn(
          number: 230,
          title: 'Abre tu corazón',
          body: 'Ven al Señor',
          version: 'sda-es-2009'),
      Hymn(
          number: 12,
          title: 'Otra canción',
          body: 'corazón',
          version: 'sda-es-1962'),
    ];
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildHymnalTheme(HymnalTokens.dark, classic: classic),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
              body: HymnList(
            english: false,
            hymns: hymns,
            hymnsNew: [hymns.first],
            hymnsOld: [hymns.last],
          )),
        ));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'corazon');
        await tester.pump(const Duration(milliseconds: 400));
        final title =
            find.text(classic ? '230. Abre tu corazón' : 'Abre tu corazón');
        final other = find.text(classic ? '12. Otra canción' : 'Otra canción');
        expect(title, findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: '${locale.languageCode} classic=$classic');
        final titleY = tester.getTopLeft(title).dy;
        final bodyY = tester.getTopLeft(other).dy;
        expect(titleY, lessThan(bodyY));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('all-language search keeps translated actions above keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildHymnalTheme(HymnalTokens.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(1.3),
              viewInsets: const EdgeInsets.only(bottom: 220)),
          child: child!,
        ),
        home: const Scaffold(
            body: AllHymnalsSearch(hymns: [], keyboardOpen: true)),
      ));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AllHymnalsSearch));
      expect(find.text(context.appText.done), findsOneWidget);
      expect(find.text(context.appText.noMatchingHymns), findsOneWidget);
      expect(tester.takeException(), isNull, reason: locale.languageCode);
    }
  });
}
