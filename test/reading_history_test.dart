import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/reading_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recents = Recents.instance;
  Hymn hymn(int number, [String version = 'new']) =>
      Hymn(number: number, title: 'Hymn $number', body: '', version: version);
  setUp(() async {
    SharedPreferences.setMockInitialValues({'selectedHymnal': 'sda-es-2009'});
    await recents.load();
    await Favorites.instance.load();
  });

  test('history keeps more than six entries with distinct book identities',
      () async {
    for (var n = 1; n <= 20; n++) {
      await recents.push(hymn(n));
    }
    await recents.push(hymn(1, 'sda-es-2009'));
    await recents.push(hymn(1));
    await recents.load();
    expect(recents.value.length, 21);
    expect(recents.value.take(2), [(n: 1, v: 'new'), (n: 1, v: 'sda-es-2009')]);
    expect(recents.value.last, (n: 2, v: 'new'));
  });

  test('clear serializes with visits and preserves favorites and settings',
      () async {
    await Favorites.instance.toggle(hymn(3));
    final a = recents.push(hymn(1));
    final b = recents.clear();
    final c = recents.push(hymn(2));
    await Future.wait([a, b, c]);
    await recents.load();
    expect(recents.value, [(n: 2, v: 'new')]);
    await recents.clear();
    await recents.load();
    expect(recents.value, isEmpty);
    await Favorites.instance.load();
    expect(Favorites.instance.contains(3, 'new'), isTrue);
    expect((await SharedPreferences.getInstance()).getString('selectedHymnal'),
        'sda-es-2009');
  });

  test('history cannot clear storage while saved data is protected', () async {
    await recents.push(hymn(1));
    recents.storageError.value = true;
    await recents.clear();
    expect(recents.value, [(n: 1, v: 'new')]);
    recents.storageError.value = false;
    await recents.load();
    expect(recents.value, [(n: 1, v: 'new')]);
  });

  testWidgets('history labels books and requires confirmation to clear',
      (tester) async {
    final newHymn = hymn(388);
    final oldHymn = hymn(388, 'old');
    await recents.push(newHymn);
    await recents.push(oldHymn);
    await recents.push(hymn(1, 'sda-fr-2020'));
    await tester.pumpWidget(
        MaterialApp(home: ReadingHistoryPage(hymns: [newHymn, oldHymn])));
    expect(find.text('New Hymnal'), findsOneWidget);
    expect(find.text('Old Hymnal'), findsOneWidget);
    expect(find.text('Hymn unavailable'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(recents.value.length, 3);
    await tester.tap(find.byTooltip('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No recently opened hymns'), findsOneWidget);
    await recents.load();
    expect(recents.value, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
