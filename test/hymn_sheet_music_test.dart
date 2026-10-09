import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_sheet_music.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymn_sheet_music.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';

class _ScoreAssets extends CachingAssetBundle {
  bool failCatalog = false;

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (failCatalog) return Future.error(StateError('Unreadable catalog'));
    return SynchronousFuture(File(key).readAsStringSync());
  }

  @override
  Future<ByteData> load(String key) => File(key).existsSync()
      ? SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()))
      : rootBundle.load(key);
}

void main() {
  final source = File('assets/sheet_music/catalog.json').readAsStringSync();
  final catalog = HymnSheetMusicCatalog.fromJson(source);

  test('every New Hymnal number has real ordered offline pages', () {
    var total = 0;
    for (var number = 1; number <= 695; number++) {
      final pages = catalog.forHymn('new', number);
      expect(pages, isNotEmpty, reason: 'New $number');
      total += pages.length;
      for (var index = 0; index < pages.length; index++) {
        final suffix = index == 0 ? '' : '_$index';
        expect(pages[index].asset,
            endsWith('${number.toString().padLeft(3, '0')}$suffix.png'));
        expect(File(pages[index].asset).existsSync(), isTrue);
      }
    }
    expect(total, 723);
    expect(catalog.forHymn('new', 663), hasLength(6));
  });

  test('old, unknown editions, and missing numbers cannot borrow a score', () {
    expect(catalog.forHymn('old', 1), isEmpty);
    expect(catalog.forHymn('sda-es-1962', 1), isEmpty);
    expect(catalog.forHymn('sda-pt-1996', 1), isEmpty);
    expect(catalog.forHymn('sda-ru-1997', 244), isEmpty);
    expect(catalog.forHymn('new', 696), isEmpty);
    expect(catalog.forHymn('sda-en-1985', 1), catalog.forHymn('new', 1));
  });

  test('Spanish and Russian scores retain their own edition and coverage', () {
    for (var number = 1; number <= 614; number++) {
      final pages = catalog.forHymn('sda-es-2009', number);
      expect(pages.length, 1);
      expect(pages.single.asset, contains('/es_2009/piano_sheet_es_'));
      expect(File(pages.single.asset).existsSync(), isTrue);
    }
    var russianPages = 0;
    for (var number = 1; number <= 385; number++) {
      final pages = catalog.forHymn('sda-ru-1997', number);
      if (number == 244) {
        expect(pages, isEmpty);
        continue;
      }
      expect(pages, isNotEmpty);
      russianPages += pages.length;
      for (final page in pages) {
        expect(page.asset, contains('/ru_1997/piano_sheet_ru_'));
        expect(File(page.asset).existsSync(), isTrue);
      }
    }
    expect(russianPages, 506);
    expect(catalog.forHymn('sda-ru-1997', 2), hasLength(2));
    expect(catalog.forHymn('sda-es-2009', 388).single.asset,
        isNot(catalog.forHymn('new', 388).single.asset));
  });

  test('unsupported schemas and unsafe asset paths are rejected', () {
    final data = jsonDecode(source) as Map<String, dynamic>;
    data['schemaVersion'] = 2;
    expect(() => HymnSheetMusicCatalog.fromJson(jsonEncode(data)),
        throwsFormatException);
    data['schemaVersion'] = 1;
    data['books']['sda-en-1985']['hymns']['1'][0]['asset'] = '../score.png';
    expect(() => HymnSheetMusicCatalog.fromJson(jsonEncode(data)),
        throwsFormatException);
  });

  test('all published pages match trusted size, checksum and PNG dimensions',
      () {
    var count = 0;
    for (final book in catalog.books.values) {
      for (final pages in book.values) {
        for (final page in pages) {
          page.validate(File(page.asset).readAsBytesSync());
          count++;
        }
      }
    }
    expect(count, 1843);
    final page = catalog.forHymn('new', 1).single;
    final bytes = File(page.asset).readAsBytesSync();
    final changed = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 1;
    expect(() => page.validate(changed), throwsFormatException);
    expect(() => page.validate(Uint8List.sublistView(bytes, 1)),
        throwsFormatException);
    final dimensions = HymnScorePage(page.asset, page.width + 1, page.height,
        bytes: page.bytes, checksum: page.checksum);
    expect(() => dimensions.validate(bytes), throwsFormatException);
    final invalid = Uint8List(33);
    final fake = HymnScorePage(page.asset, 1, 1,
        bytes: invalid.length, checksum: sha256.convert(invalid).toString());
    expect(() => fake.validate(invalid), throwsFormatException);
  });

  test(
      'download catalog rejects ambiguous references and invalid integrity metadata',
      () {
    for (final change in <void Function(Map<String, dynamic>)>[
      (d) => d['books']['sda-en-1985']['hymns']['1'].clear(),
      (d) => d['books']['sda-en-1985']['hymns']['01'] =
          d['books']['sda-en-1985']['hymns']['1'],
      (d) => d['books']['sda-en-1985']['hymns']['1'][0]['bytes'] = 0,
      (d) => d['books']['sda-en-1985']['hymns']['1'][0]['sha256'] = 'invalid',
      (d) => d['books']['sda-en-1985']['hymns']['1'][0]['width'] = 999999,
      (d) => d['books']['sda-es-2009']['hymns']['1'] =
          d['books']['sda-en-1985']['hymns']['1'],
      (d) => d['books']['sda-en-1985']['hymns']['2'] =
          d['books']['sda-en-1985']['hymns']['1'],
      (d) => d['books'].clear(),
    ]) {
      final data = jsonDecode(source) as Map<String, dynamic>;
      change(data);
      expect(() => HymnSheetMusicCatalog.fromJson(jsonEncode(data)),
          throwsFormatException);
    }
  });

  Hymn hymn(int number, {String version = 'new'}) =>
      Hymn(number: number, title: 'Score test', body: '', version: version);

  for (final classic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('score pages and zoom work in classic=$classic dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var lyricsRequested = false;
        await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(dark ? HymnalTokens.dark : HymnalTokens.light,
              classic: classic),
          home: DefaultAssetBundle(
            bundle: _ScoreAssets(),
            child: Scaffold(
              body: HymnSheetMusic(
                hymn: hymn(4),
                onLyrics: () => lyricsRequested = true,
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('1 of 2'), findsOneWidget);
        expect(
            tester
                .widget<IconButton>(find.byWidgetPredicate((w) =>
                    w is IconButton && w.tooltip == 'Previous score page'))
                .onPressed,
            isNull);
        final transform = tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!;
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
        expect(transform.value.getMaxScaleOnAxis(), greaterThan(1));
        await tester.tap(find.byTooltip('Next score page'));
        await tester.pumpAndSettle();
        expect(find.text('2 of 2'), findsOneWidget);
        expect(transform.value.getMaxScaleOnAxis(), 1);
        expect(
            tester
                .widget<IconButton>(find.byWidgetPredicate(
                    (w) => w is IconButton && w.tooltip == 'Next score page'))
                .onPressed,
            isNull);
        expect(
            find.byKey(const ValueKey(
                'assets/sheet_music/en_1985/piano_sheet_en_004_1.png')),
            findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('score-show-lyrics')));
        expect(lyricsRequested, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('language scores use the existing viewer and reset between books',
      (tester) async {
    Widget app(String version, int number) => MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light),
          home: DefaultAssetBundle(
            bundle: _ScoreAssets(),
            child: Scaffold(
                body: HymnSheetMusic(
                    hymn: hymn(number, version: version), onLyrics: () {})),
          ),
        );
    await tester.pumpWidget(app('sda-es-2009', 388));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey(
            'assets/sheet_music/es_2009/piano_sheet_es_388.png')),
        findsOneWidget);
    await tester.pumpWidget(app('sda-ru-1997', 2));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next score page'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey(
            'assets/sheet_music/ru_1997/piano_sheet_ru_002_1.png')),
        findsOneWidget);
    await tester.pumpWidget(app('sda-ru-1997', 244));
    await tester.pumpAndSettle();
    expect(find.text('Sheet music is not available for this hymn yet.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing scores stay readable and catalog errors can retry',
      (tester) async {
    final bundle = _ScoreAssets()..failCatalog = true;
    Widget app(Hymn current) => MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light),
          home: DefaultAssetBundle(
            bundle: bundle,
            child:
                Scaffold(body: HymnSheetMusic(hymn: current, onLyrics: () {})),
          ),
        );
    await tester.pumpWidget(app(hymn(4)));
    await tester.pumpAndSettle();
    expect(find.text('Sheet music could not be loaded.'), findsOneWidget);
    bundle.failCatalog = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Next score page'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(hymn(1)));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1'), findsOneWidget);
    await tester.pumpWidget(app(hymn(1, version: 'old')));
    await tester.pumpAndSettle();
    expect(find.text('Sheet music is not available for this hymn yet.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('localized score controls fit and turn real pages',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        var lyricsOpened = false;
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildHymnalTheme(HymnalTokens.dark, classic: classic),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!),
          home: DefaultAssetBundle(
              bundle: _ScoreAssets(),
              child: Scaffold(
                body: HymnSheetMusic(
                  hymn: Hymn(
                      number: 663,
                      version: 'new',
                      title: 'Source hymn',
                      body: ''),
                  onLyrics: () => lyricsOpened = true,
                ),
              )),
        ));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(HymnSheetMusic));
        final text = context.appText;
        expect(find.text(text.pageOfTotal(1, 6)), findsOneWidget);
        expect(find.text(text.scorePageError), findsNothing);
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        await tester.tap(find.byTooltip(text.nextScorePage));
        await tester.pumpAndSettle();
        expect(find.text(text.pageOfTotal(2, 6)), findsOneWidget);
        await tester.tap(find.byTooltip(text.zoomIn));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(text.fitScore));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('score-show-lyrics')));
        expect(lyricsOpened, isTrue);
        expect(tester.takeException(), isNull,
            reason: '${locale.languageCode} classic=$classic');
      }
    }
  });
}
