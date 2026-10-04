import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/hymnal_browser.dart';
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
        expect(find.text('Sheet music'), findsNothing);
        expect(audioCalls.where((m) => m.startsWith('setSource')), isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
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
          home:
              DefaultAssetBundle(bundle: FilePackBundle(), child: const Tabs()),
        ));
    await shell();
    // The English number entry deliberately keeps a blinking caret active.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('hymnal-selector')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Português · 1996').last);
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('selectedHymnal'),
        'sda-pt-1996');
    expect(find.text('Ó Deus de Amor'), findsOneWidget);
    await tester.tap(find.text('Search').last);
    await tester.pumpAndSettle();
    expect(find.text('Title, lyrics or number'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await shell();
    await tester.pumpAndSettle();
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
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await (await SharedPreferences.getInstance())
          .setString('selectedHymnal', 'sda-es-2009');
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(
            classic ? HymnalTokens.classic(false) : HymnalTokens.light,
            classic: classic),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!),
        home: DefaultAssetBundle(bundle: FilePackBundle(), child: const Tabs()),
      ));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.enterText(find.byKey(const ValueKey('book-query')), '388');
      await tester.pump();
      expect(find.byKey(const ValueKey('book-hymn-388')), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
