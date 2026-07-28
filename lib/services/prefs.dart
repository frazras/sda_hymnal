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

/// MIDI instrument theme (SharedPreferences key 'midiTheme', default
/// 'classic'). Value is a theme id from [themes]; 'classic' keeps each hymn
/// file's own instruments, every other theme forces one GM program.
class InstrumentTheme extends ValueNotifier<String> {
  InstrumentTheme._() : super('classic');
  static final InstrumentTheme instance = InstrumentTheme._();

  /// (id, label, GM program); a null program means the theme is not a simple
  /// single-instrument remap: 'classic' leaves the file as-is, 'gospel' maps
  /// channels individually (bass line -> electric bass, voices -> Rhodes).
  static const List<(String, String, int?)> themes = [
    ('classic', 'Classic', null),
    ('gospel', 'Modern Gospel', null),
    ('organ', 'Cathedral Organ', 19),
    ('strings', 'Strings', 49),
    ('choir', 'Choir', 52),
    ('musicbox', 'Music Box', 10),
  ];

  (String, String, int?) get _theme =>
      themes.firstWhere((e) => e.$1 == value, orElse: () => themes.first);

  /// Display label of the current theme ('Classic', 'Grand Piano', …).
  String get label => _theme.$2;

  /// GM program forced onto playback; null for 'classic' (file as-is) and
  /// 'gospel' (per-channel mapping built at render time).
  int? get program => _theme.$3;

  /// Whether playback needs a rewritten render (everything except Classic).
  bool get transforms => value != 'classic';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString('midiTheme') ?? 'classic';
  }

  Future<void> set(String id) async {
    value = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('midiTheme', id);
  }
}

/// Chord-tabs toggle (SharedPreferences key 'chordTabs', default false —
/// opt-in): when on, the hymn page shows the live chord strip and the chord
/// chart sheet for musicians playing along.
class ChordTabs extends ValueNotifier<bool> {
  ChordTabs._() : super(false);
  static final ChordTabs instance = ChordTabs._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool('chordTabs') ?? false;
  }

  Future<void> set(bool on) async {
    value = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chordTabs', on);
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
