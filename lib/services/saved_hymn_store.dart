import 'dart:convert';

import 'package:sdahymnal/models/hymn_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SavedHymn = ({int n, String v});

/// The first migration keeps the numeric English UI adapter. Persistence uses
/// explicit book/item identities, and leaves all original keys untouched.
/// Unknown schemas or unrepresentable references fail closed, never dropping
/// rows to make a partially loaded collection look valid.
class SavedHymnStore {
  static const favoritesKey = 'hymnalFavorites.v2';
  static const recentsKey = 'hymnalRecents.v2';

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved collection.');
    }
    return value;
  }

  static List<dynamic> _list(dynamic value) {
    if (value is! List) throw const FormatException('Invalid saved list.');
    return value;
  }

  static SavedHymn _legacyEntry(dynamic value) {
    final row = _map(value);
    final number = row['n'];
    final version = row['v'];
    if (number is! int ||
        number <= 0 ||
        version is! String ||
        version.trim().isEmpty) {
      throw const FormatException('Invalid saved hymn.');
    }
    return (n: number, v: legacyBookAlias(canonicalBookId(version)));
  }

  static Map<String, dynamic> encodeEntry(SavedHymn entry) =>
      HymnRef(bookId: entry.v, itemId: '${entry.n}').toJson();

  static SavedHymn _entry(dynamic value) {
    final ref = HymnRef.fromJson(_map(value));
    final number = int.tryParse(ref.itemId);
    if (ref.kind != HymnalItemKind.hymn ||
        number == null ||
        number <= 0 ||
        '$number' != ref.itemId) {
      throw const FormatException('This saved item needs a newer app.');
    }
    return (n: number, v: legacyBookAlias(ref.bookId));
  }

  static Map<String, dynamic> _envelope(String raw) {
    final data = _map(jsonDecode(raw));
    if (data['schemaVersion'] != 2) {
      throw const FormatException('This saved collection needs a newer app.');
    }
    return data;
  }

  static List<SavedHymn> _entries(dynamic values, {bool legacy = false}) => [
        for (final value in _list(values))
          legacy ? _legacyEntry(value) : _entry(value)
      ];

  static Future<List<SavedHymn>> loadRecents(SharedPreferences prefs) async {
    await prefs.reload();
    final current = prefs.getString(recentsKey);
    if (current != null) return _entries(_envelope(current)['items']);
    final entries = _entries(
        jsonDecode(prefs.getString('hymnalRecents') ?? '[]'),
        legacy: true);
    await saveRecents(prefs, entries);
    return entries;
  }

  static Future<SavedFavoriteCollection> loadFavorites(
      SharedPreferences prefs) async {
    await prefs.reload();
    final current = prefs.getString(favoritesKey);
    final legacy = current == null;
    final data = legacy
        ? {
            'items': jsonDecode(prefs.getString('hymnalFavorites') ?? '[]'),
            'lists':
                jsonDecode(prefs.getString('hymnalFavoriteSublists') ?? '[]'),
          }
        : _envelope(current);
    final entries = _entries(data['items'], legacy: legacy);
    final ids = <String>{};
    final lists = <SavedFavoriteList>[];
    for (final value in _list(data['lists'])) {
      final row = _map(value);
      final id = row['id'];
      final name = row['name'];
      if (id is! String ||
          id.isEmpty ||
          !ids.add(id) ||
          name is! String ||
          name.trim().isEmpty) {
        throw const FormatException('Invalid saved favorite category.');
      }
      lists.add(SavedFavoriteList(
          id: id,
          name: name,
          hymns: _entries(row[legacy ? 'hymns' : 'items'], legacy: legacy)));
    }
    final collection = SavedFavoriteCollection(entries, lists);
    if (legacy) await saveFavorites(prefs, collection);
    return collection;
  }

  static Future<void> saveRecents(
          SharedPreferences prefs, List<SavedHymn> entries) =>
      _write(prefs, recentsKey, {
        'schemaVersion': 2,
        'items': entries.map(encodeEntry).toList(),
      });

  static Future<void> saveFavorites(
          SharedPreferences prefs, SavedFavoriteCollection collection) =>
      _write(prefs, favoritesKey, {
        'schemaVersion': 2,
        'items': collection.hymns.map(encodeEntry).toList(),
        'lists': [
          for (final list in collection.lists)
            {
              'id': list.id,
              'name': list.name,
              'items': list.hymns.map(encodeEntry).toList(),
            }
        ],
      });

  static Future<void> _write(
      SharedPreferences prefs, String key, Map<String, dynamic> data) async {
    final encoded = jsonEncode(data);
    final bool saved;
    try {
      saved = await prefs.setString(key, encoded);
    } finally {
      // SharedPreferences updates its cache before the platform write. Even a
      // thrown write must discard that optimistic value before a retry.
      await prefs.reload();
    }
    if (!saved || prefs.getString(key) != encoded) {
      throw StateError('Could not save the hymn collection.');
    }
  }
}

class SavedFavoriteCollection {
  final List<SavedHymn> hymns;
  final List<SavedFavoriteList> lists;
  const SavedFavoriteCollection(this.hymns, this.lists);
}

class SavedFavoriteList {
  final String id;
  final String name;
  final List<SavedHymn> hymns;
  const SavedFavoriteList(
      {required this.id, required this.name, required this.hymns});
}
