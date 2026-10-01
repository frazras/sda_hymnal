import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in settings. Instrument choices are stored independently for each style.
class MusicOptions extends ChangeNotifier {
  MusicOptions._();
  static final instance = MusicOptions._();
  bool customInstruments = false;
  bool choirPractice = false;
  final Map<String, Map<int, int>> _programs = {};
  final Map<String, Map<int, int>> _styleVolumes = {};
  final Map<String, Set<int>> _styleSolo = {};
  final Map<String, String> _names = {};
  final Map<String, Map<int, int>> _trackPrograms = {};

  final Map<String, Map<int, int>> _trackVolumes = {};
  Map<int, int> trackVolumes(String hymn) => Map.of(_trackVolumes[hymn] ?? {});

  Future<void> setTrackVolume(String hymn, int track, int volume) async {
    RangeError.checkValueInInterval(volume, 0, 100, 'volume');
    final values = _trackVolumes.putIfAbsent(hymn, () => {});
    if (volume == 100) {
      values.remove(track);
    } else {
      values[track] = volume;
    }
    notifyListeners();
    await _saveTrackVolumes();
  }

  Future<void> resetTrackVolumes(String hymn) async {
    _trackVolumes.remove(hymn);
    notifyListeners();
    await _saveTrackVolumes();
  }

  Future<void> _saveTrackVolumes() async {
    await (await SharedPreferences.getInstance()).setString(
        'trackVolumes',
        jsonEncode({
          for (final entry in _trackVolumes.entries)
            entry.key: {
              for (final item in entry.value.entries)
                item.key.toString(): item.value,
            },
        }));
  }

  Map<int, int> trackPrograms(String hymn) =>
      Map.of(_trackPrograms[hymn] ?? {});

