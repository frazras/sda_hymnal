import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/hymn_ref.dart';
import 'package:sdahymnal/models/service_playlist.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/services/service_playlists.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/service_playlists.dart';
import 'package:sdahymnal/ui/service_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = HymnalRepository(editions: const [], hymns: const []);
  final list =
      ServicePlaylist(id: 'service', name: 'Oración — сердце', entries: [
    for (final id in ['first', 'second'])
      ServiceEntry(id: id, ref: HymnRef(bookId: 'future-book', itemId: id)),
  ]);

  testWidgets(
      'unavailable service items retain identity and translated navigation',
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
                child: child!),
            home: ServiceReader(playlist: list, repository: repo).page(0),
          ));
          await tester.pumpAndSettle();
          final text = tester.element(find.byType(Scaffold)).appText;
          expect(find.text(text.unavailableItem), findsOneWidget);
          expect(
              find.text(text.servicePosition(list.name, 1, 2)), findsOneWidget);
          expect(find.text('future-book · first'), findsOneWidget);
          expect(find.text(text.serviceItemNotInstalled), findsOneWidget);
          expect(
              tester
                  .widget<TextButton>(
                      find.widgetWithText(TextButton, text.previousControl))
                  .onPressed,
              isNull);
          await tester.tap(find.text(text.nextControl));
          await tester.pumpAndSettle();
          expect(
              find.text(text.servicePosition(list.name, 2, 2)), findsOneWidget);
          expect(find.text('future-book · second'), findsOneWidget);
          expect(
              tester
                  .widget<TextButton>(
                      find.widgetWithText(TextButton, text.nextControl))
                  .onPressed,
              isNull);
          await tester.tap(find.text(text.previousControl));
          await tester.pumpAndSettle();
          expect(find.text('future-book · first'), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
  });

  testWidgets(
      'localized storage warning protects services and fits compact layouts',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          SharedPreferences.setMockInitialValues(
              {ServicePlaylists.storageKey: 'corrupted'});
          final store = ServicePlaylists();
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
            home: ServicePlaylistsPage(repository: repo, store: store),
          ));
          await tester.pumpAndSettle();
          final text =
              tester.element(find.byType(ServicePlaylistsPage)).appText;
          expect(find.text(text.serviceStorageFailed), findsOneWidget);
          expect(find.text(text.serviceEditingPaused), findsOneWidget);
          expect(
              tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
              isNull);
          await tester.tap(find.text(text.retryLoading));
          await tester.pumpAndSettle();
          expect(store.storageError, isTrue);
          expect(
              (await SharedPreferences.getInstance())
                  .getString(ServicePlaylists.storageKey),
              'corrupted');
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
          store.dispose();
        }
      }
    }
  });
}
