import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/prefs.dart';

/// Plays the bundled New-Hymnal MIDI files (assets/midi/001.mid … 695.mid)
/// through the platform media player. One hymn at a time; play/pause toggles.
/// Old-Hymnal hymns have no MIDI, so [hasMidi] gates the UI.
///
/// Transposition ([transpose]) and the instrument theme ([InstrumentTheme])
/// are applied by rewriting the asset bytes with [transformMidi] into a
/// temp-dir cache file and playing that; at the defaults (no shift, Classic)
/// the untouched asset plays directly as before.
class MidiPlayer {
  MidiPlayer._() {
    _player.onPlayerComplete.listen((_) {
      current.value = null;
      position.value = Duration.zero;
      duration.value = Duration.zero;
    });
    _player.onPositionChanged.listen((p) => position.value = p);
    _player.onDurationChanged.listen((d) => duration.value = d);
    // An instrument change re-renders the loaded tune in place.
    InstrumentTheme.instance.addListener(_restartWithTransform);
  }

  static final MidiPlayer instance = MidiPlayer._();

  final AudioPlayer _player = AudioPlayer();

  /// Hymn number currently loaded (+ paused flag); null when stopped.
  final ValueNotifier<({int n, bool paused})?> current = ValueNotifier(null);

  /// Playback progress of the current hymn (zero when stopped).
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  /// Playback speed multiplier (0.75–2.0, pitch preserved). Session-scoped;
  /// applies to the current tune immediately and to every tune started after.
  final ValueNotifier<double> speed = ValueNotifier(1.0);

  /// Semitone shift (-6..+6) applied to the current hymn. Per-hymn: it
  /// resets to 0 automatically when a different hymn number comes up.
  final ValueNotifier<int> transpose = ValueNotifier(0);

  /// Key signature of the hymn page's tune as written ([prepareKey]); null
  /// for Old-Hymnal hymns and files without one.
  final ValueNotifier<MidiKey?> originalKey = ValueNotifier(null);

  /// Last hymn number prepared or played — the anchor for the automatic
  /// transpose reset.
  int? _lastN;

  static bool hasMidi(Hymn hymn) => hymn.version == 'new';

  static String _asset(int n) => 'midi/${n.toString().padLeft(3, '0')}.mid';

  static Future<Uint8List> _assetBytes(int n) async {
    final data = await rootBundle.load('assets/${_asset(n)}');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Reset the per-hymn transposition when [n] is a new hymn number.
  void _trackHymn(int n) {
    if (_lastN == n) return;
    _lastN = n;
    if (transpose.value != 0) transpose.value = 0;
  }

  /// Called by the hymn page on init: publishes the tune's written key to
  /// [originalKey] (null when there is no MIDI or no key signature) and
  /// resets [transpose] when the page shows a new hymn number.
  Future<void> prepareKey(Hymn hymn) async {
    _trackHymn(hymn.number);
    if (!hasMidi(hymn)) {
      originalKey.value = null;
      return;
    }
    try {
      originalKey.value = readKeySignature(await _assetBytes(hymn.number));
    } catch (_) {
      originalKey.value = null;
    }
  }

  /// Source for hymn [n] under the current transpose + instrument theme:
  /// the bare asset when both are at their defaults, otherwise a transformed
  /// render cached in the temp dir per (hymn, shift, theme).
  Future<Source> _source(int n) async {
    final semis = transpose.value;
    final theme = InstrumentTheme.instance;
    if (semis == 0 && theme.program == null) return AssetSource(_asset(n));
    final dir = Directory('${(await getTemporaryDirectory()).path}/midi_cache');
    final name = '${n.toString().padLeft(3, '0')}_t${semis}_${theme.value}.mid';
    final file = File('${dir.path}/$name');
    if (!await file.exists()) {
      final out = transformMidi(await _assetBytes(n),
          semitones: semis, forceProgram: theme.program);
      await dir.create(recursive: true);
      await file.writeAsBytes(out, flush: true);
    }
    return DeviceFileSource(file.path);
  }

  /// Play the hymn; if it is already the current one, toggle pause/resume.
  Future<void> toggle(Hymn hymn) async {
    if (!hasMidi(hymn)) return;
    final cur = current.value;
    if (cur != null && cur.n == hymn.number) {
      if (cur.paused) {
        await _player.resume();
        current.value = (n: hymn.number, paused: false);
        await _applySpeed();
      } else {
        await _player.pause();
        current.value = (n: hymn.number, paused: true);
      }
      return;
    }
    _trackHymn(hymn.number);
    await _player.stop();
    current.value = (n: hymn.number, paused: false);
    try {
      await _player.play(await _source(hymn.number));
      await _applySpeed();
    } catch (_) {
      current.value = null;
    }
  }

  /// Shift the current key by [semitones] (clamped -6..+6). Takes effect
  /// immediately: a loaded hymn is re-rendered and resumed in place.
  Future<void> setTranspose(int semitones) async {
    final s = semitones.clamp(-6, 6);
    if (s == transpose.value) return;
    transpose.value = s;
    await _restartWithTransform();
  }

  /// Restart the loaded hymn through the current transform and pick up
  /// where it was: same position, same pause state, same speed.
  Future<void> _restartWithTransform() async {
    final cur = current.value;
    if (cur == null) return;
    final pos = position.value;
    await _player.stop();
    current.value = (n: cur.n, paused: false);
    try {
      await _player.play(await _source(cur.n));
      await _applySpeed();
      await _player.seek(pos);
      position.value = pos;
      if (cur.paused) {
        await _player.pause();
        current.value = (n: cur.n, paused: true);
      }
    } catch (_) {
      current.value = null;
      position.value = Duration.zero;
      duration.value = Duration.zero;
    }
  }

  Future<void> setSpeed(double s) async {
    speed.value = s;
    await _applySpeed();
  }

  /// MediaPlayer only accepts a rate while actively playing; paused/stopped
  /// states pick it up from the next resume/play.
  Future<void> _applySpeed() async {
    final cur = current.value;
    if (cur == null || cur.paused) return;
    try {
      await _player.setPlaybackRate(speed.value);
    } catch (_) {}
  }

  /// Jump forward/back by [delta], clamped to the track bounds.
  Future<void> seekBy(Duration delta) async {
    if (current.value == null) return;
    final target = position.value + delta;
    final max = duration.value;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (max > Duration.zero && target > max)
            ? max
            : target;
    await _player.seek(clamped);
    position.value = clamped;
  }

  Future<void> stop() async {
    await _player.stop();
    current.value = null;
    position.value = Duration.zero;
    duration.value = Duration.zero;
  }

  /// Stop only if [number] is the hymn currently loaded — lets a disposed
  /// hymn page clean up without cutting off a newer page's playback.
  Future<void> stopIfCurrent(int number) async {
    if (current.value?.n == number) await stop();
  }
}
