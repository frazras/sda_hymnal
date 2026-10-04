import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/app_icon.dart';
import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/saved_hymn_store.dart';

/// Layout is independent of brightness and of the MIDI instrument named
/// "Classic". Existing installs keep Modern until they explicitly opt in.
enum AppDesign { modern, classic }

class AppDesignController extends ValueNotifier<AppDesign> {
  AppDesignController._() : super(AppDesign.modern);
  static final AppDesignController instance = AppDesignController._();
  final iconBusy = ValueNotifier(false);
  final iconError = ValueNotifier<String?>(null);
  Future<void>? _iconSync;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString('appDesign') == 'classic'
        ? AppDesign.classic
        : AppDesign.modern;
    iconError.value = null;
  }

  Future<void> set(AppDesign design) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appDesign', design.name);
    AppAnalytics.instance.setDesign(design.name);
    AppAnalytics.instance.event('setting_design', variant: design.name);
    value = design;
    await syncIcon();
  }

  /// Reconcile after startup/resume too: an existing Classic preference may
  /// predate alternate icons, or the OS may have refused a previous change.
  /// Serialize/coalesce requests so a late completion cannot win over the
  /// latest design. The saved layout remains usable if the launcher fails.
  Future<void> syncIcon() =>
      _iconSync ??= _updateIcon().whenComplete(() => _iconSync = null);

  Future<void> _updateIcon() async {
    iconBusy.value = true;
    iconError.value = null;
    try {
      AppDesign requested;
      do {
        requested = value;
        try {
          await AppIcon.setDesign(requested.name);
          if (requested == value) iconError.value = null;
        } catch (_) {
          AppAnalytics.instance.event('diagnostic', variant: 'icon');
          if (requested == value) {
            iconError.value =
                'The layout is saved, but the home-screen icon could not be '
                'updated. Keep the app open and try again.';
          }
        }
      } while (requested != value);
    } finally {
      iconBusy.value = false;
    }
  }
}

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
      AppAnalytics.instance.event('setting_theme', variant: pref);
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
    AppAnalytics.instance.event('setting_font',
        variant: size < 20
            ? 'small'
            : size < 25
                ? 'medium'
                : 'large');
  }
}

/// Keep-screen-on toggle (SharedPreferences key 'keepScreenOn', default true):
/// when on, the hymn reading page holds a wakelock so the phone does not lock
/// mid-verse. Only the hymn page honours it — see [ScreenWake].
class KeepScreenOn extends ValueNotifier<bool> {
  KeepScreenOn._() : super(true);
  static final KeepScreenOn instance = KeepScreenOn._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool('keepScreenOn') ?? true;
  }

  Future<void> set(bool on) async {
    value = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keepScreenOn', on);
    AppAnalytics.instance
        .event('setting_keep_awake', variant: on ? 'on' : 'off');
  }
}

/// Continue the active medium through the reader's list after a manual start.
class Autoplay extends ValueNotifier<bool> {
  Autoplay._() : super(false);
  static final instance = Autoplay._();
  Future<void> load() async {
    value =
        (await SharedPreferences.getInstance()).getBool('autoplay') ?? false;
  }

  Future<void> set(bool enabled) async {
    value = enabled;
    await (await SharedPreferences.getInstance()).setBool('autoplay', enabled);
  }
}

/// Opt-in MIDI-timed lyric scrolling, shared by both reader designs.
class AutoScroll extends ValueNotifier<bool> {
  AutoScroll._() : super(false);
  static final AutoScroll instance = AutoScroll._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool('autoScroll') ?? false;
  }

  Future<void> set(bool on) async {
    value = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoScroll', on);
    AppAnalytics.instance
        .event('setting_auto_scroll', variant: on ? 'on' : 'off');
  }
}

/// Whether the hymn-page music player is visible. This is shared by both
/// designs and every hymn (SharedPreferences key 'musicPlayerVisible').
class MusicPlayerVisible extends ValueNotifier<bool> {
  MusicPlayerVisible._() : super(true);
  static final MusicPlayerVisible instance = MusicPlayerVisible._();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool('musicPlayerVisible') ?? true;
  }

  Future<void> set(bool visible) async {
    value = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('musicPlayerVisible', visible);
    AppAnalytics.instance
        .event('setting_player', variant: visible ? 'on' : 'off');
  }
}

/// The UI keeps its numeric adapter; saved references use permanent book IDs.
class Recents extends ValueNotifier<List<({int n, String v})>> {
  Recents._() : super(const []);
  static final Recents instance = Recents._();
  final storageError = ValueNotifier<bool>(false);
  Future<void>? _pendingSave;

