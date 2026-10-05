import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_sheet_music.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymn_sheet_music.dart';

class _ScoreAssets extends CachingAssetBundle {
  bool failCatalog = false;

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (failCatalog) return Future.error(StateError('Unreadable catalog'));
    return SynchronousFuture(File(key).readAsStringSync());
  }

  @override
  Future<ByteData> load(String key) =>
      SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()));
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
}
