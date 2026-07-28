import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path_provider/path_provider.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/style_arranger.dart';
import 'package:sdahymnal/services/prefs.dart';

/// Plays the bundled New-Hymnal MIDI files (assets/midi/001.mid … 695.mid).
/// One hymn at a time; play/pause toggles. Old-Hymnal hymns have no MIDI, so
/// [hasMidi] gates the UI.
///
/// Two engines behind one API:
///  * Android (and host test runs): the platform media player via
///    audioplayers, unchanged.
///  * iOS: the native soundfont player behind the 'sdahymnal/midi'
///    MethodChannel (load/play/pause/stop/seek/setRate/getPosition, plus an
///    'onComplete' callback), which only accepts real file paths.
///
/// Transposition ([transpose]) and the instrument theme ([InstrumentTheme])
/// are applied by rewriting the asset bytes with [transformMidi] into a
/// temp-dir cache file and playing that; at the defaults (no shift, Classic)
/// the untouched asset plays directly (audioplayers) or is materialized
/// verbatim into the same cache (iOS).
class MidiPlayer {
  MidiPlayer._() {
    if (_useChannel) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onComplete') _onComplete();
        return null;
      });
    } else {
      _player.onPlayerComplete.listen((_) => _onComplete());
      _player.onPositionChanged.listen((p) => position.value = p);
      _player.onDurationChanged.listen((d) => duration.value = d);
    }
    // An instrument change re-renders the loaded tune in place.
    InstrumentTheme.instance.addListener(_restartWithTransform);
  }

  static final MidiPlayer instance = MidiPlayer._();

  /// True when playback goes through the native iOS channel engine. Host
  /// test runs report Platform.isIOS == false and keep the audioplayers path.
  static final bool _useChannel = !kIsWeb && Platform.isIOS;

  static const MethodChannel _channel = MethodChannel('sdahymnal/midi');

  /// Created lazily so the iOS engine never spins up an audioplayers player.
  late final AudioPlayer _player = AudioPlayer();

  /// Polls getPosition while the channel engine is audibly playing.
  Timer? _posTimer;

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

  /// Chords detected in the hymn page's tune ([prepareKey]); null for
  /// Old-Hymnal hymns and files where detection finds nothing.
  final ValueNotifier<ChordTrack?> chordTrack = ValueNotifier(null);

  /// Detection results per hymn number, so revisiting a page skips the parse.
  final Map<int, ChordTrack?> _chordCache = {};

  /// Last hymn number prepared or played — the anchor for the automatic
  /// transpose reset.
  int? _lastN;

  static bool hasMidi(Hymn hymn) => hymn.version == 'new';

  static String _asset(int n) => 'midi/${n.toString().padLeft(3, '0')}.mid';

  static Future<Uint8List> _assetBytes(int n) async {
    final data = await rootBundle.load('assets/${_asset(n)}');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Duration _toDuration(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  static double _toSeconds(Duration d) => d.inMilliseconds / 1000.0;

  /// Natural end of the tune: same reset on both engines.
  void _onComplete() {
    _stopPositionPolling();
    current.value = null;
    position.value = Duration.zero;
    duration.value = Duration.zero;
  }

  void _startPositionPolling() {
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      try {
        final secs = await _channel.invokeMethod<double>('getPosition');
        final cur = current.value;
        // A poll can resolve after a pause/stop raced past the cancel; only
        // a still-playing tune may move the notifier.
        if (secs != null && cur != null && !cur.paused) {
          position.value = _toDuration(secs);
        }
      } catch (_) {}
    });
  }

  void _stopPositionPolling() {
    _posTimer?.cancel();
    _posTimer = null;
  }

  /// Reset the per-hymn transposition when [n] is a new hymn number.
  void _trackHymn(int n) {
    if (_lastN == n) return;
    _lastN = n;
    if (transpose.value != 0) transpose.value = 0;
  }

  /// Called by the hymn page on init: publishes the tune's written key to
  /// [originalKey] and its detected chords to [chordTrack] (both null when
  /// there is no MIDI) and resets [transpose] when the page shows a new hymn
  /// number.
  Future<void> prepareKey(Hymn hymn) async {
    _trackHymn(hymn.number);
    if (!hasMidi(hymn)) {
      originalKey.value = null;
      chordTrack.value = null;
      return;
    }
    try {
      final bytes = await _assetBytes(hymn.number);
      originalKey.value = readKeySignature(bytes);
      final raw =
          _chordCache.putIfAbsent(hymn.number, () => detectChords(bytes));
      chordTrack.value = _displayTrack(bytes, raw);
    } catch (_) {
      originalKey.value = null;
      chordTrack.value = null;
    }
  }

  /// The chord track as the UI must time it. Raw detection is timed on the
  /// hymn's ORIGINAL tempo map, but arranged themes play a render whose
  /// map is reshaped (clamped) by the arranger — so their chords are
  /// remapped onto the render's timeline, or the ticker runs ahead of the
  /// audio at fast openers and outlives it through closing rits (#15).
  ChordTrack? _displayTrack(Uint8List bytes, ChordTrack? raw) {
    if (raw == null) return null;
    if (_arrangedThemes[InstrumentTheme.instance.value] == null) return raw;
    try {
      return retimeTrackForArrangement(bytes, raw);
    } on FormatException {
      return raw;
    }
  }

  /// Re-times the published chord track for the current theme (called on
  /// every instrument change — switching between a passthrough theme and
  /// an arranged one changes the playing file's timeline).
  Future<void> _republishChords() async {
    final n = _lastN;
    if (n == null || chordTrack.value == null) return;
    try {
      final bytes = await _assetBytes(n);
      chordTrack.value = _displayTrack(
          bytes, _chordCache.putIfAbsent(n, () => detectChords(bytes)));
    } catch (_) {}
  }

  /// Source for hymn [n] under the current transpose + instrument theme
  /// (audioplayers engine only): the bare asset when both are at their
  /// defaults, otherwise the cached render from [_renderFile].
  Future<Source> _source(int n) async {
    if (transpose.value == 0 && !InstrumentTheme.instance.transforms) {
      return AssetSource(_asset(n));
    }
    return DeviceFileSource((await _renderFile(n)).path);
  }

  /// File for hymn [n] under the current transpose + instrument theme,
  /// cached in the temp dir per (hymn, shift, theme). At the defaults (no
  /// shift, Classic) the raw asset bytes are materialized verbatim (e.g.
  /// 001_t0_classic.mid) — the iOS channel engine can only load real files.
  /// Bump when render output changes for the same (hymn, shift, theme) —
  /// e.g. theme program retunes or arranger revisions — so stale caches
  /// from earlier app versions are bypassed.
  static const int _renderVersion = 7;

  /// Generated-arrangement themes: the [ArrangeStyle] behind each theme id,
  /// plus the GM program of the plain remap used when a file has no
  /// detectable harmony to arrange (gospel falls back to Rhodes; reggae to
  /// drawbar organ, the church instrument of its palette; calypso to steel
  /// drums — Trinidadian steel orchestras play hymns straight).
  static const Map<String, (ArrangeStyle, int)> _arrangedThemes = {
    'gospel': (ArrangeStyle.gospel, 4),
    'reggae': (ArrangeStyle.reggae, 16),
    'calypso': (ArrangeStyle.calypso, 114),
  };

  Future<File> _renderFile(int n) async {
    final semis = transpose.value;
    final theme = InstrumentTheme.instance;
    final dir = Directory('${(await getTemporaryDirectory()).path}/midi_cache');
    final name =
        '${n.toString().padLeft(3, '0')}_t${semis}_${theme.value}_v$_renderVersion.mid';
    final file = File('${dir.path}/$name');
    if (!await file.exists()) {
      final bytes = await _assetBytes(n);
      final Uint8List out;
      if (semis == 0 && !theme.transforms) {
        out = bytes;
      } else if (_arrangedThemes[theme.value] != null) {
        // Generated accompaniment: melody preserved, backing rearranged from
        // the detected chords. Transposition composes on the arranged bytes.
        final (style, fallbackProgram) = _arrangedThemes[theme.value]!;
        Uint8List arranged;
        try {
          arranged = arrangeStyle(bytes, style);
        } on FormatException {
          // No detectable harmony: degrade to a plain single-program remap.
          arranged = transformMidi(bytes, forceProgram: fallbackProgram);
        }
        out = semis == 0
            ? arranged
            : transformMidi(arranged, semitones: semis);
      } else {
        out = transformMidi(
          bytes,
          semitones: semis,
          forceProgram: theme.program,
        );
      }
      await dir.create(recursive: true);
      await file.writeAsBytes(out, flush: true);
    }
    return file;
  }

  /// Play the hymn; if it is already the current one, toggle pause/resume.
  Future<void> toggle(Hymn hymn) async {
    if (!hasMidi(hymn)) return;
    if (_useChannel) return _channelToggle(hymn);
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

  Future<void> _channelToggle(Hymn hymn) async {
    final cur = current.value;
    if (cur != null && cur.n == hymn.number) {
      try {
        if (cur.paused) {
          await _channel.invokeMethod('play');
          current.value = (n: hymn.number, paused: false);
          await _applySpeed();
          _startPositionPolling();
        } else {
          _stopPositionPolling();
          await _channel.invokeMethod('pause');
          current.value = (n: hymn.number, paused: true);
          // Snap to the exact paused position (the last poll can be stale).
          final secs = await _channel.invokeMethod<double>('getPosition');
          if (secs != null) position.value = _toDuration(secs);
        }
      } catch (_) {
        _stopPositionPolling();
        current.value = null;
      }
      return;
    }
    _trackHymn(hymn.number);
    _stopPositionPolling();
    // A failed stop (e.g. nothing loaded yet) must not block the new tune.
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
    current.value = (n: hymn.number, paused: false);
    try {
      final path = (await _renderFile(hymn.number)).path;
      final secs = await _channel.invokeMethod<double>('load', path);
      duration.value = _toDuration(secs ?? 0);
      position.value = Duration.zero;
      await _channel.invokeMethod('play');
      await _applySpeed();
      _startPositionPolling();
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
    await _republishChords();
    if (_useChannel) return _channelRestartWithTransform();
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

  Future<void> _channelRestartWithTransform() async {
    final cur = current.value;
    if (cur == null) return;
    final pos = position.value;
    _stopPositionPolling();
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
    current.value = (n: cur.n, paused: false);
    try {
      final path = (await _renderFile(cur.n)).path;
      final secs = await _channel.invokeMethod<double>('load', path);
      duration.value = _toDuration(secs ?? 0);
      await _applySpeed();
      await _channel.invokeMethod('seek', _toSeconds(pos));
      position.value = pos;
      if (cur.paused) {
        // No need to start-then-pause: play() later resumes from the seek.
        current.value = (n: cur.n, paused: true);
      } else {
        await _channel.invokeMethod('play');
        _startPositionPolling();
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

  /// Applied only while actively playing on both engines (MediaPlayer
  /// rejects a rate otherwise); paused/stopped states pick it up from the
  /// next resume/play — on iOS setRate also persists natively across loads.
  Future<void> _applySpeed() async {
    final cur = current.value;
    if (cur == null || cur.paused) return;
    try {
      if (_useChannel) {
        await _channel.invokeMethod('setRate', speed.value);
      } else {
        await _player.setPlaybackRate(speed.value);
      }
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
    if (_useChannel) {
      try {
        await _channel.invokeMethod('seek', _toSeconds(clamped));
      } catch (_) {}
    } else {
      await _player.seek(clamped);
    }
    position.value = clamped;
  }

  Future<void> stop() async {
    if (_useChannel) {
      _stopPositionPolling();
      try {
        await _channel.invokeMethod('stop');
      } catch (_) {}
    } else {
      await _player.stop();
    }
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
