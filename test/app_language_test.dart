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
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/favorite_lists.dart';
import 'package:sdahymnal/ui/favorite_order.dart';
import 'package:sdahymnal/ui/fontsize.dart';
import 'package:sdahymnal/ui/hymn_auto_scroll.dart';
import 'package:sdahymnal/services/prefs.dart';
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
  testWidgets('localized favorite dialogs preserve names and book references',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hymn = Hymn(
        number: 230,
        title: 'Abre tu corazón',
        body: 'Letra',
        version: 'sda-es-2009');
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        SharedPreferences.setMockInitialValues({});
        await Favorites.instance.load();
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
              body: FavoritesTab(
            hymnsNew: [],
            hymnsOld: [],
            additionalHymns: [hymn],
          )),
        ));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(FavoritesTab));
        final text = context.appText;
        await tester.tap(find.byKey(const ValueKey('create-favorite-sublist')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(text.create));
        await tester.pumpAndSettle();
        expect(find.text(text.listNameLengthError), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Mis himnos — corazón');
        await tester.tap(find.text(text.create));
        await tester.pumpAndSettle();
        final saved = Favorites.instance;
        final id = saved.sublists.value.single.id;
        await saved.setSublistHymn(id, hymn, true);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('create-favorite-sublist')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Mis himnos — corazón');
        await tester.tap(find.text(text.create));
        await tester.pumpAndSettle();
        expect(find.text(text.listNameDuplicateError), findsOneWidget);
        await tester.tap(find.text(text.cancel));
        await tester.pumpAndSettle();
        editFavoriteSublist(context, list: saved.sublists.value.single);
        await tester.pumpAndSettle();
        expect(find.text(text.renameFavoriteCategory), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Sábado — сердце');
        await tester.tap(find.text(text.save));
        await tester.pumpAndSettle();
        await saved.load();
        expect(saved.sublists.value.single.name, 'Sábado — сердце');
        expect(saved.sublists.value.single.id, id);
        expect(saved.sublists.value.single.hymns, [(n: 230, v: 'sda-es-2009')]);
        expect(tester.takeException(), isNull,
            reason: '${locale.languageCode} categories');
        Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) =>
                FavoriteOrderPage(sublistId: id, resolve: (_) => hymn)));
        await tester.pumpAndSettle();
        expect(find.text(text.reorderList('Sábado — сердце')), findsOneWidget);
        expect(
            find.byWidgetPredicate((widget) =>
                widget is Semantics &&
                widget.properties.label == text.moveHymn(hymn.title)),
            findsOneWidget);
        expect(tester.takeException(), isNull,
            reason: '${locale.languageCode} reorder');
        saved.storageError.value = true;
        await tester.pumpAndSettle();
        expect(find.text(text.savedListError(text.favorites)), findsOneWidget);
        saved.storageError.value = false;
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${locale.languageCode} classic=$classic');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('font and scroll controls fit translated compact layouts',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
              child: child!,
            ),
            home: const FontSizer(),
          ));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(FontSizer));
          final text = context.appText;
          expect(find.text(text.fontSize), findsOneWidget);
          expect(find.text(text.lyricsSize), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} font');
          var speed = 1.0;
          var toggles = 0;
          final controls = HymnAutoScrollControl(
            speed: speed,
            defaultSpeed: 1,
            running: false,
            canToggle: true,
            status: text.startAutoScroll,
            onToggle: () => toggles++,
            onSpeedChanged: (value) => speed = value,
          );
          controls.showControls(context);
          await tester.pumpAndSettle();
          expect(find.text(text.autoScrollSpeed), findsOneWidget);
          await tester.drag(
              find.byKey(const ValueKey('hymn-scroll-speed-slider')),
              const Offset(40, 0));
          await tester.pumpAndSettle();
          expect(speed, greaterThan(1));
          await tester
              .tap(find.byKey(const ValueKey('hymn-scroll-speed-reset')));
          await tester.pumpAndSettle();
          expect(speed, 1);
          await tester.tap(
              find.byKey(const ValueKey('hymn-scroll-toggle-sheet-button')));
          await tester.pumpAndSettle();
          expect(toggles, 1);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
  });
}
