import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

void main() {
  final hymn =
      Hymn(number: 1, version: 'new', title: 'My song', body: 'Lyrics');
  final oldHymn =
      Hymn(number: 1, version: 'old', title: 'Old song', body: 'Lyrics');
  final saved = Favorites.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await saved.load();
    await KeepScreenOn.instance.set(false);
    MusicPlayerVisible.instance.value = false;
  });

  test('legacy favorites survive and lists persist with parent membership',
      () async {
    SharedPreferences.setMockInitialValues(
        {'hymnalFavorites': '[{"n":1,"v":"new"}]'});
    await saved.load();
    expect(saved.contains(1, 'new'), isTrue);
    expect(saved.sublists.value, isEmpty);
    await saved.createSublist('My childhood songs');
    final id = saved.sublists.value.single.id;
    await saved.setSublistHymn(id, hymn, true);
    await saved.setSublistHymn(id, oldHymn, true);
    await saved.renameSublist(id, 'Childhood');
    await saved.load();
    expect(saved.value.length, 1);
    expect(saved.sublists.value.single.name, 'Childhood');
    expect(saved.sublists.value.single.hymns.length, 2);
    await saved.toggle(hymn);
    expect(saved.sublists.value.single.hymns.toSet(),
        {(n: 1, v: 'new'), (n: 1, v: 'old')});
    await saved.deleteSublist(id);
    await saved.load();
    expect(saved.contains(1, 'old'), isFalse);
    expect(saved.sublists.value, isEmpty);
  });

  test('validates names and preserves rapid checkbox changes', () async {
    expect(() => saved.createSublist(' '), throwsArgumentError);
    await saved.createSublist('Childhood');
    expect(() => saved.createSublist(' childhood '), throwsArgumentError);
    final id = saved.sublists.value.single.id;
    await Future.wait([
      saved.setSublistHymn(id, hymn, true),
      saved.setSublistHymn(id, hymn, false),
      saved.setSublistHymn(id, oldHymn, true),
    ]);
    await saved.load();
    expect(saved.sublists.value.single.hymns, [(n: 1, v: 'old')]);
    expect(saved.contains(1, 'new'), isFalse);
  });

  test('one hymn can belong to multiple sublists independently', () async {
    await saved.createSublist('Childhood');
    final first = saved.sublists.value.first.id;
    await saved.createSublist('Sabbath');
    final second = saved.sublists.value.first.id;
    await saved.setSublistHymn(first, hymn, true);
    await saved.setSublistHymn(second, hymn, true);
    await saved.setSublistHymn(first, hymn, false);
    await saved.load();
    expect(saved.sublists.value.first.hymns, [(n: 1, v: 'new')]);
    expect(saved.sublists.value.last.hymns, isEmpty);
    expect(saved.contains(1, 'new'), isFalse);
    await saved.toggle(hymn);
    await saved.toggle(hymn);
    expect(saved.sublists.value.first.hymns, [(n: 1, v: 'new')]);
    expect(saved.containsAnywhere(1, 'new'), isTrue);
  });

  for (final classic in [false, true]) {
    testWidgets(
        'favorite category swipes left to next and wraps, classic=$classic',
        (tester) async {
      final third =
          Hymn(number: 4, version: 'new', title: 'Third song', body: 'Lyrics');
      await saved.createSublist('Childhood');
      final id = saved.sublists.value.single.id;
      for (final song in [third, oldHymn, hymn]) {
        await saved.setSublistHymn(id, song, true);
      }
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(
            classic ? HymnalTokens.classic(false) : HymnalTokens.light,
            classic: classic),
        home: Scaffold(
            body: FavoritesTab(hymnsNew: [hymn, third], hymnsOld: [oldHymn])),
      ));
      await tester.pumpAndSettle();
      expect(find.text('New favorite category'), findsOneWidget);
      await tester.tap(find.text('Childhood'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My song').first);
      await tester.pumpAndSettle();
      expect(find.text('Category: Childhood · 1 of 3'), findsOneWidget);
      Future<void> swipe(double dx, Hymn expected, int position) async {
        await tester.drag(
            find.byKey(const ValueKey('hymn-lyrics-scroll')), Offset(dx, 0));
        await tester.pumpAndSettle();
        final reader = tester.widget<HymnPage>(find.byType(HymnPage));
        expect(reader.hymn, expected);
        expect(reader.hymns, [hymn, oldHymn, third]);
        expect(
            find.text('Category: Childhood · $position of 3'), findsOneWidget);
      }

      final history = List.of(Recents.instance.value);
      final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('hymn-lyrics-scroll'))));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(find.byKey(const ValueKey('hymn-turn-preview')), findsOneWidget);
      expect(find.textContaining('Old song'), findsOneWidget);
      expect(
          tester
              .widget<HymnPage>(find
                  .byWidgetPredicate((w) => w is HymnPage && !w.previewOnly))
              .hymn,
          hymn);
      expect(Recents.instance.value, history);
      int visibleArea() {
        final path = tester
            .widget<ClipPath>(find.byKey(const ValueKey('hymn-page-fold')))
            .clipper!
            .getClip(const Size(800, 600));
        var count = 0;
        for (var x = 5.0; x < 800; x += 10) {
          for (var y = 5.0; y < 600; y += 10) {
            if (path.contains(Offset(x, y))) count++;
          }
        }
        return count;
      }

      final folded = visibleArea();
      expect(folded, lessThan(4800));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump(const Duration(milliseconds: 200));
      final unfolded = visibleArea();
      expect(unfolded, greaterThan(folded));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<HymnPage>(find
                  .byWidgetPredicate((w) => w is HymnPage && !w.previewOnly))
              .hymn,
          hymn);
      expect(find.byKey(const ValueKey('hymn-turn-preview')), findsNothing);
      expect(Recents.instance.value, history);

      await swipe(-150, oldHymn, 2);
      await swipe(-150, third, 3);
      await swipe(-150, hymn, 1);
      await swipe(150, third, 3);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'create a top sublist and save using the heart, classic=$classic',
        (tester) async {
      await saved.toggle(hymn);
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(
            classic ? HymnalTokens.classic(false) : HymnalTokens.light,
            classic: classic),
        home:
            Scaffold(body: FavoritesTab(hymnsNew: [hymn], hymnsOld: [oldHymn])),
      ));
      await tester.tap(find.byKey(const ValueKey('create-favorite-sublist')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My childhood songs');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('My childhood songs')).dy,
          lessThan(tester.getTopLeft(find.text('Main favorites')).dy));
      final id = saved.sublists.value.single.id;
      await tester.tap(find.text('My song'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('hymn-favorite-header-button')));
      await tester.pumpAndSettle();
      expect(saved.contains(1, 'new'), isTrue,
          reason: 'A saved heart opens membership choices');
      expect(
          tester
              .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('favorite-parent-checkbox')))
              .value,
          isTrue);
      await tester.tap(find.byKey(ValueKey('favorite-sublist-checkbox-$id')));
      await tester.pumpAndSettle();
      expect(saved.sublists.value.single.hymns, [(n: 1, v: 'new')]);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('My childhood songs'));
      await tester.pumpAndSettle();
      expect(find.text('My song'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'heart saves immediately; choices appear only when sublists exist',
      (tester) async {
    Future<void> reader() => tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light),
          home: HymnPage(hymn: hymn, hymns: [hymn]),
        ));
    await reader();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hymn-favorite-header-button')));
    await tester.pumpAndSettle();
    expect(saved.contains(1, 'new'), isTrue);
    expect(find.byType(CheckboxListTile), findsNothing);
    await tester.tap(find.byKey(const ValueKey('hymn-favorite-header-button')));
    await tester.pumpAndSettle();
    expect(saved.contains(1, 'new'), isFalse);
    await saved.createSublist('Sabbath');
    await tester.tap(find.byKey(const ValueKey('hymn-favorite-header-button')));
    expect(saved.contains(1, 'new'), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('favorite-parent-checkbox')));
    await tester.pumpAndSettle();
    expect(saved.contains(1, 'new'), isFalse);
    await tester.tap(find.text('Sabbath'));
    await tester.pumpAndSettle();
    expect(saved.contains(1, 'new'), isFalse);
    expect(saved.sublists.value.single.hymns, [(n: 1, v: 'new')]);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('hymn-favorite-header-button')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('favorite-parent-checkbox')))
            .value,
        isFalse);
    await saved.load();
    expect(saved.contains(1, 'new'), isFalse);
    expect(saved.containsAnywhere(1, 'new'), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
