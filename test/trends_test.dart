import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/services/trends.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/statistics.dart';
import 'package:sdahymnal/ui/settings.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';

String fixture({bool empty = false}) => jsonEncode({
      'schema': 2,
      'minimum_contributors': 20,
      'generated': '2026-09-08T00:00:00Z',
      'periods': {
        for (final period in ['1', '4', '8'])
          period: {
            'start': '2026-08-10',
            'end': '2026-09-06',
            'top_songs': empty
                ? []
                : [
                    {
                      'hymn': 1,
                      'edition': 'new',
                      'title': 'Praise to the Lord',
                      'count': int.parse(period) * 100
                    }
                  ],
            'repeat_songs': [],
            'favorites': [],
            'times': empty
                ? []
                : [
                    {'label': 'morning', 'count': 250}
                  ],
            'weekdays': empty
                ? []
                : [
                    {'label': '6', 'count': 200}
                  ],
            'countries': empty
                ? []
                : [
                    {
                      'country': 'JM',
                      'songs': [
                        {
                          'hymn': 2,
                          'edition': 'old',
                          'title': 'A country favorite',
                          'count': 50
                        }
                      ]
                    }
                  ],
          }
      }
    });

class Repository extends TrendsRepository {
  int requests = 0;
  bool offline = false;
  @override
  Future<String> fetch() async {
    requests++;
    if (offline) throw const SocketException('offline');
    return fixture();
  }
}

void main() {
  test('native statistic preserves book identity and label', () {
    final song = SongStatistic.parse({
      'hymn': 303,
      'edition': '',
      'book_id': 'sda-es-2009',
      'book_label': 'Español · 2009',
      'title': 'Sublime Gracia',
      'count': 20
    });
    expect(song.bookId, 'sda-es-2009');
    expect(song.bookLabel, 'Español · 2009');
    expect(
        SongStatistic.parse(
                {'hymn': 1, 'edition': 'new', 'title': 'Praise', 'count': 20})
            .bookId,
        'sda-en-1985');
    expect(
        () => SongStatistic.parse({
              'hymn': 303,
              'edition': 'new',
              'book_id': 'sda-es-2009',
              'title': 'Sublime Gracia',
              'count': 20
            }),
        throwsFormatException);
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Settings statistics receives every installed hymnal',
      (tester) async {
    final pack = HymnalPack.fromJson(
        File('assets/hymnals/sda-es-2009.json').readAsStringSync());
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: Scaffold(body: Settings(hymns: const [], historyHymns: pack.hymns)),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Community statistics'), 300,
        scrollable: find.descendant(
            of: find.byKey(const ValueKey('settings-list')),
            matching: find.byType(Scrollable)));
    await tester.tap(find.text('Community statistics'));
    await tester.pumpAndSettle();
    expect(tester.widget<StatisticsPage>(find.byType(StatisticsPage)).hymns,
        pack.hymns);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'native statistics opens the selected book instead of an English alias',
      (tester) async {
    final pack = HymnalPack.fromJson(
        File('assets/hymnals/sda-ru-1997.json').readAsStringSync());
    await KeepScreenOn.instance.set(false);
    final data = jsonDecode(fixture()) as Map<String, dynamic>;
    for (final period in (data['periods'] as Map).values) {
      period['top_songs'] = [
        {
          'hymn': 1,
          'edition': '',
          'book_id': pack.edition.id,
          'book_label': pack.hymns.first.bookLabel,
          'title': 'Native ranking result',
          'count': 30
        }
      ];
    }
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: StatisticsPage(
          hymns: pack.hymns,
          load: (_) async => TrendsSnapshot.parse(jsonEncode(data))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Native ranking result'));
    await tester.pumpAndSettle();
    final hymn = tester.widget<HymnPage>(find.byType(HymnPage)).hymn;
    expect(hymn.ref.bookId, 'sda-ru-1997');
    expect(hymn.number, 1);
    expect(hymn.title, pack.hymns.first.title);
    expect(tester.takeException(), isNull);
  });

  test('cache avoids repeated requests and provides offline fallback',
      () async {
    final repo = Repository();
    expect((await repo.load()).offline, isFalse);
    await repo.load();
    expect(repo.requests, 1);
    repo.offline = true;
    final cached = await repo.load(force: true);
    expect(cached.offline, isTrue);
    expect(cached.periods['4']!.songs.single.count, 400);
  });

  test('missing or corrupt cache reports failure rather than invented zeros',
      () async {
    SharedPreferences.setMockInitialValues(
        {TrendsRepository.cacheKey: 'bad json'});
    await expectLater(
        (Repository()..offline = true).load(), throwsA(isA<SocketException>()));
    expect(
        () => TrendsSnapshot.parse(
            fixture().replaceFirst('"schema":2', '"schema":3')),
        throwsFormatException);
  });

  for (final classic in [false, true]) {
    testWidgets('community page period selection and charts, classic=$classic',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
          home: StatisticsPage(
              hymns: const [],
              load: (_) async => TrendsSnapshot.parse(fixture()))));
      await tester.pumpAndSettle();
      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('New 1 · 400 opens'), findsOneWidget);
      await tester.tap(find.text('Last week'));
      await tester.pumpAndSettle();
      expect(find.text('New 1 · 100 opens'), findsOneWidget);
      final scroll = find.byKey(const ValueKey('statistics-list'));
      await tester.scrollUntilVisible(find.text('When we open the hymnal'), 300,
          scrollable:
              find.descendant(of: scroll, matching: find.byType(Scrollable)));
      expect(find.text('Morning · 6 am–12 pm · 250 opens'), findsOneWidget);
      expect(find.textContaining('Night · 12–6 am · Not enough published data'),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('Around the world'), 300,
          scrollable:
              find.descendant(of: scroll, matching: find.byType(Scrollable)));
      expect(find.text('Jamaica (JM)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text dark theme empty state and retry', (tester) async {
    bool offline = true;
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.dark),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!),
        home: StatisticsPage(
            hymns: const [],
            load: (_) async {
              if (offline) throw const SocketException('offline');
              return TrendsSnapshot.parse(fixture(empty: true), offline: true);
            })));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Try again'), 250,
        scrollable: find.descendant(
            of: find.byKey(const ValueKey('statistics-list')),
            matching: find.byType(Scrollable)));
    offline = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    await tester.drag(
        find.byKey(const ValueKey('statistics-list')), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline · Saved report'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Most-opened hymns'), 250,
        scrollable: find.descendant(
            of: find.byKey(const ValueKey('statistics-list')),
            matching: find.byType(Scrollable)));
    expect(
        find.textContaining('Community insights are growing.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
