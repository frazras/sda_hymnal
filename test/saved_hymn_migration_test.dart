import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/saved_hymn_store.dart';
import 'package:sdahymnal/ui/saved_hymn_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const legacyFavorites = '[{"n":388,"v":"new"},{"n":653,"v":"old"},'
      '{"n":388,"v":"old"}]';
  const legacyLists = '[{"id":"sabbath","name":"Sabbath worship",'
      '"hymns":[{"n":653,"v":"old"},{"n":388,"v":"new"}]},'
      '{"id":"choir","name":"Choir","hymns":[{"n":388,"v":"new"}]}]';
  const legacyRecents = '[{"n":653,"v":"old"},{"n":388,"v":"new"}]';
  final hymn = Hymn(number: 15, title: 'Song', body: 'Verse', version: 'new');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Favorites.instance.load();
    await Recents.instance.load();
  });

  test('migrates twice, retaining order, memberships, settings and originals',
      () async {
    SharedPreferences.setMockInitialValues({
      'hymnalFavorites': legacyFavorites,
      'hymnalFavoriteSublists': legacyLists,
      'hymnalRecents': legacyRecents,
      'theme': 'dark',
      'autoplay': true,
      'fontSize': 24.0,
    });
    final prefs = await SharedPreferences.getInstance();
    await Favorites.instance.load();
    await Recents.instance.load();
    final migratedFavorites = prefs.getString(SavedHymnStore.favoritesKey);
    final migratedRecents = prefs.getString(SavedHymnStore.recentsKey);
    for (var i = 0; i < 2; i++) {
      await Favorites.instance.load();
      await Recents.instance.load();
      expect(Favorites.instance.value,
          [(n: 388, v: 'new'), (n: 653, v: 'old'), (n: 388, v: 'old')]);
      expect(Favorites.instance.sublists.value.map((l) => l.id),
          ['sabbath', 'choir']);
      expect(Favorites.instance.sublists.value.first.hymns,
          [(n: 653, v: 'old'), (n: 388, v: 'new')]);
      expect(
          Favorites.instance.sublists.value.last.hymns, [(n: 388, v: 'new')]);
      expect(Recents.instance.value, [(n: 653, v: 'old'), (n: 388, v: 'new')]);
      expect(prefs.getString(SavedHymnStore.favoritesKey), migratedFavorites);
      expect(prefs.getString(SavedHymnStore.recentsKey), migratedRecents);
    }
    final data = jsonDecode(migratedFavorites!) as Map<String, dynamic>;
    expect(data['items'][0],
        {'bookId': 'sda-en-1985', 'itemId': '388', 'kind': 'hymn'});
    await Favorites.instance.toggle(hymn);
    await Recents.instance.push(hymn);
    await Favorites.instance.load();
    expect(Favorites.instance.value.first, (n: 15, v: 'new'));
    expect(prefs.getString('hymnalFavorites'), legacyFavorites);
    expect(prefs.getString('hymnalFavoriteSublists'), legacyLists);
    expect(prefs.getString('hymnalRecents'), legacyRecents);
    expect(prefs.getString('theme'), 'dark');
    expect(prefs.getBool('autoplay'), isTrue);
    expect(prefs.getDouble('fontSize'), 24);
  });

  test('foreign and temporarily unavailable book references survive edits',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await SavedHymnStore.saveFavorites(
        prefs,
        const SavedFavoriteCollection([
          (n: 388, v: 'sda-es-2009'),
          (n: 388, v: 'new'),
        ], []));
    await Favorites.instance.load();
    await Favorites.instance.toggle(hymn);
    await Favorites.instance.load();
    expect(Favorites.instance.value, [
      (n: 15, v: 'new'),
      (n: 388, v: 'sda-es-2009'),
      (n: 388, v: 'new'),
    ]);
  });

  for (final key in ['hymnalFavorites', 'hymnalFavoriteSublists']) {
    test('malformed $key is retained and cannot be overwritten', () async {
      SharedPreferences.setMockInitialValues({
        'hymnalFavorites': legacyFavorites,
        'hymnalFavoriteSublists': legacyLists,
        key: '{broken',
      });
      final prefs = await SharedPreferences.getInstance();
      await Favorites.instance.load();
      expect(Favorites.instance.storageError.value, isTrue);
      await Favorites.instance.toggle(hymn);
      await Favorites.instance.createSublist('New list');
      expect(prefs.getString(key), '{broken');
      expect(prefs.containsKey(SavedHymnStore.favoritesKey), isFalse);
    });
  }

  test('unsupported version is protected instead of restoring stale legacy',
      () async {
    const future = '{"schemaVersion":99,"items":[]}';
    SharedPreferences.setMockInitialValues({
      'hymnalFavorites': legacyFavorites,
      SavedHymnStore.favoritesKey: future,
      SavedHymnStore.recentsKey: future,
    });
    await Favorites.instance.load();
    await Recents.instance.load();
    expect(Favorites.instance.storageError.value, isTrue);
    expect(Recents.instance.storageError.value, isTrue);
    await Favorites.instance.toggle(hymn);
    await Recents.instance.push(hymn);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SavedHymnStore.favoritesKey), future);
    expect(prefs.getString(SavedHymnStore.recentsKey), future);
  });

  test('rapid recent changes persist in order and stay capped at six',
      () async {
    await Future.wait([
      for (var n = 1; n <= 8; n++)
        Recents.instance
            .push(Hymn(number: n, title: 'Song', body: 'Verse', version: 'new'))
    ]);
    await Recents.instance.load();
    expect(Recents.instance.value.map((e) => e.n), [8, 7, 6, 5, 4, 3]);
    await Recents.instance
        .push(Hymn(number: 5, title: 'Song', body: 'Verse', version: 'old'));
    await Recents.instance.load();
    expect(Recents.instance.value.take(5), [
      (n: 5, v: 'old'),
      (n: 8, v: 'new'),
      (n: 7, v: 'new'),
      (n: 6, v: 'new'),
      (n: 5, v: 'new'),
    ]);
  });

  test('a bad row cannot partially migrate a collection', () async {
    SharedPreferences.setMockInitialValues({
      'hymnalFavorites': '[{"n":388,"v":"new"},{"n":"broken","v":"old"}]',
      'hymnalRecents': '[{"n":388,"v":"new"},{"n":0,"v":"old"}]',
    });
    await Favorites.instance.load();
    await Recents.instance.load();
    final prefs = await SharedPreferences.getInstance();
    expect(Favorites.instance.storageError.value, isTrue);
    expect(Recents.instance.storageError.value, isTrue);
    expect(prefs.containsKey(SavedHymnStore.favoritesKey), isFalse);
    expect(prefs.containsKey(SavedHymnStore.recentsKey), isFalse);
  });

  for (final throwsError in [false, true]) {
    test('failed storage write protects originals, throws=$throwsError',
        () async {
      SharedPreferences.setMockInitialValues({});
      final platform = _FailingStore(throwsError, {
        'flutter.hymnalFavorites': legacyFavorites,
        'flutter.hymnalFavoriteSublists': legacyLists,
        'flutter.hymnalRecents': legacyRecents,
      });
      SharedPreferencesStorePlatform.instance = platform;
      await Favorites.instance.load();
      await Recents.instance.load();
      expect(Favorites.instance.storageError.value, isTrue);
      expect(Recents.instance.storageError.value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(SavedHymnStore.favoritesKey), isFalse);
      expect(prefs.containsKey(SavedHymnStore.recentsKey), isFalse);
      expect(prefs.getString('hymnalFavorites'), legacyFavorites);
      platform.failWrites = false;
      await Favorites.instance.load();
      await Recents.instance.load();
      expect(Favorites.instance.storageError.value, isFalse);
      expect(Favorites.instance.value.first, (n: 388, v: 'new'));
      expect(Recents.instance.value.first, (n: 653, v: 'old'));
      expect(prefs.containsKey(SavedHymnStore.favoritesKey), isTrue);
    });
  }

  testWidgets('migration errors are visible and retry resumes safely',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SavedHymnStore.favoritesKey, '{bad');
    await Favorites.instance.load();
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: SavedHymnNotice())));
    expect(find.textContaining('Changes are paused'), findsOneWidget);
    // Simulate repair/restoration, then exercise the actual retry action.
    await prefs.setString(SavedHymnStore.favoritesKey,
        '{"schemaVersion":2,"items":[],"lists":[]}');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsNothing);
    await Favorites.instance.toggle(hymn);
    expect(Favorites.instance.contains(15, 'new'), isTrue);
  });
}

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore(this.throwsError, Map<String, Object> data)
      : super.withData(data);
  final bool throwsError;
  bool failWrites = true;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (failWrites) {
      if (throwsError) throw StateError('Simulated disk failure');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
