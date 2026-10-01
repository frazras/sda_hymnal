import 'dart:io';
import 'dart:convert';

import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/ui/additional_readings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn_occasion.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymn_occasions.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/hymnlist.dart';

void main() {
  final hymns =
      HymnApi.allHymnsFromJson(File('assets/hymns.json').readAsStringSync());

  final readings = AdditionalReadingCatalog.fromJson(
      jsonDecode(File('assets/additional_readings.json').readAsStringSync()));

  test('every occasion resolves unique valid hymns and readings', () {
    expect(hymnOccasions.map((o) => o.id).toSet().length, hymnOccasions.length);
    for (final occasion in hymnOccasions) {
      for (final version in ['new', 'old']) {
        final numbers =
            version == 'new' ? occasion.newNumbers : occasion.oldNumbers;
        if (version == 'new') {
          expect([...numbers, ...occasion.newReadingNumbers], isNotEmpty,
              reason: occasion.id);
        }
        expect(numbers.toSet().length, numbers.length, reason: occasion.id);
        final matches = occasion.hymnsFor(hymns, version);
        expect(matches.map((h) => h.number), numbers,
            reason: '${occasion.id} $version');
        expect(
            matches
                .every((h) => h.version == version && h.body.trim().isNotEmpty),
            isTrue);
      }
    }
  });

  test('merge preserves every existing topic, ID and hymn membership', () {
    for (final original in curatedHymnOccasions) {
      final merged = hymnOccasions.singleWhere((o) => o.id == original.id);
      expect(merged.newNumbers, containsAll(original.newNumbers));
      expect(merged.oldNumbers, containsAll(original.oldNumbers));
    }
    expect(hymnOccasions.expand((o) => o.newNumbers).toSet(),
        containsAll(List.generate(695, (i) => i + 1)));
  });

  test('all photographed topic memberships survive the merge', () {
    for (final line in File('tool/data/topical_index/new_hymnal.tsv')
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('#'))) {
      final fields = line.split('|');
      final topic = hymnOccasions.singleWhere((o) => o.title == fields[0]);
      final songs =
          fields[1].split(' ').where((n) => n.isNotEmpty).map(int.parse);
      final refs =
          fields[2].split(' ').where((n) => n.isNotEmpty).map(int.parse);
      expect(topic.newNumbers, containsAll(songs), reason: topic.title);
      expect(topic.newReadingNumbers, containsAll(refs), reason: topic.title);
      expect(topic.readingsFor(readings, 'new').map((r) => r.number),
          topic.newReadingNumbers,
          reason: topic.title);
      expect(topic.newReadingNumbers.toSet().length,
          topic.newReadingNumbers.length);
      expect(topic.readingsFor(readings, 'old'), isEmpty);
    }
    final stewardship =
        hymnOccasions.singleWhere((o) => o.title == 'Stewardship');
    expect(stewardship.readingsFor(readings, 'new').map((r) => r.title),
        contains('Generosity'));
  });

  testWidgets('reading-only topic opens reading and filters by edition',
      (tester) async {
    final topic = hymnOccasions.singleWhere((o) => o.title == 'Christian Life');
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: OccasionHymnsPage(
          occasion: topic, hymns: hymns, readingCatalog: readings),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Blessed is the Man'), findsOneWidget);
    expect(find.text('No selections are available in this hymnal yet.'),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('occasion-reading-new-784')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AdditionalReadingPage>(find.byType(AdditionalReadingPage))
            .reading
            .number,
        784);
    expect(
        tester
            .widget<AdditionalReadingPage>(find.byType(AdditionalReadingPage))
            .categoryTitle,
        topic.title);
    expect(find.byKey(const ValueKey('reading-category-indicator')),
        findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old Hymnal'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('occasion-reading-new-784')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renamed topics remain searchable by their previous names',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: HymnOccasionsPage(hymns: hymns),
    ));
    await tester.enterText(find.byType(TextField), 'Prayer meetings');
    await tester.pumpAndSettle();
    expect(find.text('Meditation and Prayer'), findsOneWidget);
    expect(find.text('Communion'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Bible');
    await tester.pumpAndSettle();
    expect(find.text('Holy Scriptures'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tithe');
    await tester.pumpAndSettle();
    expect(find.text('Stewardship'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unmatched query');
    await tester.pumpAndSettle();
    expect(find.text('No matching topics.'), findsOneWidget);
  });

  test('missing numbers never resolve to a different hymn or edition', () {
    final communion = hymnOccasions.first;
    final partial = hymns
        .where((h) => h.version == 'old' || h.number == 403)
        .toList()
        .reversed
        .toList();
    expect(communion.hymnsFor(partial, 'new').map((h) => h.number), [403]);
    expect(communion.hymnsFor([], 'old'), isEmpty);
  });

  for (final classic in [false, true]) {
    testWidgets(
        'Search opens occasions and correct edition reader (classic=$classic)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await KeepScreenOn.instance.set(false);
      MusicPlayerVisible.instance.value = false;
      final tokens = classic ? HymnalTokens.classic(false) : HymnalTokens.light;
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(tokens, classic: classic),
        home: Scaffold(
            body: HymnList(
          hymns: hymns,
          hymnsNew: hymns.where((h) => h.version == 'new').toList(),
          hymnsOld: hymns.where((h) => h.version == 'old').toList(),
        )),
      ));
      await tester.tap(find.text('Hymns by occasion'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Communion'));
      await tester.pumpAndSettle();
      expect(find.text('An Upper Room'), findsOneWidget);
      await tester.tap(find.text('Old Hymnal'));
      await tester.pumpAndSettle();
      expect(find.text('An Upper Room'), findsNothing);
      expect(find.text('Bread of the World'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('occasion-old-476')));
      await tester.pumpAndSettle();
      final reader = tester.widget<HymnPage>(find.byType(HymnPage));
      expect(reader.hymn.number, 476);
      expect(reader.hymn.version, 'old');
      expect(reader.hymns.every((h) => h.version == 'old'), isTrue);
      final category = hymnOccasions.singleWhere((o) => o.title == 'Communion');
      expect(reader.hymns.map((h) => h.number).toSet(),
          category.oldNumbers.toSet());
      expect(reader.categoryTitle, 'Communion');
      final start = reader.hymns.indexWhere((h) => h.number == 476);
      Future<void> swipe(double dx, int expectedIndex) async {
        await tester.drag(
            find.byKey(const ValueKey('hymn-lyrics-scroll')), Offset(dx, 0));
        await tester.pumpAndSettle();
        final current = tester.widget<HymnPage>(find.byType(HymnPage));
        expect(current.hymn, reader.hymns[expectedIndex]);
        expect(current.categoryTitle, 'Communion');
        expect(
            find.text(
                'Category: Communion · ${expectedIndex + 1} of ${reader.hymns.length}'),
            findsOneWidget);
      }

      // Walk the complete category, including wraparound, then reverse.
      for (var step = 1; step <= reader.hymns.length; step++) {
        await swipe(-150, (start + step) % reader.hymns.length);
      }
      await swipe(150, (start - 1) % reader.hymns.length);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('occasion-old-476')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets('occasion list accommodates large text on a narrow dark screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.dark),
      builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!),
      home: OccasionHymnsPage(occasion: hymnOccasions.first, hymns: hymns),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Communion'), findsOneWidget);
  });
}
