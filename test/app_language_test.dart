import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/services/app_language.dart';

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
}
