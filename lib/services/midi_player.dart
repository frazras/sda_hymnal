import 'dart:async';
import 'dart:io';

import 'hymn_recordings.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:path_provider/path_provider.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/midi_cache.dart';
import 'package:sdahymnal/services/verified_midi.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/style_arranger.dart';
import 'package:sdahymnal/services/prefs.dart';

/// Plays the bundled New-Hymnal MIDI files (assets/midi/001.mid … 695.mid)
/// and Old-Hymnal files (assets/midi/C001.mid … C703.mid). One hymn at a
/// time; play/pause toggles. [hasMidi] identifies editable arrangements;
/// [hasMusic] also includes edition-specific instrumental recordings.
///
/// Two engines behind one API:
///  * Recordings on every platform, plus Android MIDI: audioplayers.
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
  MidiPlayer._(
      {bool? useNative, Future<File> Function(String, int)? recordingFile})
      : _useChannel = useNative ?? (!kIsWeb && Platform.isIOS),
        _recordingFile = recordingFile ?? HymnRecordings.file {
    if (_useChannel) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onComplete' && _nativeActive) _onComplete();
        return null;
      });
    }
    _player.onPlayerComplete.listen((_) {
      if (!_nativeActive) _onComplete();
    });
    _player.onPositionChanged.listen((p) {
      if (!_nativeActive && current.value != null) position.value = p;
    });
    _player.onDurationChanged.listen((d) {
      if (!_nativeActive && current.value != null) duration.value = d;
    });
    // An instrument change re-renders the loaded tune in place.
    InstrumentTheme.instance.addListener(_restartWithTransform);
    MusicOptions.instance.addListener(_restartWithTransform);
  }

  static final MidiPlayer instance = MidiPlayer._();

  @visibleForTesting
  factory MidiPlayer.forTesting(
          {required bool useNative,
          required Future<File> Function(String, int) recordingFile}) =>
      MidiPlayer._(useNative: useNative, recordingFile: recordingFile);

  final Future<File> Function(String, int) _recordingFile;

  final ValueNotifier<List<({int index, String name})>> parts =
      ValueNotifier([]);
  final ValueNotifier<Set<int>> mutedParts = ValueNotifier({});
  final ValueNotifier<Set<int>> soloParts = ValueNotifier({});
  bool _preview = false;
  bool get isPreview => _preview;
  Hymn? _loadedHymn;
  Hymn? get loadedHymn => _loadedHymn;
  bool get _practice => MusicOptions.instance.choirPractice && !_preview;
  int _stopGeneration = 0;
  Future<void> _operations = Future.value();
  Future<void> _enqueue(Future<void> Function() action) {
    final next = _operations.then((_) => action());
    _operations = next.catchError((Object _) {});
    return next;
  }

  Future<void> setPartMuted(int track, bool muted) async {
    mutedParts.value = {...mutedParts.value}..remove(track);
    if (muted) mutedParts.value = {...mutedParts.value, track};
    await _restartWithTransform();
  }

  Future<void> setPartSolo(int track, bool solo) async {
    soloParts.value = {...soloParts.value}..remove(track);
    if (solo) soloParts.value = {...soloParts.value, track};
    await _restartWithTransform();
  }

  Future<void> setPartInstrument(Hymn hymn, int track, int? program) async {
    final id = '${hymn.version}:${hymn.number}';
    final choices = MusicOptions.instance.trackPrograms(id);
    if (program == null) {
      choices.remove(track);
    } else {
      choices[track] = program;
    }
    // Validate channel capacity before saving a choice that playback cannot honor.
    instrumentMidiParts(await _assetBytes(hymn.version, hymn.number), choices);
    await MusicOptions.instance.setTrackProgram(id, track, program);
    // The preference listener queues the reload; wait for that reload as well.
    await _operations;
  }

  Future<void> resetParts({Hymn? hymn}) async {
    mutedParts.value = {};
    soloParts.value = {};
    final id = hymn != null
        ? '${hymn.version}:${hymn.number}'
        : _lastHymn == null
            ? null
            : '${_lastHymn!.$1}:${_lastHymn!.$2}';
    if (id != null && MusicOptions.instance.trackVolumes(id).isNotEmpty) {
      await MusicOptions.instance.resetTrackVolumes(id);
      await _operations;
    } else {
      await _restartWithTransform();
    }
  }

  /// Preview shares the native engine, so it cannot overlap hymn playback.
  Future<void> preview(Hymn hymn) => _enqueue(() async {
        await _stop();
        _preview = true;
        await _toggle(hymn);
      });

  Future<void> stopPreview() => _enqueue(() async {
        if (_preview) await _stop();
      });

  /// True when playback goes through the native iOS channel engine. Host
  /// test runs report Platform.isIOS == false and keep the audioplayers path.
  final bool _useChannel;

  static const MethodChannel _channel = MethodChannel('sdahymnal/midi');

  bool _recording = false;
  bool get _nativeActive => _useChannel && !_recording;
  final ValueNotifier<bool> loading = ValueNotifier(false);

  /// Also plays instrumental recordings on iOS.
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
    final theme = _practice ? 'classic' : InstrumentTheme.instance.value;
    return _durationCache.putIfAbsent((hymn.version, hymn.number, theme),
        () async {
      try {
        final bytes = await _assetBytes(hymn.version, hymn.number);
        return await compute(_readingDuration, (bytes, theme));
      } catch (_) {
        AppAnalytics.instance.event('play_error', variant: 'timing');
        return null;
      }
    });
  }

  /// Last hymn prepared or played — the anchor for automatic transpose reset.
  (String, int)? _lastHymn;

  static bool hasMidi(Hymn hymn) =>
      hymnMidiAsset(hymn.version, hymn.number) != null;

  static bool hasMusic(Hymn hymn) =>
      hasMidi(hymn) || HymnRecordings.contains(hymn.version, hymn.number);

  static bool isCurrent(MidiPlayback? playback, Hymn hymn) =>
      playback?.version == hymn.version && playback?.n == hymn.number;

  static String _asset(String version, int n) {
    final asset = hymnMidiAsset(version, n);
    if (asset == null) throw ArgumentError('No verified MIDI for $version:$n');
    return asset;
  }

  static Future<Uint8List> _assetBytes(String version, int n) async {
    final data = await rootBundle.load('assets/${_asset(version, n)}');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static Duration _toDuration(double seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  static double _toSeconds(Duration d) => d.inMilliseconds / 1000.0;

  /// Natural end of the tune: same reset on both engines.
  final _completions = StreamController<MidiPlayback>.broadcast(sync: true);
  Stream<MidiPlayback> get completions => _completions.stream;

  void _onComplete() {
    final finished = current.value;
    if (finished != null) {
      AppAnalytics.instance
          .event('play_complete', hymn: finished.n, edition: finished.version);
    }
    _stopPositionPolling();
    // Publish the exact endpoint before clearing playback. Readers following
    // the timeline reach the final chorus even if the last native poll was early.
    if (duration.value > Duration.zero) position.value = duration.value;
    current.value = null;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    if (finished != null && !finished.paused) _completions.add(finished);
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
    parts.value = [];
    mutedParts.value = {};
    soloParts.value = {};
    if (transpose.value != 0) transpose.value = 0;
  }

  /// Called by the hymn page on init: publishes the tune's written key to
  /// [originalKey] and its detected chords to [chordTrack] (both null when
  /// there is no MIDI) and resets [transpose] when the page shows a new hymn
  /// number.
  Future<void> prepareKey(Hymn hymn) async {
    _preview = false;
    _trackHymn(hymn);
    if (!hasMidi(hymn)) {
      originalKey.value = null;
      chordTrack.value = null;
      return;
    }
    try {
      final bytes = await _assetBytes(hymn.version, hymn.number);
      if (_lastHymn != (hymn.version, hymn.number)) return;
      parts.value = midiParts(bytes);
      originalKey.value = readKeySignature(bytes);
      final id = (hymn.version, hymn.number);
      final raw = _chordCache.putIfAbsent(id, () => detectChords(bytes));
      chordTrack.value = _displayTrack(bytes, raw);
    } catch (_) {
      AppAnalytics.instance.event('play_error', variant: 'decode');
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
    if (_practice) return raw;
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
    if (hymnMidiAsset(version, n) == null) {
      return DeviceFileSource((await _recordingFile(version, n)).path);
    }
    if (transpose.value == 0 &&
        !InstrumentTheme.instance.transforms &&
        !_practice &&
        MusicOptions.instance
            .programs(InstrumentTheme.instance.value)
            .isEmpty &&
        MusicOptions.instance
            .styleVolumes(InstrumentTheme.instance.value)
            .isEmpty &&
        MusicOptions.instance
            .styleSolo(InstrumentTheme.instance.value)
            .isEmpty) {
      return AssetSource(_asset(version, n));
    }
    return DeviceFileSource((await _renderFile(version, n)).path);
  }

  late final Future<MidiRenderCache> _renderCache = getTemporaryDirectory()
      .then((dir) => MidiRenderCache(Directory('${dir.path}/midi_cache'),
          onRepair: () => AppAnalytics.instance
              .event('diagnostic', variant: 'cache_repaired')));

  /// Snapshot options before awaiting storage so rapid theme/key changes
  /// cannot save one arrangement under another arrangement's cache key.
  Future<File> _renderFile(String version, int n) async {
    final semis = transpose.value;
    final theme = InstrumentTheme.instance.value;
    final program = InstrumentTheme.instance.program;
    final programs = MusicOptions.instance.programs(theme);
    final styleVolumes = MusicOptions.instance.styleVolumes(theme);
    final solo = MusicOptions.instance.styleSolo(theme);
    final mutedStyle = solo.isEmpty
        ? <int>{}
        : instrumentRoles(theme).keys.where((ch) => !solo.contains(ch)).toSet();
    final practice = _practice;
    final trackPrograms = practice
        ? MusicOptions.instance.trackPrograms('$version:$n')
        : <int, int>{};
    final trackKeys = trackPrograms.keys.toList()..sort();
    final trackVolumes = practice
        ? MusicOptions.instance.trackVolumes('$version:$n')
        : <int, int>{};
    final volumeKeys = trackVolumes.keys.toList()..sort();
    final muted = practice
        ? {
            ...mutedParts.value,
            if (soloParts.value.isNotEmpty)
              ...parts.value
                  .where((p) => !soloParts.value.contains(p.index))
                  .map((p) => p.index),
          }
        : <int>{};
    final programKeys = programs.keys.toList()..sort();
    final styleVolumeKeys = styleVolumes.keys.toList()..sort();
    final styleSoloKeys = solo.toList()..sort();
    final mutedKeys = muted.toList()..sort();
    final suffix = '_practice${practice ? 1 : 0}'
        '_voices${trackKeys.map((t) => '$t-${trackPrograms[t]}').join('-')}'
        '_levels${volumeKeys.map((t) => '$t-${trackVolumes[t]}').join('-')}'
        '_mix${mutedKeys.join('-')}'
        '_inst${programKeys.map((ch) => '$ch-${programs[ch]}').join('-')}';
    final cacheSuffix =
        '_stylevol${styleVolumeKeys.map((ch) => '$ch-${styleVolumes[ch]}').join('-')}'
        '_stylesolo${styleSoloKeys.join('-')}';
    final name = MidiRenderCache.filename(
            hymnal: version,
            hymn: n,
            semitones: semis,
            theme: theme,
            forceProgram: program,
            forAppleSynth: _useChannel)
        .replaceFirst('.mid', '$suffix$cacheSuffix.mid');
    return (await _renderCache).getOrCreate(
        name,
        () async => renderHymnMidi(await _assetBytes(version, n),
            theme: theme,
            channelPrograms: programs,
            channelVolumes: styleVolumes,
            mutedChannels: mutedStyle,
            mutedTracks: muted,
            choirPractice: practice,
            trackPrograms: trackPrograms,
            trackVolumes: trackVolumes,
            semitones: semis,
            forceProgram: program,
            forAppleSynth: _useChannel));
  }

  /// Play the hymn; if it is already the current one, toggle pause/resume.
  Future<void> toggle(Hymn hymn) async {
    if (!hasMusic(hymn)) return;
    final before = current.value;
    final starting = !isCurrent(before, hymn);
    final watch = Stopwatch()..start();
    if (starting) {
      AppAnalytics.instance.event('play_attempt',
          hymn: hymn.number,
          edition: hymn.version,
          variant: InstrumentTheme.instance.value);
    }
    try {
      await _enqueue(() async {
        _preview = false;
        await _toggle(hymn);
      });
      final after = current.value;
      if (isCurrent(after, hymn)) {
        AppAnalytics.instance.event(
            starting
                ? 'play_start'
                : after!.paused
                    ? 'play_pause'
                    : 'play_resume',
            hymn: hymn.number,
            edition: hymn.version);
        if (starting) {
          AppAnalytics.instance.event('play_start_ms',
              total: watch.elapsedMilliseconds.clamp(0, 3600000));
        }
      } else {
        AppAnalytics.instance
            .event('play_error', variant: starting ? 'start' : 'toggle');
      }
    } catch (_) {
      AppAnalytics.instance.event('play_error', variant: 'toggle');
      rethrow;
    }
  }

  Future<void> _toggle(Hymn hymn) async {
    if (!hasMusic(hymn)) return;
    if (!isCurrent(current.value, hymn)) {
      final preview = _preview;
      await _stop();
      _preview = preview;
      _recording = !hasMidi(hymn);
    }
    _loadedHymn = hymn;
    if (_nativeActive) return _channelToggle(hymn);
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
      loading.value = true;
      final generation = _stopGeneration;
      final source = await _source(hymn.version, hymn.number);
      if (generation != _stopGeneration) return;
      await _player.play(source);
      await _applySpeed();
    } catch (_) {
      current.value = null;
      rethrow;
    } finally {
      loading.value = false;
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
    AppAnalytics.instance.event('play_transpose',
        variant: s < 0
            ? 'down'
            : s == 0
                ? 'original'
                : 'up');
    transpose.value = s;
    await _restartWithTransform();
  }

  /// Restart the loaded hymn through the current transform and pick up
  /// where it was: same position, same pause state, same speed.
  Future<void> _restartWithTransform() => _enqueue(_restartNow);

  Future<void> _restartNow() async {
    await _republishChords();
    if (_recording) return;
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
      AppAnalytics.instance.event('play_error', variant: 'restart');
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
      AppAnalytics.instance.event('play_error', variant: 'restart');
      current.value = null;
      position.value = Duration.zero;
      duration.value = Duration.zero;
    }
  }

  Future<void> setSpeed(double s) async {
    AppAnalytics.instance.event('play_speed',
        variant: s < 1
            ? 'slow'
            : s == 1
                ? 'normal'
                : 'fast');
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
      if (_nativeActive) {
        await _channel.invokeMethod('setRate', speed.value);
      } else {
        await _player.setPlaybackRate(speed.value);
      }
    } catch (_) {
      AppAnalytics.instance.event('play_error', variant: 'rate');
    }
  }

  /// Jump forward/back by [delta], clamped to the track bounds.
  Future<void> seekBy(Duration delta) async {
    if (current.value == null) return;
    AppAnalytics.instance
        .event('play_seek', variant: delta.isNegative ? 'back' : 'forward');
    final target = position.value + delta;
    final max = duration.value;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (max > Duration.zero && target > max)
            ? max
            : target;
    if (_nativeActive) {
      try {
        await _channel.invokeMethod('seek', _toSeconds(clamped));
      } catch (_) {
        AppAnalytics.instance.event('play_error', variant: 'seek');
      }
    } else {
      try {
        await _player.seek(clamped);
      } catch (_) {
        AppAnalytics.instance.event('play_error', variant: 'seek');
        rethrow;
      }
    }
    position.value = clamped;
  }

  /// Explicit media commands must be idempotent: repeated headset/system events
  /// must never toggle a paused hymn back into playback.
  Future<void> pause() => _setPaused(true);
  Future<void> resume() => _setPaused(false);

  Future<void> _setPaused(bool paused) => _enqueue(() async {
        final cur = current.value;
        if (cur == null || cur.paused == paused) return;
        if (_nativeActive) {
          await _channel.invokeMethod(paused ? 'pause' : 'play');
          if (paused) {
            _stopPositionPolling();
          } else {
            _startPositionPolling();
          }
        } else {
          if (paused) {
            await _player.pause();
          } else {
            await _player.resume();
          }
        }
        // A completion callback may have cleared this track while the command ran.
        if (current.value == cur) {
          current.value = (version: cur.version, n: cur.n, paused: paused);
          if (!paused) await _applySpeed();
          AppAnalytics.instance.event(paused ? 'play_pause' : 'play_resume',
              hymn: cur.n, edition: cur.version);
        }
      });

  Future<void> stop() {
    _stopGeneration++;
    return _enqueue(_stop);
  }

  Future<void> _stop() async {
    _preview = false;
    final stopped = current.value;
    current.value = null;
    if (stopped != null) {
      AppAnalytics.instance
          .event('play_stop', hymn: stopped.n, edition: stopped.version);
    }
    if (_nativeActive) {
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
