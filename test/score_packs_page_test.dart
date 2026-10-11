import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/services/score_pack_store.dart';
import 'package:sdahymnal/models/hymn_sheet_music.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/score_packs.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
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
}

void main() {
  final full =
      jsonDecode(File('assets/sheet_music/catalog.json').readAsStringSync());
  final page = full['books']['sda-en-1985']['hymns']['1'][0];
  final catalog = jsonEncode({
    'schemaVersion': 1,
    'books': {
      'sda-en-1985': {
        'hymns': {
          '1': [page]
        }
      }
    }
  });
  FilePackBundle bundle(bool bundled) {
    final metadata = jsonDecode(
        File('assets/sheet_music/downloads.json').readAsStringSync());
    metadata['catalogSha256'] = sha256.convert(utf8.encode(catalog)).toString();
    metadata['books'] = [
      {
        'bookId': 'sda-en-1985',
        'displayName': 'English · 1985',
        'hymnCount': 1,
        'pageCount': 1,
        'bytes': page['bytes'],
        'bundled': bundled
      }
    ];
    return FilePackBundle({
      'assets/sheet_music/catalog.json':
          Uint8List.fromList(utf8.encode(catalog)),
      'assets/sheet_music/downloads.json':
          Uint8List.fromList(utf8.encode(jsonEncode(metadata))),
    });
  }

  for (final locale in ['en', 'es', 'pt', 'ru']) {
    for (final classic in [false, true]) {
      testWidgets('score download and remove fit $locale classic=$classic',
          (tester) async {
        final directory = (await tester
            .runAsync(() => Directory.systemTemp.createTemp('score-ui-')))!;
        addTearDown(() => directory.delete(recursive: true));
        var requests = 0;
        final store =
            ScorePackStore(directory, download: (_, image, cancellation) async {
          requests++;
          cancellation?.check();
          return File(image.asset).readAsBytes();
        });
        if (locale == 'en') {
          final previous = HymnSheetMusicCatalog.fromJson(jsonEncode({
            'schemaVersion': 1,
            'books': {
              'sda-en-1985': {
                'hymns': {'4': full['books']['sda-en-1985']['hymns']['4']}
              }
            }
          }));
          await tester.runAsync(() => store.install(ScorePackDownload(
              'sda-en-1985',
              previous,
              Uri.parse(
                  'https://raw.githubusercontent.com/frazras/sda_hymnal/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/'))));
          requests = 0;
        }
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHymnalTheme(HymnalTokens.dark, classic: classic),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!),
          home: DefaultAssetBundle(
              bundle: bundle(false), child: ScorePacksPage(store: store)),
        ));
        await settleIo(tester);
        final download = find.byType(FilledButton);
        await tester.ensureVisible(download);
        await tester.pumpAndSettle();
        expect(requests, 0);
        if (locale == 'en') {
          expect(find.text('Update'), findsOneWidget);
        }
        await tester.tap(download);
        await settleIo(tester);
        expect(requests, 1);
        expect(
            await tester.runAsync(() => store.load('sda-en-1985')), isNotNull);
        final remove = find.byType(TextButton);
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        await settleIo(tester);
        expect(await tester.runAsync(() => store.load('sda-en-1985')), isNull);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final cancel in [false, true]) {
    testWidgets('failed or cancelled score download can retry cancel=$cancel',
        (tester) async {
      final directory = (await tester
          .runAsync(() => Directory.systemTemp.createTemp('score-retry-')))!;
      addTearDown(() => directory.delete(recursive: true));
      final store = ScorePackStore(directory, download: (_, __, token) async {
        if (cancel) {
          await token!.whenCancelled;
          token.check();
        }
        throw const FormatException('Rejected score');
      });
      await tester.pumpWidget(MaterialApp(
          home: DefaultAssetBundle(
              bundle: bundle(false), child: ScorePacksPage(store: store))));
      await settleIo(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      if (cancel) {
        await tester.tap(find.text('Cancel'));
      }
      await settleIo(tester);
      expect(await tester.runAsync(() => store.load('sda-en-1985')), isNull);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('included collection performs no redundant download',
      (tester) async {
    final directory = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('score-included-')))!;
    addTearDown(() => directory.delete(recursive: true));
    final store = ScorePackStore(directory,
        download: (_, __, ___) async =>
            throw StateError('No request expected'));
    await tester.pumpWidget(MaterialApp(
        home: DefaultAssetBundle(
            bundle: bundle(true), child: ScorePacksPage(store: store))));
    await settleIo(tester);
    expect(find.text('Included in the app'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
