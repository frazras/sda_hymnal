import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/services/language_pack_store.dart';
import 'package:sdahymnal/services/installed_language_packs.dart';
import 'package:sdahymnal/ui/language_packs.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

void main() {
  final bytes =
      File('resources/hymnals/sda-ny-khristu-mu-nyimbo.json').readAsBytesSync();
  for (final cancel in [false, true]) {
    testWidgets('failed or cancelled download remains retryable cancel=$cancel',
        (tester) async {
      final directory = await tester
          .runAsync(() => Directory.systemTemp.createTemp('pack-ui-failure-'));
      addTearDown(() => directory!.delete(recursive: true));
      final store = LanguagePackStore(directory!, download: (_) async => bytes);
      var changes = 0;
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
            home: DefaultAssetBundle(
                bundle: FilePackBundle(),
                child: LanguagePacksPage(
                  store: store,
                  onChanged: () async {
                    changes++;
                  },
                  fetch: (_, {cancellation, onProgress}) async {
                    if (cancel) {
                      await cancellation!.whenCancelled;
                      cancellation.check();
                    }
                    throw const FormatException('Rejected object');
                  },
                ))));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      final download = find.byType(FilledButton);
      await tester.scrollUntilVisible(download, 300);
      await tester.ensureVisible(download);
      await tester.pumpAndSettle();
      await tester.tap(download);
      await tester.pump();
      if (cancel) {
        await tester.ensureVisible(find.text('Cancel'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Cancel'));
      }
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(changes, 0);
      expect(
          await tester.runAsync(() => store.load('sda-ny-khristu-mu-nyimbo')),
          isNull);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final locale in ['en', 'es', 'pt', 'ru']) {
    testWidgets('optional text download and removal refresh books in $locale',
        (tester) async {
      final directory = await tester
          .runAsync(() => Directory.systemTemp.createTemp('pack-ui-'));
      addTearDown(() async => directory!.delete(recursive: true));
      final store = LanguagePackStore(directory!, download: (_) async => bytes);
      if (locale == 'en') {
        final old = jsonDecode(utf8.decode(bytes));
        old['items'][0]['title'] = 'Previous text';
        final previous = Uint8List.fromList(utf8.encode(jsonEncode(old)));
        final descriptor = LanguagePackDownload(
          bookId: 'sda-ny-khristu-mu-nyimbo',
          url: Uri.parse('https://example.com/previous.json'),
          bytes: previous.length,
          checksum: sha256.convert(previous).toString(),
          hymnCount: 350,
          topicCount: 0,
        );
        await tester.runAsync(
            () => store.install(descriptor, fetch: (_) async => previous));
      }
      var changes = 0;
      var bookCount = 6;
      var requests = 0;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: DefaultAssetBundle(
              bundle: FilePackBundle(),
              child: LanguagePacksPage(
                store: store,
                onChanged: () async {
                  changes++;
                  bookCount = (await loadInstalledLanguagePacks(
                          FilePackBundle(),
                          store: store))
                      .length;
                },
                fetch: (_, {cancellation, onProgress}) async {
                  requests++;
                  cancellation?.check();
                  onProgress?.call(bytes.length, bytes.length);
                  return Uint8List.fromList(bytes);
                },
              )),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      final download = find.byType(FilledButton);
      await tester.scrollUntilVisible(download, 300);
      await tester.ensureVisible(download);
      await tester.pumpAndSettle();
      expect(download,
          findsOneWidget); // Bundled copies never download redundantly.
      expect(requests, 0);
      if (locale == 'en') {
        expect(find.text('Update'), findsOneWidget);
      }
      await tester.runAsync(() async {
        await tester.tap(download);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(changes, 1);
      expect(bookCount, 7);
      expect(
          await tester.runAsync(() => store.load('sda-ny-khristu-mu-nyimbo')),
          isNotNull);
      final remove = find.byType(TextButton).last;
      await tester.ensureVisible(remove);
      await tester.runAsync(() async {
        await tester.tap(remove);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();
      expect(changes, 2);
      expect(bookCount, 6);
      expect(
          await tester.runAsync(() => store.load('sda-ny-khristu-mu-nyimbo')),
          isNull);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
