import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path_provider/path_provider.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/midi_cache.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/style_arranger.dart';
import 'package:sdahymnal/services/prefs.dart';

/// Plays the bundled New-Hymnal MIDI files (assets/midi/001.mid … 695.mid)
/// and Old-Hymnal files (assets/midi/C001.mid … C703.mid). One hymn at a
/// time; play/pause toggles. [hasMidi] gates invalid/out-of-range records.
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
typedef MidiPlayback = ({String version, int n, bool paused});

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

  /// Hymnal edition + number currently loaded (+ paused flag); null stopped.
  final ValueNotifier<MidiPlayback?> current = ValueNotifier(null);

  /// Playback progress of the current hymn (zero when stopped).
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  /// Playback speed multiplier (0.75–2.0, pitch preserved). Session-scoped;
  /// applies to the current tune immediately and to every tune started after.
  final ValueNotifier<double> speed = ValueNotifier(1.0);

  /// Semitone shift (-6..+6) applied to the current hymn. Per-hymn: it
  /// resets to 0 when the edition or hymn number changes.
  final ValueNotifier<int> transpose = ValueNotifier(0);

  /// Key signature of the hymn page's tune as written ([prepareKey]); null
  /// for files without one.
  final ValueNotifier<MidiKey?> originalKey = ValueNotifier(null);

  /// Chords detected in the hymn page's tune ([prepareKey]); null for files
  /// where detection finds nothing.
  final ValueNotifier<ChordTrack?> chordTrack = ValueNotifier(null);

  /// Detection results per edition and number, so revisiting skips the parse.
  final Map<(String, int), ChordTrack?> _chordCache = {};

  final Map<(String, int, String), Future<Duration?>> _durationCache = {};

  /// The entire selected arrangement at 1x, without starting audio. Cache
  /// per theme because arranged styles can change the source's tempo map.
  /// Transposition/instrument remapping do not alter event timing.
  Future<Duration?> readingDuration(Hymn hymn) async {
    if (!hasMidi(hymn)) return null;
    final theme = InstrumentTheme.instance.value;
    return _durationCache.putIfAbsent((hymn.version, hymn.number, theme),
        () async {
      try {
        final bytes = await _assetBytes(hymn.version, hymn.number);
        return await compute(_readingDuration, (bytes, theme));
      } catch (_) {
        return null;
      }
    });
  }

  /// Last hymn prepared or played — the anchor for automatic transpose reset.
  (String, int)? _lastHymn;

  static bool hasMidi(Hymn hymn) =>
      hymn.version == 'new' && hymn.number >= 1 && hymn.number <= 695 ||
      hymn.version == 'old' && hymn.number >= 1 && hymn.number <= 703;

  static bool isCurrent(MidiPlayback? playback, Hymn hymn) =>
      playback?.version == hymn.version && playback?.n == hymn.number;

  static String _asset(String version, int n) {
    final prefix = version == 'old' ? 'C' : '';
    return 'midi/$prefix${n.toString().padLeft(3, '0')}.mid';
  }

  static Future<Uint8List> _assetBytes(String version, int n) async {
    final data = await rootBundle.load('assets/${_asset(version, n)}');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Duration _toDuration(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  static double _toSeconds(Duration d) => d.inMilliseconds / 1000.0;

  /// Natural end of the tune: same reset on both engines.
  void _onComplete() {
    _stopPositionPolling();
    // Publish the exact endpoint before clearing playback. Readers following
    // the timeline reach the final chorus even if the last native poll was early.
    if (duration.value > Duration.zero) position.value = duration.value;
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

  /// Reset transposition when either the edition or hymn number changes.
  void _trackHymn(Hymn hymn) {
    final id = (hymn.version, hymn.number);
    if (_lastHymn == id) return;
    _lastHymn = id;
    if (transpose.value != 0) transpose.value = 0;
  }

  /// Called by the hymn page on init: publishes the tune's written key to
  /// [originalKey] and its detected chords to [chordTrack] (both null when
  /// there is no MIDI) and resets [transpose] when the page shows a new hymn
  /// number.
  Future<void> prepareKey(Hymn hymn) async {
    _trackHymn(hymn);
    if (!hasMidi(hymn)) {
      originalKey.value = null;
      chordTrack.value = null;
      return;
    }
    try {
      final bytes = await _assetBytes(hymn.version, hymn.number);
      originalKey.value = readKeySignature(bytes);
      final id = (hymn.version, hymn.number);
      final raw = _chordCache.putIfAbsent(id, () => detectChords(bytes));
      chordTrack.value = _displayTrack(bytes, raw);
    } catch (_) {
      originalKey.value = null;
      chordTrack.value = null;
    }
  }

  /// The chord track as the UI must time it. Raw detection is timed on the
  /// hymn's ORIGINAL tempo map, but arranged themes play a render whose map
  /// the arranger reshapes — clamped for gospel, flattened outright for the
  /// island styles — so their chords are remapped onto the render's own
  /// timeline, or the ticker runs ahead of the audio at fast openers and
  /// outlives it through closing rits (#15). The remap must be told which
  /// style is playing, because the two reshape the timeline differently.
  ChordTrack? _displayTrack(Uint8List bytes, ChordTrack? raw) {
    if (raw == null) return null;
    final arranged = arrangedMidiThemes[InstrumentTheme.instance.value];
    if (arranged == null) return raw;
    try {
      return retimeTrackForArrangement(bytes, raw, arranged.$1);
    } on FormatException {
      return raw;
    }
  }

  /// Re-times the published chord track for the current theme (called on
  /// every instrument change — switching between a passthrough theme and
  /// an arranged one changes the playing file's timeline).
  Future<void> _republishChords() async {
    final id = _lastHymn;
    if (id == null || chordTrack.value == null) return;
    final (version, n) = id;
    try {
      final bytes = await _assetBytes(version, n);
      chordTrack.value = _displayTrack(bytes,
          _chordCache.putIfAbsent((version, n), () => detectChords(bytes)));
    } catch (_) {}
  }

  /// Source for hymn [n] under the current transpose + instrument theme
  /// (audioplayers engine only): the bare asset when both are at their
  /// defaults, otherwise the cached render from [_renderFile].
  Future<Source> _source(String version, int n) async {
    if (transpose.value == 0 && !InstrumentTheme.instance.transforms) {
      return AssetSource(_asset(version, n));
    }
    return DeviceFileSource((await _renderFile(version, n)).path);
  }

  late final Future<MidiRenderCache> _renderCache = getTemporaryDirectory()
      .then((dir) => MidiRenderCache(Directory('${dir.path}/midi_cache')));

  /// Snapshot options before awaiting storage so rapid theme/key changes
  /// cannot save one arrangement under another arrangement's cache key.
  Future<File> _renderFile(String version, int n) async {
    final semis = transpose.value;
    final theme = InstrumentTheme.instance.value;
    final program = InstrumentTheme.instance.program;
    final name = MidiRenderCache.filename(
        hymnal: version,
        hymn: n,
        semitones: semis,
        theme: theme,
        forceProgram: program,
        forAppleSynth: _useChannel);
    return (await _renderCache).getOrCreate(
        name,
        () async => renderHymnMidi(await _assetBytes(version, n),
            theme: theme,
            semitones: semis,
            forceProgram: program,
            forAppleSynth: _useChannel));
  }

  /// Play the hymn; if it is already the current one, toggle pause/resume.
  Future<void> toggle(Hymn hymn) async {
    if (!hasMidi(hymn)) return;
    if (_useChannel) return _channelToggle(hymn);
    final cur = current.value;
    if (isCurrent(cur, hymn)) {
      if (cur!.paused) {
        await _player.resume();
        current.value = (version: hymn.version, n: hymn.number, paused: false);
        await _applySpeed();
      } else {
        await _player.pause();
        current.value = (version: hymn.version, n: hymn.number, paused: true);
      }
      return;
    }
    _trackHymn(hymn);
    await _player.stop();
    position.value = Duration.zero;
    duration.value = Duration.zero;
    current.value = (version: hymn.version, n: hymn.number, paused: false);
    try {
      await _player.play(await _source(hymn.version, hymn.number));
      await _applySpeed();
    } catch (_) {
      current.value = null;
    }
  }

  Future<void> _channelToggle(Hymn hymn) async {
    final cur = current.value;
    if (isCurrent(cur, hymn)) {
      try {
        if (cur!.paused) {
          await _channel.invokeMethod('play');
          current.value =
              (version: hymn.version, n: hymn.number, paused: false);
          await _applySpeed();
          _startPositionPolling();
        } else {
          _stopPositionPolling();
          await _channel.invokeMethod('pause');
          current.value = (version: hymn.version, n: hymn.number, paused: true);
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
    _trackHymn(hymn);
    _stopPositionPolling();
    // A failed stop (e.g. nothing loaded yet) must not block the new tune.
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
    position.value = Duration.zero;
    duration.value = Duration.zero;
    current.value = (version: hymn.version, n: hymn.number, paused: false);
    try {
      final path = (await _renderFile(hymn.version, hymn.number)).path;
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
    current.value = (version: cur.version, n: cur.n, paused: false);
    try {
      await _player.play(await _source(cur.version, cur.n));
      await _applySpeed();
      await _player.seek(pos);
      position.value = pos;
      if (cur.paused) {
        await _player.pause();
        current.value = (version: cur.version, n: cur.n, paused: true);
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
    current.value = (version: cur.version, n: cur.n, paused: false);
    try {
      final path = (await _renderFile(cur.version, cur.n)).path;
      final secs = await _channel.invokeMethod<double>('load', path);
      duration.value = _toDuration(secs ?? 0);
      await _applySpeed();
      await _channel.invokeMethod('seek', _toSeconds(pos));
      position.value = pos;
      if (cur.paused) {
        // No need to start-then-pause: play() later resumes from the seek.
        current.value = (version: cur.version, n: cur.n, paused: true);
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

  /// Stop only if [hymn] is currently loaded — lets a disposed
  /// hymn page clean up without cutting off a newer page's playback.
  Future<void> stopIfCurrent(Hymn hymn) async {
    if (isCurrent(current.value, hymn)) await stop();
  }
}

Duration _readingDuration((Uint8List, String) input) {
  final (bytes, theme) = input;
  return readMidiDuration(arrangedMidiThemes.containsKey(theme)
      ? renderHymnMidi(bytes, theme: theme)
      : bytes);
}
