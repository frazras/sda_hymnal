import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdahymnal/main.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/classic.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/theme.dart';

class _HymnAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key == 'assets/hymns.json') {
      return SynchronousFuture(File(key).readAsStringSync());
    }
    return super.loadString(key, cache: cache);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hymns = HymnApi.allHymnsFromJson(File('assets/hymns.json').readAsStringSync());

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('sdahymnal/app_icon'),
            (_) async => null);
    SharedPreferences.setMockInitialValues({});
    await AppDesignController.instance.load();
    await ThemeController.instance.load();
    await FontSizeController.instance.load();
    await Recents.instance.load();
    await Favorites.instance.load();
    await KeepScreenOn.instance.set(false);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global/events'), (_) async => null);
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'];
        messenger.setMockMethodCallHandler(MethodChannel('xyz.luan/audioplayers/events/$id'), (_) async => null);
      }
      return null;
    });
  });

  test('Modern is the default and invalid values fall back safely', () async {
    expect(AppDesignController.instance.value, AppDesign.modern);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appDesign', 'obsolete');
    await AppDesignController.instance.load();
    expect(AppDesignController.instance.value, AppDesign.modern);
  });

  test('design persists without changing brightness, music or saved hymns', () async {
    final prefs = await SharedPreferences.getInstance();
    await ThemeController.instance.setPref('dark');
    await prefs.setString('midiTheme', 'reggae');
    await Favorites.instance.toggle(hymns.first);
    await FontSizeController.instance.set(25);
    await AppDesignController.instance.set(AppDesign.classic);
    AppDesignController.instance.value = AppDesign.modern;
    await AppDesignController.instance.load();
    expect(AppDesignController.instance.value, AppDesign.classic);
    expect(prefs.getString('theme'), 'dark');
    expect(prefs.getString('midiTheme'), 'reggae');
    expect(prefs.getDouble('fontSize'), 25);
    expect(Favorites.instance.contains(hymns.first.number, hymns.first.version), isTrue);
    await AppDesignController.instance.set(AppDesign.modern);
    expect(prefs.getString('appDesign'), 'modern');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(DefaultAssetBundle(bundle: _HymnAssets(), child: const Hymnal()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('settings switches both ways, keeps number input and search', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('5'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.text('533'), findsOneWidget);
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'cross');
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('design-classic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClassicHeader), findsOneWidget);
    expect(find.text('App design'), findsOneWidget);
    await tester.tap(find.text('Numbers'));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('classic-number-display'))).data, '533');
    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'cross');
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('design-modern')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClassicHeader), findsNothing);
    expect(find.text('App design'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Classic keypad validates bounds and opens the right edition', (tester) async {
    await AppDesignController.instance.set(AppDesign.classic);
    await pumpApp(tester);
    OutlinedButton newButton() => tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'NEW»'));
    expect(newButton().onPressed, isNull);
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(newButton().onPressed, isNull);
    for (final digit in ['7', '0', '3']) { await tester.tap(find.text(digit)); }
    await tester.pump();
    expect(newButton().onPressed, isNull);
    await tester.tap(find.text('OLD»'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.number, 703);
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.version, 'old');
    expect(find.text('Music & playback'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Classic filter cycles and retains the typed query', (tester) async {
    await AppDesignController.instance.set(AppDesign.classic);
    await pumpApp(tester);
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '533');
    await tester.pump();
    expect(find.byType(ClassicSearchRow), findsNWidgets(2));
    await tester.tap(find.text('ALL\nHymns'));
    await tester.pump();
    expect(find.text('533. On a Hill Far Away'), findsOneWidget);
    await tester.tap(find.text('OLD\nHymns'));
    await tester.pump();
    expect(find.text('533. O for a Faith'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '533');
  });

  testWidgets('Classic swipes through corrected Old 533 534 and 535 in order',
      (tester) async {
    final list = hymns.where((h) => h.version == 'old').toList();
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light, classic: true),
      home: HymnPage(hymn: hymnByNumber(list, 533)!, hymns: list),
    ));
    await tester.pump();
    for (final number in [534, 535]) {
      await tester.drag(find.byType(HymnPage), const Offset(-250, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final page = tester.widget<HymnPage>(find.byType(HymnPage));
      expect(page.hymn.number, number);
      expect(page.hymn.version, 'old');
      expect(find.byKey(const ValueKey('hymn-play-pause')), findsNothing);
    }
    expect(Recents.instance.value.first, (n: 535, v: 'old'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final dark in [false, true]) {
    testWidgets('Classic reader and music controls fit narrow ${dark ? 'dark' : 'light'} screens', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final list = hymns.where((h) => h.version == 'new').toList();
      final hymn = hymnByNumber(list, 533)!;
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(dark ? HymnalTokens.dark : HymnalTokens.light, classic: true),
        home: HymnPage(hymn: hymn, hymns: list),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('classic-reader-header')), findsOneWidget);
      expect(find.text('Music & playback'), findsOneWidget);
      await tester.tap(find.text('Music & playback'));
      await tester.pump();
      expect(find.text('Hide music controls'), findsOneWidget);
      expect(MidiPlayer.hasMidi(hymn), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