  Future<void> setTrackProgram(String hymn, int track, int? program) async {
    if (program != null) RangeError.checkValueInInterval(program, 0, 127);
    final values = _trackPrograms.putIfAbsent(hymn, () => {});
    if (program == null) {
      values.remove(track);
    } else {
      values[track] = program;
    }
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
        'trackInstruments',
        jsonEncode({
          for (final entry in _trackPrograms.entries)
            entry.key: {
              for (final item in entry.value.entries)
                item.key.toString(): item.value
            }
        }));
  }

  Map<int, int> programs(String style) =>
      customInstruments ? Map.of(_programs[style] ?? {}) : {};
  Map<int, int> styleVolumes(String style) => {
        if (style == 'jazz') 0: 50,
        if (customInstruments) ...?_styleVolumes[style]
      };
  Set<int> styleSolo(String style) =>
      customInstruments ? Set.of(_styleSolo[style] ?? {}) : {};

  Future<void> setStyleVolume(String style, int channel, int volume) async {
    RangeError.checkValueInInterval(volume, 0, 100, 'volume');
    final values = _styleVolumes.putIfAbsent(style, () => {});
    if (volume == (style == 'jazz' && channel == 0 ? 50 : 100)) {
      values.remove(channel);
    } else {
      values[channel] = volume;
    }
    notifyListeners();
    await _saveStyleMix();
  }

  Future<void> setStyleSolo(String style, int channel, bool solo) async {
    final values = _styleSolo.putIfAbsent(style, () => {});
    if (solo) {
      values.add(channel);
    } else {
      values.remove(channel);
    }
    notifyListeners();
    await _saveStyleMix();
  }

  Future<void> _saveStyleMix() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'styleVolumes',
        jsonEncode({
          for (final e in _styleVolumes.entries)
            e.key: {for (final v in e.value.entries) v.key.toString(): v.value}
        }));
    await prefs.setString(
        'styleSolo',
        jsonEncode(
            {for (final e in _styleSolo.entries) e.key: e.value.toList()}));
  }

  String partName(String hymn, int track, String fallback) =>
      _names['$hymn:$track'] ?? fallback;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    customInstruments = prefs.getBool('customInstruments') ?? false;
    choirPractice = prefs.getBool('choirPractice') ?? false;
    _programs.clear();
    _styleVolumes.clear();
    _styleSolo.clear();
    _names.clear();
    _trackPrograms.clear();
    _trackVolumes.clear();
    try {
      final rawVolumes =
          jsonDecode(prefs.getString('styleVolumes') ?? '{}') as Map;
      for (final entry in rawVolumes.entries) {
        _styleVolumes[entry.key.toString()] = {
          for (final item in (entry.value as Map).entries)
            if (int.tryParse(item.key.toString()) case final channel?
                when item.value is int && item.value >= 0 && item.value <= 100)
              channel: item.value as int,
        };
      }
      final rawSolo = jsonDecode(prefs.getString('styleSolo') ?? '{}') as Map;
      for (final entry in rawSolo.entries) {
        _styleSolo[entry.key.toString()] = {
          for (final channel in (entry.value as List))
            if (channel is int && channel >= 0 && channel < 16) channel,
        };
      }
    } catch (_) {}
    try {
      final raw = jsonDecode(prefs.getString('trackVolumes') ?? '{}') as Map;
      for (final entry in raw.entries) {
        final values = <int, int>{};
        for (final item in (entry.value as Map).entries) {
          final track = int.tryParse(item.key.toString());
          if (track != null &&
              track >= 0 &&
              item.value is int &&
              item.value >= 0 &&
              item.value < 100) {
            values[track] = item.value as int;
          }
        }
        _trackVolumes[entry.key.toString()] = values;
      }
    } catch (_) {
      _trackVolumes.clear();
    }

    try {
      final raw =
          jsonDecode(prefs.getString('trackInstruments') ?? '{}') as Map;
      for (final entry in raw.entries) {
        final values = <int, int>{};
        for (final item in (entry.value as Map).entries) {
          final track = int.tryParse(item.key.toString());
          if (track != null &&
              track >= 0 &&
              item.value is int &&
              item.value >= 0 &&
              item.value < 128) {
            values[track] = item.value as int;
          }
        }
        _trackPrograms[entry.key.toString()] = values;
      }
    } catch (_) {
      _trackPrograms.clear();
    }
    try {
      final raw = jsonDecode(prefs.getString('stylePrograms') ?? '{}') as Map;
      for (final entry in raw.entries) {
        final programs = <int, int>{};
        for (final item in (entry.value as Map).entries) {
          final channel = int.tryParse(item.key.toString());
          if (channel != null &&
              channel >= 0 &&
              channel < 16 &&
              channel != 9 &&
              item.value is int &&
              item.value >= 0 &&
              item.value < 128) {
            programs[channel] = item.value as int;
          }
        }
        _programs[entry.key.toString()] = programs;
      }
      final names =
          jsonDecode(prefs.getString('vocalPartNames') ?? '{}') as Map;
      for (final entry in names.entries) {
        if (entry.value is String) _names[entry.key.toString()] = entry.value;
      }
    } catch (_) {/* Invalid optional preferences fall back to defaults. */}
    notifyListeners();
  }

  Future<void> setCustomInstruments(bool value) async {
    customInstruments = value;
    notifyListeners();
    await (await SharedPreferences.getInstance())
        .setBool('customInstruments', value);
  }

  Future<void> setChoirPractice(bool value) async {
    choirPractice = value;
    notifyListeners();
    await (await SharedPreferences.getInstance())
        .setBool('choirPractice', value);
  }

  Future<void> setProgram(String style, int channel, int? program) async {
    final values = _programs.putIfAbsent(style, () => {});
    if (program == null) {
      values.remove(channel);
    } else {
      values[channel] = program;
    }
    notifyListeners();
    await (await SharedPreferences.getInstance()).setString(
        'stylePrograms',
        jsonEncode({
          for (final entry in _programs.entries)
            entry.key: {
              for (final item in entry.value.entries)
                item.key.toString(): item.value,
            },
        }));
  }

  Future<void> renamePart(String hymn, int track, String name) async {
    final key = '$hymn:$track';
    if (name.trim().isEmpty) {
      _names.remove(key);
    } else {
      _names[key] = name.trim();
    }
    notifyListeners();
    await (await SharedPreferences.getInstance())
        .setString('vocalPartNames', jsonEncode(_names));
  }
}

Map<int, String> instrumentRoles(String style) => switch (style) {
      'jazz' => {
          0: 'Melody',
          1: 'Piano chords',
          2: 'Walking bass',
          4: 'Descant (when present)',
          9: 'Drum kit'
        },
      'gospel' => {
          0: 'Melody',
          1: 'Chords',
          2: 'Bass',
          4: 'Descant (when present)',
          9: 'Drum kit'
        },
      'jamaican_gospel' => {
          0: 'Melody',
          1: 'Offbeat organ',
          2: 'Bass',
          4: 'Descant (when present)',
          9: 'Drum kit'
        },
      'reggae' => {
          0: 'Melody',
          1: 'Offbeat chords',
          2: 'Bass',
          3: 'Organ backing',
          4: 'Descant (when present)',
          9: 'Drum kit'
        },
      'calypso' => {
          0: 'Melody',
          1: 'Strum',
          2: 'Bass',
          3: 'Shimmer',
          4: 'Descant (when present)',
          9: 'Drum kit'
        },
      _ => {0: 'All melodic parts'},
    };