  Future<void> load() async {
    if (_pendingSave != null) await _pendingSave;
    final prefs = await SharedPreferences.getInstance();
    try {
      value = await SavedHymnStore.loadRecents(prefs);
      storageError.value = false;
    } catch (_) {
      // Keep the original storage and stop writes until a successful reload.
      storageError.value = true;
    }
  }

  Future<void> push(Hymn hymn) async {
    if (storageError.value) return;
    final entry = (n: hymn.number, v: hymn.version);
    value = [
      entry,
      ...value.where((e) => !(e.n == entry.n && e.v == entry.v)),
    ].take(6).toList();
    final snapshot = List.of(value);
    final previous = _pendingSave;
    Future<void> write() async {
      if (previous != null) await previous;
      if (storageError.value) return;
      try {
        await SavedHymnStore.saveRecents(
            await SharedPreferences.getInstance(), snapshot);
      } catch (_) {
        storageError.value = true;
      }
    }

    final operation = write();
    _pendingSave = operation;
    await operation;
    if (identical(_pendingSave, operation)) _pendingSave = null;
  }
}

/// MIDI instrument theme (SharedPreferences key 'midiTheme', default
/// 'classic'). Value is a theme id from [themes]; 'classic' keeps each hymn
/// file's own instruments, every other theme forces one GM program.
class InstrumentTheme extends ValueNotifier<String> {
  InstrumentTheme._() : super('classic');
  static final InstrumentTheme instance = InstrumentTheme._();

  /// (id, label, GM program); a null program means the theme is not a simple
  /// single-instrument remap: 'classic' leaves the file as-is, while
  /// 'gospel', 'jazz', 'jamaican_gospel', 'reggae' and 'calypso' generate arrangements (melody
  /// preserved, backing regenerated per style by the style arranger).
  static const List<(String, String, int?)> themes = [
    ('classic', 'Classic', null),
    ('gospel', 'Modern Gospel', null),
    ('jazz', 'Jazz', null),
    // Keep the Jamaican styles together, followed by Trinidadian calypso.
    ('reggae', 'Island Reggae', null),
    ('jamaican_gospel', 'Jamaican Gospel', null),
    ('calypso', 'Steel Pan Calypso', null),
    ('organ', 'Cathedral Organ', 19),
    ('strings', 'Strings', 49),
    ('choir', 'Choir', 91),
    ('musicbox', 'Music Box', 11),
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
    AppAnalytics.instance.event('setting_instrument', variant: id);
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
    AppAnalytics.instance.event('setting_chords', variant: on ? 'on' : 'off');
  }
}

/// Chord difficulty (SharedPreferences key 'chordLevel', default 'original'):
/// 'simple' | 'medium' | 'original' — how far detected chords are simplified
/// before the strip and chart label them.
class ChordLevelPref extends ValueNotifier<String> {
  ChordLevelPref._() : super('original');
  static final ChordLevelPref instance = ChordLevelPref._();

  /// The stored string as the chord_detect enum.
  ChordLevel get level => switch (value) {
        'simple' => ChordLevel.simple,
        'medium' => ChordLevel.medium,
        _ => ChordLevel.original,
      };

  /// Display label of the current level ('Simple' / 'Medium' / 'Original').
  String get label => switch (value) {
        'simple' => 'Simple',
        'medium' => 'Medium',
        _ => 'Original',
      };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getString('chordLevel') ?? 'original';
  }

  Future<void> set(String level) async {
    value = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chordLevel', level);
    AppAnalytics.instance.event('setting_chord_level', variant: level);
  }
}

class FavoriteSublist {
  const FavoriteSublist(
      {required this.id, required this.name, this.hymns = const []});
  final String id;
  final String name;
  final List<({int n, String v})> hymns;
}

/// Favorites and categories are saved together, with permanent book IDs.
class Favorites extends ValueNotifier<List<({int n, String v})>> {
  Favorites._() : super(const []);
  static final Favorites instance = Favorites._();
  final sublists = ValueNotifier<List<FavoriteSublist>>(const []);
  final storageError = ValueNotifier<bool>(false);
  Future<void>? _pendingSave;

  Future<void> load() async {
    if (_pendingSave != null) await _pendingSave;
    final prefs = await SharedPreferences.getInstance();
    try {
      final collection = await SavedHymnStore.loadFavorites(prefs);
      value = collection.hymns;
      sublists.value = [
        for (final list in collection.lists)
          FavoriteSublist(
            id: list.id,
            name: list.name,
            hymns: list.hymns,
          )
      ];
      storageError.value = false;
    } catch (_) {
      storageError.value = true;
    }
  }

