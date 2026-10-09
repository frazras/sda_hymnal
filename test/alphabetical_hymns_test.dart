import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/ui/alphabetical_hymns.dart';

Hymn hymn(int n, String title,
        {String language = 'es', String version = 'sda-es-2009'}) =>
    Hymn(
        number: n,
        title: title,
        body: 'Verse',
        version: version,
        languageTag: language);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sdahymnal/collation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
      'letter labels preserve Spanish ñ and Russian letters but fold Latin accents',
      () {
    expect(titleInitial(hymn(1, '¡Ñandú!')), 'Ñ');
    expect(titleInitial(hymn(1, 'Élan')), 'E');
    expect(titleInitial(hymn(1, 'Ёлка', language: 'ru')), 'Ё');
    expect(titleInitial(hymn(1, '123')), '#');
  });
  testWidgets(
      'jump lands on a lazy row in native order without changing source data',
      (tester) async {
    final hymns = [
      for (var i = 1; i <= 40; i++) hymn(i, i == 40 ? 'Zulu' : 'Alpha $i')
    ];
    messenger.setMockMethodCallHandler(
        channel, (_) async => List.generate(40, (i) => i));
    await tester.pumpWidget(MaterialApp(home: AlphabeticalHymns(hymns: hymns)));
    await tester.pumpAndSettle();
    expect(find.text('Zulu'), findsNothing);
    await tester.tap(find.text('Jump to letter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z'));
    await tester.pumpAndSettle();
    expect(find.text('Zulu'), findsOneWidget);
    expect(hymns.first.number, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unavailable bridge offers retry and keeps navigation usable',
      (tester) async {
    var fail = true;
    messenger.setMockMethodCallHandler(channel, (_) async {
      if (fail) throw PlatformException(code: 'UNAVAILABLE');
      return [0];
    });
    await tester.pumpWidget(
        MaterialApp(home: AlphabeticalHymns(hymns: [hymn(1, 'Corazón')])));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Corazón'), findsOneWidget);
  });
  testWidgets('language switch sends only that language to collation',
      (tester) async {
    final requests = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = call.arguments as Map;
      requests.add(args['language'] as String);
      expect((args['titles'] as List).length, 1);
      return [0];
    });
    await tester.pumpWidget(MaterialApp(
        home: AlphabeticalHymns(hymns: [
      hymn(1, 'Corazón'),
      hymn(2, 'Я', language: 'ru', version: 'sda-ru-2005'),
    ])));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sda-ru-2005').last);
    await tester.pumpAndSettle();
    expect(requests, ['es', 'ru']);
    expect(find.text('Я'), findsOneWidget);
    expect(find.text('Corazón'), findsNothing);
  });
}
