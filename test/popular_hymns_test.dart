import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/popular_hymns.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/trends.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

void main() {
  final hymns = List.generate(
      25,
      (i) => Hymn(
          number: i + 1,
          version: 'new',
          title: 'Song ${i + 1}',
          body: 'Lyrics'));
  final report = jsonEncode({
    'schema': 2,
    'minimum_contributors': 20,
    'generated': '2026-09-28',
    'periods': {
      for (final period in ['1', '4', '8'])
        period: {
          'start': '2026-09-01',
          'end': '2026-09-28',
          'top_songs': [
            for (final h in hymns)
              {
                'hymn': h.number,
                'edition': h.version,
                'title': h.title,
                'count': 100 - h.number,
              }
          ],
          'repeat_songs': [],
          'favorites': [],
          'times': [],
          'weekdays': [],
          'countries': [],
        }
    },
  });

  test('samples five unique hymns only from top 20 and varies with randomness',
      () {
    final snapshot = TrendsSnapshot.parse(report);
    final samples = [
      for (var seed = 0; seed < 10; seed++)
        popularHymns(hymns, snapshot: snapshot, random: Random(seed))
    ];
    for (final selection in samples) {
      expect(selection.length, 5);
      expect(selection.toSet().length, 5);
      expect(selection.every((h) => h.number <= 20), isTrue);
    }
    expect(samples.map((s) => s.map((h) => h.number).join(',')).toSet().length,
        greaterThan(1));
    expect(popularHymns([]), isEmpty);
  });

  testWidgets('two-line hymn selections stay visible above the keypad',
      (tester) async {
    tester.view.physicalSize = const Size(375, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      TrendsRepository.cacheKey: report,
      TrendsRepository.fetchedKey: DateTime.now().millisecondsSinceEpoch,
    });
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: Scaffold(
          body: SizedBox(
              height: 530,
              child: Buttons(
                hymnsNew: [
                  Hymn(
                      number: 1,
                      version: 'new',
                      title: 'A long hymn title\nwith a second line',
                      body: 'Lyrics')
                ],
                hymnsOld: [
                  Hymn(
                      number: 1,
                      version: 'old',
                      title: 'Another long title\nwith a second line',
                      body: 'Lyrics')
                ],
              ))),
    ));
    await tester.pump();
    await tester.tap(find.text('1').last);
    await tester.pump();
    final popular = find.byKey(const ValueKey('popular-hymns'));
    expect(
        tester.getBottomLeft(popular).dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('number-preview-new')))
            .dy));
    final keypadTop = tester.getTopLeft(find.text('2')).dy;
    for (final version in ['new', 'old']) {
      final preview = find.byKey(ValueKey('number-preview-$version'));
      expect(preview.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(preview).dy, lessThan(keypadTop));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final classic in [false, true]) {
    testWidgets(
        'popular chips survive typing and refresh on tab and route return, classic=$classic',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        TrendsRepository.cacheKey: report,
        TrendsRepository.fetchedKey: DateTime.now().millisecondsSinceEpoch,
      });
      await KeepScreenOn.instance.set(false);
      MusicPlayerVisible.instance.value = false;
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(
            classic ? HymnalTokens.classic(false) : HymnalTokens.light,
            classic: classic),
        home: Scaffold(
            body: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, value, __) =>
              Buttons(active: value, hymnsNew: hymns, hymnsOld: const []),
        )),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      List<Key?> chips() => tester
          .widgetList<Pressable>(find.descendant(
              of: find.byKey(const ValueKey('popular-hymns')),
              matching: find.byType(Pressable)))
          .map((w) => w.key)
          .toList();
      final initial = chips();
      expect(initial.length, 5);
      await tester.tap(classic
          ? find.widgetWithText(OutlinedButton, '2')
          : find.text('2').last);
      await tester.pump();
      expect(chips(), initial);
      active.value = false;
      await tester.pump();
      active.value = true;
      await tester.pump();
      final revisited = chips();
      expect(revisited, isNot(initial));
      final chip = find.byKey(revisited.first!);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final reader = tester.widget<HymnPage>(find.byType(HymnPage));
      expect(revisited.first, ValueKey('popular-new-${reader.hymn.number}'));
      // Replacing the reader must still refresh when returning to Numbers.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushReplacement(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Next page'))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(chips(), isNot(revisited));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