  bool contains(int n, String v) => value.any((e) => e.n == n && e.v == v);

  bool containsAnywhere(int n, String v) =>
      contains(n, v) ||
      sublists.value.any((list) => list.hymns.contains((n: n, v: v)));

  String _validName(String name, {String? exceptId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) {
      throw ArgumentError('Use a name between 1 and 60 characters.');
    }
    if (trimmed.toLowerCase() == 'favorites' ||
        sublists.value.any((list) =>
            list.id != exceptId &&
            list.name.toLowerCase() == trimmed.toLowerCase())) {
      throw ArgumentError('Choose a different list name.');
    }
    return trimmed;
  }

  Future<void> createSublist(String name) {
    if (storageError.value) return Future.value();
    final valid = _validName(name);
    sublists.value = [
      FavoriteSublist(
          id: DateTime.now().microsecondsSinceEpoch.toString(), name: valid),
      ...sublists.value
    ];
    return _save();
  }

  Future<void> renameSublist(String id, String name) {
    if (storageError.value) return Future.value();
    final valid = _validName(name, exceptId: id);
    sublists.value = [
      for (final list in sublists.value)
        if (list.id == id)
          FavoriteSublist(id: id, name: valid, hymns: list.hymns)
        else
          list
    ];
    return _save();
  }

  Future<void> deleteSublist(String id) {
    if (storageError.value) return Future.value();
    sublists.value = sublists.value.where((list) => list.id != id).toList();
    return _save();
  }

  Future<void> setSublistHymn(String id, Hymn hymn, bool selected) {
    if (storageError.value) return Future.value();
    if (!sublists.value.any((list) => list.id == id)) return Future.value();
    final entry = (n: hymn.number, v: hymn.version);
    sublists.value = [
      for (final list in sublists.value)
        if (list.id == id)
          FavoriteSublist(id: id, name: list.name, hymns: [
            if (selected) entry,
            ...list.hymns.where((e) => e != entry)
          ])
        else
          list
    ];
    return _save();
  }

  Future<void> _save() {
    final snapshot = SavedFavoriteCollection(List.of(value), [
      for (final list in sublists.value)
        SavedFavoriteList(
            id: list.id, name: list.name, hymns: List.of(list.hymns)),
    ]);
    // Preserve tap order even when several checkboxes change rapidly.
    final previous = _pendingSave;
    Future<void> write() async {
      if (previous != null) await previous.catchError((Object _) {});
      if (storageError.value) return;
      try {
        await SavedHymnStore.saveFavorites(
            await SharedPreferences.getInstance(), snapshot);
      } catch (_) {
        storageError.value = true;
      }
    }

    final operation = write();
    _pendingSave = operation;
    void clear() {
      if (identical(_pendingSave, operation)) _pendingSave = null;
    }

    operation.then((_) => clear(),
        onError: (Object _, StackTrace __) => clear());
    return operation;
  }

  /// Move to the final zero-based position. Retain every
  /// reference, including books which are not currently installed.
  Future<void> reorderHymns(int oldIndex, int newIndex, {String? sublistId}) {
    if (storageError.value) return Future.value();
    final category = sublistId == null
        ? null
        : sublists.value.where((list) => list.id == sublistId).firstOrNull;
    if (sublistId != null && category == null) return Future.value();
    final entries = List.of(category?.hymns ?? value);
    if (oldIndex < 0 ||
        oldIndex >= entries.length ||
        newIndex < 0 ||
        newIndex >= entries.length) {
      return Future.value();
    }
    if (oldIndex == newIndex) return Future.value();
    entries.insert(newIndex, entries.removeAt(oldIndex));
    if (category == null) {
      value = entries;
    } else {
      sublists.value = [
        for (final list in sublists.value)
          if (list.id == sublistId)
            FavoriteSublist(id: list.id, name: list.name, hymns: entries)
          else
            list,
      ];
    }
    return _save();
  }

  /// Adds the hymn (to the front) if absent, removes it otherwise.
  Future<void> toggle(Hymn hymn) async {
    if (storageError.value) return;
    final entry = (n: hymn.number, v: hymn.version);
    final removing = contains(entry.n, entry.v);
    value = contains(entry.n, entry.v)
        ? value.where((e) => !(e.n == entry.n && e.v == entry.v)).toList()
        : [entry, ...value];
    await _save();
    AppAnalytics.instance.event(removing ? 'favorite_remove' : 'favorite_add',
        hymn: hymn.number, edition: hymn.version);
  }
}
