import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/ui/hymn_auto_scroll.dart';
import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/hymnal_browser.dart';
import 'package:sdahymnal/ui/alphabetical_hymns.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/tabs.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final russian = HymnalPack.fromJson(
      File('assets/hymnals/sda-ru-1997.json').readAsStringSync());
  final spanish = HymnalPack.fromJson(
      File('assets/hymnals/sda-es-2009.json').readAsStringSync());
  final audioCalls = <String>[];
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      ReleaseNotesService.seenVersionsKey: <String>[appReleaseVersion],
    });
    await Favorites.instance.load();
    await Recents.instance.load();
    await KeepScreenOn.instance.set(false);
    MusicPlayerVisible.instance.value = true;
    AutoScroll.instance.value = false;
    audioCalls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(channel), (_) async => null);
    }
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      audioCalls.add(call.method);
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'];
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      return null;
    });
  });

  for (final classic in [false, true]) {
    testWidgets('updated text keeps the shared Spanish keypad classic=$classic',
        (tester) async {
      final source = jsonDecode(
          File('assets/hymnals/sda-es-2009.json').readAsStringSync());
      source['items'][0]['title'] = 'Título revisado';
      final updated = HymnalPack.fromJson(jsonEncode(source));
      final old = HymnalPack.fromJson(
          File('assets/hymnals/sda-es-1962.json').readAsStringSync());
      await (await SharedPreferences.getInstance())
          .setString('selectedHymnal', 'spanish');
      await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
          home: DefaultAssetBundle(
              bundle: FilePackBundle(),
              child: Tabs(packLoader: (_) async => [updated, old]))));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('1').last);
      await tester.pump();
      expect(find.byKey(const ValueKey('book-query')), findsNothing);
      expect(find.textContaining('Título revisado'), findsWidgets);
    });
  }

  testWidgets(
      'alphabetical reader preserves exact edition and displayed book order',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('sdahymnal/collation');
    messenger.setMockMethodCallHandler(channel, (_) async => [2, 0, 1]);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final hymns = [
      Hymn(
          number: 3,
          title: 'Beta',
          body: 'Verse',
          version: 'sda-es-2009',
          languageTag: 'es'),
      Hymn(
          number: 1,
          title: 'Gamma',
          body: 'Verse',
          version: 'sda-es-1962',
          languageTag: 'es'),
      Hymn(
          number: 2,
          title: 'Alpha',
          body: 'Verse',
          version: 'sda-es-2009',
          languageTag: 'es'),
    ];
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: AlphabeticalHymns(hymns: hymns)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();
    final reader = tester.widget<HymnPage>(find.byType(HymnPage));
    expect(reader.hymn, same(hymns[2]));
    expect(reader.hymns, [hymns[2], hymns[0]]);
    expect(reader.hymns.every((h) => h.version == 'sda-es-2009'), isTrue);
  });

  for (final classic in [false, true]) {
    testWidgets(
        'Spanish search matches corazon while keyboard is open classic=$classic',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ReleaseNotesService.seenVersionsKey: <String>[appReleaseVersion],
        'selectedHymnal': 'spanish',
      });
      await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
          home: DefaultAssetBundle(
              bundle: FilePackBundle(),
              child: Tabs(packLoader: loadHymnalPacks))));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Search').last);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(find.byType(TextField).first, 'corazon');
      await tester.pumpAndSettle();
      expect(find.textContaining('Corazones siempre alegres'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'corazón');
      await tester.pumpAndSettle();
      expect(find.textContaining('Corazones siempre alegres'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('foreign reader starts silent auto-scroll from its menu',
      (tester) async {
    final hymn = Hymn(
        number: 1,
        title: 'Lectura',
        version: 'sda-es-2009',
        bookTitle: 'Español 2009',
        languageTag: 'es',
        body: List.filled(100, 'Una línea del himno para leer.').join('<br>'));
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: HymnPage(hymn: hymn, hymns: [hymn])));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hymn-scroll-speed-menu-item')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('hymn-scroll-toggle-sheet-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
    final scroll = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(HymnAutoScroll), matching: find.byType(Scrollable))
        .first);
    expect(scroll.position.pixels, greaterThan(0));
    expect(audioCalls.where((m) => m.startsWith('setSource')), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final classic in [false, true]) {
    testWidgets('Spanish keeps paired number-pad results classic=$classic',
        (tester) async {
      if (!classic) {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      await (await SharedPreferences.getInstance())
          .setString('selectedHymnal', 'sda-es-1962');
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(
            classic ? HymnalTokens.classic(true) : HymnalTokens.dark,
            classic: classic),
        home: DefaultAssetBundle(
            bundle: FilePackBundle(), child: Tabs(packLoader: loadHymnalPacks)),
      ));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('book-query')), findsNothing);
      expect(
          tester
              .widget<DropdownButton<String>>(
                  find.byKey(const ValueKey('hymnal-selector')))
              .value,
          'spanish');
      for (final digit in ['3', '8', '8']) {
        await tester.tap(find.text(digit).last);
        await tester.pump();
      }
      if (classic) {
        await tester.ensureVisible(find.text('Antiguo»'));
        await tester.tap(find.text('Antiguo»'));
      } else {
        expect(
            find.byKey(const ValueKey('number-preview-new')), findsOneWidget);
        expect(
            tester.getRect(find.text('388').first).bottom,
            lessThanOrEqualTo(tester
                .getRect(find.byKey(const ValueKey('number-preview-new')))
                .top));
        await tester.tap(find.byKey(const ValueKey('number-preview-old')));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.version,
          'sda-es-1962');
      expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.number, 388);
      await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('hymn-scroll-speed-menu-item')),
          findsOneWidget);
      expect(find.text('Copy or share lyrics'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    for (final dark in [false, true]) {
      testWidgets(
          'Russian reader, paging and favorites classic=$classic dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tokens = classic
            ? HymnalTokens.classic(dark)
            : dark
                ? HymnalTokens.dark
                : HymnalTokens.light;
        await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(tokens, classic: classic),
          home: Scaffold(body: HymnalBrowser(pack: russian, numbersOnly: true)),
        ));
        await tester.enterText(find.byKey(const ValueKey('book-query')), '385');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('book-hymn-385')));
        await tester.pumpAndSettle();
        final reader = tester.widget<HymnPage>(find.byType(HymnPage));
        expect(reader.hymn.version, 'sda-ru-1997');
        expect(reader.hymn.title, russian.hymns.last.title);
        expect(find.byKey(const ValueKey('hymn-music-player')), findsNothing);
        expect(
            tester
                .widget<IconButton>(find.byKey(const ValueKey('reader-next')))
                .onPressed,
            isNull);
        await tester.tap(find.byKey(const ValueKey('reader-previous')));
        await tester.pumpAndSettle();
        expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.number, 384);
        await tester
            .tap(find.byKey(const ValueKey('hymn-favorite-header-button')));
        await tester.pumpAndSettle();
        expect(Favorites.instance.contains(384, 'sda-ru-1997'), isTrue);
        await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
        await tester.pumpAndSettle();
        expect(find.text('Musical style'), findsNothing);
        expect(find.text('Choir practice'), findsNothing);
        expect(find.text('Sheet music'), findsOneWidget);
        expect(audioCalls.where((m) => m.startsWith('setSource')), isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }

  for (final book in [
    'sda-fr-hymnes-et-louanges',
    'sda-sw-nyimbo-za-kristo',
    'sda-ny-khristu-mu-nyimbo',
  ]) {
    final optionalPack = book == 'sda-ny-khristu-mu-nyimbo'
        ? HymnalPack.fromJson(
            File('resources/hymnals/$book.json').readAsStringSync())
        : null;
    for (final classic in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
            'expanded book keeps keypad and reader $book classic=$classic dark=$dark',
            (tester) async {
          SharedPreferences.setMockInitialValues({
            ReleaseNotesService.seenVersionsKey: <String>[appReleaseVersion],
            'selectedHymnal': book,
          });
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
              theme: buildHymnalTheme(
                  dark ? HymnalTokens.dark : HymnalTokens.light,
                  classic: classic),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!),
              home: DefaultAssetBundle(
                  bundle: FilePackBundle(),
                  child: Tabs(
                      packLoader: optionalPack == null
                          ? loadHymnalPacks
                          : (_) async => [optionalPack]))));
          for (var i = 0; i < 16; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(find.byKey(ValueKey('numbers-$book')), findsOneWidget);
          expect(find.text('Topics'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Search').last);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, '1');
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('book-hymn-1')));
          await tester.pumpAndSettle();
          final reader = tester.widget<HymnPage>(find.byType(HymnPage));
          expect(reader.hymn.ref.bookId, book);
          expect(reader.hymn.number, 1);
          expect(reader.hymns.every((h) => h.ref.bookId == book), isTrue);
          expect(find.byKey(const ValueKey('hymn-music-player')), findsNothing);
          expect(audioCalls.where((m) => m.startsWith('setSource')), isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }

  testWidgets('topics provide only their ordered book queue', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: Scaffold(body: HymnalBrowser(pack: spanish))));
    await tester.tap(find.text('Topics'));
    await tester.pumpAndSettle();
    final topic = spanish.topics.first;
    await tester.tap(find.text(topic.group));
    await tester.pumpAndSettle();
    await tester.tap(find.text(topic.title));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(ValueKey('book-hymn-${topic.hymns.first.number}')));
    await tester.pumpAndSettle();
    final reader = tester.widget<HymnPage>(find.byType(HymnPage));
    expect(reader.categoryTitle, topic.title);
    expect(reader.hymns, topic.hymns);
    await tester.tap(find.byKey(const ValueKey('reader-previous')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<HymnPage>(find.byType(HymnPage)).hymn, topic.hymns.last);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('all-language search keeps results and navigation book-specific',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: Scaffold(
          body: AllHymnalsSearch(hymns: [...spanish.hymns, ...russian.hymns])),
    ));
    await tester.enterText(
        find.byKey(const ValueKey('all-books-query')), '388');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('all-book-sda-es-2009-388')));
    await tester.pumpAndSettle();
    final reader = tester.widget<HymnPage>(find.byType(HymnPage));
    expect(reader.hymn.version, 'sda-es-2009');
    expect(reader.hymns, spanish.hymns);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('imported favorites resolve from their own book', (tester) async {
    await Favorites.instance.toggle(spanish.hymns.first);
    await Favorites.instance.toggle(russian.hymns.first);
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: Scaffold(
          body: FavoritesTab(
              hymnsNew: const [],
              hymnsOld: const [],
              additionalHymns: [...spanish.hymns, ...russian.hymns])),
    ));
    await tester.tap(find.text(russian.hymns.first.title));
    await tester.pumpAndSettle();
    final reader = tester.widget<HymnPage>(find.byType(HymnPage));
    expect(reader.hymn.version, 'sda-ru-1997');
    expect(reader.hymns.map((h) => h.version), ['sda-ru-1997', 'sda-es-2009']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('selected book persists across shell rebuild and search tab',
      (tester) async {
    Future<void> shell() => tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light),
          home: DefaultAssetBundle(
              bundle: FilePackBundle(),
              child: Tabs(packLoader: loadHymnalPacks)),
        ));
    await shell();
    // The English number entry deliberately keeps a blinking caret active.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('hymnal-selector')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Português · 1996').last);
    await tester.pump(const Duration(milliseconds: 600));
    expect((await SharedPreferences.getInstance()).getString('selectedHymnal'),
        'sda-pt-1996');
    await tester.tap(find.text('1').last);
    await tester.pump();
    expect(find.text('Ó Deus de Amor'), findsOneWidget);
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.text('Title, lyrics or number'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await shell();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('hymnal-selector')))
            .value,
        'sda-pt-1996');
    expect(tester.takeException(), isNull);
  });

  for (final classic in [false, true]) {
    testWidgets(
        'small screen keeps foreign search usable above keyboard classic=$classic',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      // The keyboard opens only on Search, never on the number pad.
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await (await SharedPreferences.getInstance())
          .setString('selectedHymnal', 'sda-pt-1996');
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(
            classic ? HymnalTokens.classic(false) : HymnalTokens.light,
            classic: classic),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: DefaultAssetBundle(
            bundle: FilePackBundle(), child: Tabs(packLoader: loadHymnalPacks)),
      ));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Search').last);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('book-query')), '388');
      await tester.pump();
      expect(find.byKey(const ValueKey('book-hymn-388')), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
