import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdahymnal/models/hymn.dart';

/// App-wide theme preference: 'light' | 'dark' | 'system'
/// (SharedPreferences key 'theme', default 'light' to match the mockups).
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.light);
  static final ThemeController instance = ThemeController._();

  String _pref = 'light';
  String get pref => _pref;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    setPref(prefs.getString('theme') ?? 'light', save: false);
  }

  Future<void> setPref(String pref, {bool save = true}) async {
    _pref = pref;
    value = switch (pref) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    if (save) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', pref);
    }
  }
}

/// Lyrics font size (SharedPreferences key 'fontSize', 16–30, default 18).
/// A notifier so open screens restyle live while the slider drags.
class FontSizeController extends ValueNotifier<double> {
  FontSizeController._() : super(18.0);
  static final FontSizeController instance = FontSizeController._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getDouble('fontSize') ?? 18.0;
  }

  Future<void> set(double size) async {
    value = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', size);
  }
}

/// Recently opened hymns (SharedPreferences key 'hymnalRecents'):
/// JSON list of {n, v}, most recent first, deduped by (n,v), capped at 6.
class Recents extends ValueNotifier<List<({int n, String v})>> {
  Recents._() : super(const []);
  static final Recents instance = Recents._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString('hymnalRecents') ?? '[]') as List;
      value = [
        for (final e in raw) (n: e['n'] as int, v: e['v'] as String)
      ];
    } catch (_) {
      value = const [];
    }
  }

  Future<void> push(Hymn hymn) async {
    final entry = (n: hymn.number, v: hymn.version);
    value = [
      entry,
      ...value.where((e) => !(e.n == entry.n && e.v == entry.v)),
    ].take(6).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'hymnalRecents',
        jsonEncode([
          for (final e in value) {'n': e.n, 'v': e.v}
        ]));
  }
}

/// Favorited hymns (SharedPreferences key 'hymnalFavorites'):
/// JSON list of {n, v}, most recently added first, deduped by (n,v).
class Favorites extends ValueNotifier<List<({int n, String v})>> {
  Favorites._() : super(const []);
  static final Favorites instance = Favorites._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw =
          jsonDecode(prefs.getString('hymnalFavorites') ?? '[]') as List;
      value = [
        for (final e in raw) (n: e['n'] as int, v: e['v'] as String)
      ];
    } catch (_) {
      value = const [];
    }
  }

  bool contains(int n, String v) => value.any((e) => e.n == n && e.v == v);

  /// Adds the hymn (to the front) if absent, removes it otherwise.
  Future<void> toggle(Hymn hymn) async {
    final entry = (n: hymn.number, v: hymn.version);
    value = contains(entry.n, entry.v)
        ? value.where((e) => !(e.n == entry.n && e.v == entry.v)).toList()
        : [entry, ...value];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'hymnalFavorites',
        jsonEncode([
          for (final e in value) {'n': e.n, 'v': e.v}
        ]));
  }
}
