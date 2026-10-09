import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/services/app_language.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/settings.dart';

void main() {
  testWidgets(
      'switch interface language and retain book/settings across designs and themes',
      (tester) async {
    for (final classic in [false, true]) {
      for (final dark in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        SharedPreferences.setMockInitialValues({
          'selectedHymnal': 'spanish',
          'favorites': 'preserve',
          'melodyVolume': .5,
          AppLanguage.preferenceKey: 'en',
        });
        await AppLanguage.instance.load();
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ValueListenableBuilder<Locale>(
          valueListenable: AppLanguage.instance,
          builder: (context, locale, _) => MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildHymnalTheme(
                dark ? HymnalTokens.dark : HymnalTokens.light,
                classic: classic),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!),
            home: const Scaffold(body: Settings()),
          ),
        ));
        await tester.pumpAndSettle();
        for (final code in ['es', 'pt', 'ru', 'en']) {
          final text = tester.element(find.byType(Settings)).appText;
          await tester.scrollUntilVisible(
              find.text(text.interfaceLanguage), 250,
              scrollable: find
                  .descendant(
                      of: find.byKey(const ValueKey('settings-list')),
                      matching: find.byType(Scrollable))
                  .first);
          await tester.ensureVisible(find.text(text.interfaceLanguage));
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.interfaceLanguage));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
              find.byKey(ValueKey('interface-language-$code')), 100,
              scrollable: find.byType(Scrollable).last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('interface-language-$code')));
          await tester.pumpAndSettle();
          for (var i = 0;
              i < 10 && AppLanguage.instance.value.languageCode != code;
              i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          expect(AppLanguage.instance.value.languageCode, code);
          expect(
              tester.element(find.byType(Settings)).appText.localeName, code);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('selectedHymnal'), 'spanish');
          expect(prefs.getString('favorites'), 'preserve');
          expect(prefs.getDouble('melodyVolume'), .5);
          expect(prefs.getString(AppLanguage.preferenceKey), code);
          expect(tester.takeException(), isNull);
        }
        await AppLanguage.instance.load();
        expect(AppLanguage.instance.value.languageCode, 'en');
      }
    }
  });
}
