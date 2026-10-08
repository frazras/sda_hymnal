import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/reading_history.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recents = Recents.instance;
  Hymn hymn(int number, [String version = 'new']) =>
      Hymn(number: number, title: 'Hymn $number', body: '', version: version);
  setUp(() async {
    SharedPreferences.setMockInitialValues({'selectedHymnal': 'sda-es-2009'});
    await recents.load();
    await Favorites.instance.load();
  });

  test('history keeps more than six entries with distinct book identities',
      () async {
    for (var n = 1; n <= 20; n++) {
      await recents.push(hymn(n));
    }
    await recents.push(hymn(1, 'sda-es-2009'));
    await recents.push(hymn(1));
    await recents.load();
    expect(recents.value.length, 21);
    expect(recents.value.take(2), [(n: 1, v: 'new'), (n: 1, v: 'sda-es-2009')]);
    expect(recents.value.last, (n: 2, v: 'new'));
  });

  test('clear serializes with visits and preserves favorites and settings',
      () async {
    await Favorites.instance.toggle(hymn(3));
    final a = recents.push(hymn(1));
    final b = recents.clear();
    final c = recents.push(hymn(2));
    await Future.wait([a, b, c]);
    await recents.load();
    expect(recents.value, [(n: 2, v: 'new')]);
    await recents.clear();
    await recents.load();
    expect(recents.value, isEmpty);
    await Favorites.instance.load();
    expect(Favorites.instance.contains(3, 'new'), isTrue);
    expect((await SharedPreferences.getInstance()).getString('selectedHymnal'),
        'sda-es-2009');
  });

  test('history cannot clear storage while saved data is protected', () async {
    await recents.push(hymn(1));
    recents.storageError.value = true;
    await recents.clear();
    expect(recents.value, [(n: 1, v: 'new')]);
    recents.storageError.value = false;
    await recents.load();
    expect(recents.value, [(n: 1, v: 'new')]);
  });

  testWidgets('history labels books and requires confirmation to clear',
      (tester) async {
    final newHymn = hymn(388);
    final oldHymn = hymn(388, 'old');
    await recents.push(newHymn);
    await recents.push(oldHymn);
    await recents.push(hymn(1, 'sda-fr-2020'));
    await tester.pumpWidget(
        MaterialApp(home: ReadingHistoryPage(hymns: [newHymn, oldHymn])));
    expect(find.text('New Hymnal'), findsOneWidget);
    expect(find.text('Old Hymnal'), findsOneWidget);
    expect(find.text('Hymn unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(recents.value.length, 3);
    await tester.tap(find.byTooltip('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No recently opened hymns'), findsOneWidget);
    await recents.load();
    expect(recents.value, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('localized history clearing preserves saved Spanish memberships',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final song = Hymn(
        number: 230,
        version: 'sda-es-2009',
        title: 'Abre tu corazón',
        body: 'Letra',
        bookTitle: 'Himnario Adventista');
    final saved = Favorites.instance;
    await saved.toggle(song);
    await saved.createSublist('Mis himnos');
    final id = saved.sublists.value.single.id;
    await saved.setSublistHymn(id, song, true);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await recents.push(song);
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
            home: ReadingHistoryPage(hymns: [song]),
          ));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(ReadingHistoryPage));
          final text = context.appText;
          expect(find.text(song.title), findsOneWidget);
          await tester.tap(find.byTooltip(text.clearHistory));
          await tester.pumpAndSettle();
          expect(find.text(text.clearHistoryQuestion), findsOneWidget);
          await tester.tap(find.text(text.cancel));
          await tester.pumpAndSettle();
          expect(recents.value, [(n: 230, v: 'sda-es-2009')]);
          await tester.tap(find.byTooltip(text.clearHistory));
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.clear));
          await tester.pumpAndSettle();
          expect(find.text(text.noRecentHymns), findsOneWidget);
          await recents.load();
          await saved.load();
          expect(recents.value, isEmpty);
          expect(saved.contains(230, 'sda-es-2009'), isTrue);
          expect(saved.sublists.value.single.id, id);
          expect(
              saved.sublists.value.single.hymns, [(n: 230, v: 'sda-es-2009')]);
          expect(
              (await SharedPreferences.getInstance())
                  .getString('selectedHymnal'),
              'sda-es-2009');
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
  });
}
