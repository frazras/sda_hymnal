import 'dart:convert';
import 'dart:io';
import 'package:sdahymnal/l10n/app_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/additional_readings.dart';
import 'package:sdahymnal/ui/report_error.dart';
import 'package:sdahymnal/ui/hymn_page_turn.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/hymnlist.dart';

void main() {
  final catalog = AdditionalReadingCatalog.fromJson(
    jsonDecode(File('assets/additional_readings.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  testWidgets('category readings preview the full page and wrap both ways',
      (tester) async {
    final category = catalog.categories.first;
    final group =
        catalog.readings.where((r) => r.category == category).toList();
    expect(group.length, greaterThan(1));
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: AdditionalReadingsPage(catalog: catalog),
    ));
    await tester.tap(find.widgetWithText(ChoiceChip, category));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${group.first.number}  ${group.first.title}'));
    await tester.pumpAndSettle();
    expect(find.text('Category: $category · 1 of ${group.length}'),
        findsOneWidget);
    expect(find.byType(HymnPageTurn), findsOneWidget);
    final gesture = await tester.startGesture(const Offset(400, 300));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    final preview = find.byKey(const ValueKey('reading-turn-preview'));
    expect(preview, findsOneWidget);
    expect(find.descendant(of: preview, matching: find.byType(AppBar)),
        findsOneWidget);
    expect(
        find.descendant(of: preview, matching: find.text('Start auto-scroll')),
        findsOneWidget);
    expect(
        find.descendant(
            of: preview,
            matching: find.text('Category: $category · 2 of ${group.length}')),
        findsOneWidget);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reading-turn-preview')), findsNothing);
    expect(find.text('Category: $category · 1 of ${group.length}'),
        findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('additional-reading-scroll')),
        const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(
        find.text('Category: $category · ${group.length} of ${group.length}'),
        findsOneWidget);
    expect(
        tester
            .widget<AdditionalReadingPage>(find.byType(AdditionalReadingPage))
            .reading
            .id,
        group.last.id);
    await tester.drag(find.byKey(const ValueKey('additional-reading-scroll')),
        const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AdditionalReadingPage>(find.byType(AdditionalReadingPage))
            .reading
            .id,
        group.first.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading menu opens a report for the selected reading',
      (tester) async {
    final reading = catalog.readings.last;
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: AdditionalReadingPage(reading: reading),
    ));
    await tester.tap(find.byTooltip('Reading options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report Errors'));
    await tester.pumpAndSettle();
    final page = tester.widget<ReportErrorPage>(find.byType(ReportErrorPage));
    expect(page.subject.kind, 'reading');
    expect(page.subject.itemId, reading.id);
    expect(page.subject.title, reading.title);
    expect(page.subject.number, 920);
  });

  test('catalog covers the complete additional-reading number range', () {
    expect(catalog.readings, hasLength(225));
    expect(catalog.readings.first.number, 696);
    expect(catalog.readings.last.number, 920);
    expect(
      catalog.readings.map((reading) => reading.number),
      orderedEquals(List.generate(225, (index) => 696 + index)),
    );
  });

  testWidgets('keypad identifies and opens readings, then swipes between them',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: Scaffold(
        body: Buttons(
          hymnsOld: const [],
          hymnsNew: const [],
          additionalReadings: catalog,
        ),
      ),
    ));

    final occasions = find.text('Hymns by occasion');
    final readingsLink = find.text('Additional readings');
    expect(occasions, findsOneWidget);
    expect(readingsLink, findsOneWidget);
    expect(tester.getCenter(occasions).dy, tester.getCenter(readingsLink).dy);

    await tester.tap(find.text('6'));
    await tester.tap(find.text('9'));
    await tester.tap(find.text('6'));
    await tester.pump();

    final first = catalog.readings.first;
    expect(find.text(tester.element(find.byType(Buttons)).appText.reading),
        findsOneWidget);
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(first.category), findsOneWidget);

    await tester.tap(find.text(first.title));
    await tester.pumpAndSettle();
    expect(find.byType(AdditionalReadingPage), findsOneWidget);
    expect(find.text(first.category.toUpperCase()), findsOneWidget);
    expect(find.text('Scripture: ${first.scriptureReference}'), findsOneWidget);
    expect(find.text('LEADER'), findsNothing);
    expect(find.text('CONGREGATION'), findsNothing);

    final plain = tester.widget<Text>(find.text(first.segments[0].text));
    final response = tester.widget<Text>(find.text(first.segments[1].text));
    expect(plain.style?.fontWeight, FontWeight.w400);
    expect(plain.style?.fontStyle, FontStyle.normal);
    expect(response.style?.fontWeight, FontWeight.w700);
    expect(response.style?.fontStyle, FontStyle.italic);

    await tester.drag(
      find.byKey(const ValueKey('additional-reading-scroll')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('697  ${catalog.readings[1].title}'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search keeps hymn and reading browse links on one row',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: Scaffold(
        body: HymnList(
          hymns: const [],
          hymnsOld: const [],
          hymnsNew: const [],
          additionalReadings: catalog,
        ),
      ),
    ));

    final occasions = find.text('Hymns by occasion');
    final readingsLink = find.text('Additional readings');
    expect(occasions, findsOneWidget);
    expect(readingsLink, findsOneWidget);
    expect(tester.getCenter(occasions).dy, tester.getCenter(readingsLink).dy);
    expect(tester.takeException(), isNull);
  });
}
