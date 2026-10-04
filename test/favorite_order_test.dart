import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/favorite_order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final saved = Favorites.instance;
  final songs = [
    for (final version in ['new', 'sda-es-2009', 'old'])
      Hymn(number: 388, title: version, body: 'Lyrics', version: version),
  ];
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await saved.load();
    await Recents.instance.load();
    for (final song in songs.reversed) {
      await saved.toggle(song);
    }
    await saved.createSublist('Service');
    for (final song in songs.reversed) {
      await saved.setSublistHymn(saved.sublists.value.single.id, song, true);
    }
  });

  test('reorder persists independently in main favorites and categories',
      () async {
    final original = List.of(saved.value);
    final id = saved.sublists.value.single.id;
    await saved.reorderHymns(0, 2);
    await saved.reorderHymns(2, 0, sublistId: id);
    await saved.load();
    expect(saved.value, [original[1], original[2], original[0]]);
    expect(saved.sublists.value.single.hymns,
        [original[2], original[0], original[1]]);
    expect(saved.value.toSet(), original.toSet());
    final before = List.of(saved.value);
    await saved.reorderHymns(0, 99);
    await saved.reorderHymns(0, 1, sublistId: 'deleted');
    expect(saved.value, before);
    saved.storageError.value = true;
    await saved.reorderHymns(0, 1);
    expect(saved.value, before);
    saved.storageError.value = false;
  });

  test('rapid reorders save in order and retain unresolved books', () async {
    final unknown =
        Hymn(number: 1, title: 'Unknown', body: '', version: 'sda-fr-2020');
    await saved.toggle(unknown);
    final original = List.of(saved.value);
    final first = saved.reorderHymns(0, 3);
    final second = saved.reorderHymns(0, 2);
    await Future.wait([first, second]);
    await saved.load();
    expect(saved.value, [original[2], original[3], original[1], original[0]]);
  });

  testWidgets('drag changes order and keeps edition labels visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: FavoriteOrderPage(
            resolve: (entry) => songs
                .where((h) => h.number == entry.n && h.version == entry.v)
                .firstOrNull)));
    expect(find.text('New Hymnal'), findsOneWidget);
    final first = find.byKey(const ValueKey('order-new-388'));
    final last = find.byKey(const ValueKey('order-old-388'));
    final start = tester.getCenter(
        find.descendant(of: first, matching: find.byIcon(Icons.drag_handle)));
    final finish = tester.getCenter(last) + const Offset(0, 35);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveTo(Offset(start.dx, finish.dy));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(saved.value.last.v, 'new', reason: '${saved.value}');
    await saved.load();
    expect(saved.value.last.v, 'new');
    expect(tester.takeException(), isNull);
  });
}
