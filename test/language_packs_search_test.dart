import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/services/language_pack_store.dart';
import 'package:sdahymnal/ui/language_packs.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

void main() {
  Future<void> openPage(WidgetTester tester, Directory directory,
      {Locale locale = const Locale('en')}) async {
    final store = LanguagePackStore(directory,
        download: (_) async => throw const FormatException('offline'));
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultAssetBundle(
              bundle: FilePackBundle(),
              child: LanguagePacksPage(store: store, onChanged: () async {}))));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(() async {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('language-packs-search')),
            matching: find.byType(TextField)),
        query);
    await tester.pumpAndSettle();
  }

  testWidgets('language search finds books by native or English name',
      (tester) async {
    final directory = await tester
        .runAsync(() => Directory.systemTemp.createTemp('pack-search-'));
    addTearDown(() => directory!.delete(recursive: true));
    await openPage(tester, directory!);

    expect(find.byKey(const ValueKey('score-packs-link')), findsOneWidget);

    // English name, native name and accent-free spellings all find a book.
    for (final (query, id) in [
      ('swahili', 'sda-sw-nyimbo-za-kristo'),
      ('kiswa', 'sda-sw-nyimbo-za-kristo'),
      ('Chewa', 'sda-ny-khristu-mu-nyimbo'),
      ('francais', 'sda-fr-hymnes-et-louanges'),
      ('русск', 'sda-ru-1997'),
      ('zulu', 'sda-zu-ukrestu-esihlabelelweni'),
      ('Kikuyu', 'sda-ki-nyimbo-cia-agendi'),
      ('gikuyu', 'sda-ki-nyimbo-cia-agendi'),
      ('venda', 'sda-ve-ngosha-yadzingosha'),
      ('Cebuano', 'sda-ceb-cebuano-hymns'),
      ('Adventist Youth', 'sda-en-adventist-youth-songs'),
    ]) {
      await search(tester, query);
      expect(find.byKey(ValueKey('pack-$id')), findsOneWidget, reason: query);
      expect(find.byKey(const ValueKey('pack-sda-es-2009')), findsNothing,
          reason: query);
      expect(find.byKey(const ValueKey('score-packs-link')), findsNothing);
    }

    // Both Spanish editions answer to one language name.
    await search(tester, 'spanish');
    expect(find.byKey(const ValueKey('pack-sda-es-2009')), findsOneWidget);
    expect(find.byKey(const ValueKey('pack-sda-es-1962')), findsOneWidget);

    await search(tester, 'klingon');
    expect(find.byKey(const ValueKey('language-packs-empty')), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('language-packs-empty')), findsNothing);
    expect(find.byKey(const ValueKey('score-packs-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('pack-sda-ceb-cebuano-hymns')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language search hint is translated', (tester) async {
    final directory = await tester
        .runAsync(() => Directory.systemTemp.createTemp('pack-search-es-'));
    addTearDown(() => directory!.delete(recursive: true));
    await openPage(tester, directory!, locale: const Locale('es'));
    expect(find.text('Buscar idiomas'), findsOneWidget);
    await search(tester, 'portugues');
    expect(find.byKey(const ValueKey('pack-sda-pt-1996')), findsOneWidget);
    expect(find.byKey(const ValueKey('pack-sda-ru-1997')), findsNothing);
  });
}
