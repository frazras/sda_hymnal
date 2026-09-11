import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/additional_readings.dart';
import 'package:sdahymnal/ui/buttons.dart';
import 'package:sdahymnal/ui/hymnlist.dart';

void main() {
  final catalog = AdditionalReadingCatalog.fromJson(
    jsonDecode(File('assets/additional_readings.json').readAsStringSync())
        as Map<String, dynamic>,
  );

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
    expect(find.text('READING'), findsOneWidget);
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
