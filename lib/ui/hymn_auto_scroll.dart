import 'package:flutter/material.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/analytics.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/prefs.dart';

/// Lets an always-visible reader action open the controls even after the
/// compact speed pill has scrolled out of view.
class HymnAutoScrollController {
  Future<void> Function()? _showControls;

  Future<void> showControls() async => _showControls?.call();

  void _attach(Future<void> Function()? showControls) {
    _showControls = showControls;
  }
}

/// Owns one reader's scroll position and 0..1 song progress. Silent reading
/// uses MIDI duration/speed; audible reading follows the player's timeline.
/// The builder keeps both reader designs on exactly the same behavior.
class HymnAutoScroll extends StatefulWidget {
  const HymnAutoScroll({
    super.key,
    required this.hymn,
    required this.builder,
    this.controller,
    this.previewOnly = false,
  });

  final Hymn hymn;
  final bool previewOnly;
  final HymnAutoScrollController? controller;
  final Widget Function(
    ScrollController controller,
    Widget controls,
  ) builder;

  @override
  State<HymnAutoScroll> createState() => _HymnAutoScrollState();
}

/// Compact launcher plus an on-demand slider. The launcher shares the hymn
/// information line; the larger controls only occupy space while requested.
class HymnAutoScrollControl extends StatelessWidget {
  const HymnAutoScrollControl({
    super.key,
    required this.speed,
    required this.defaultSpeed,
    required this.running,
    required this.canToggle,
    required this.status,
    required this.onToggle,
    required this.onSpeedChanged,
  });

  final double speed;
  final double defaultSpeed;
  final bool running;
  final bool canToggle;
  final String status;
  final VoidCallback onToggle;
  final ValueChanged<double> onSpeedChanged;

  String _label(double value) => '${value.toStringAsFixed(1)}×';

  Future<void> showControls(BuildContext context) async {
    var selectedSpeed = speed;
    var isRunning = running;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, updateSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Auto-scroll speed',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _label(selectedSpeed),
                    key: const ValueKey('hymn-scroll-current-speed'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Slider(
                key: const ValueKey('hymn-scroll-speed-slider'),
                value: selectedSpeed,
                min: 0.5,
                max: 2,
                divisions: 15,
                label: _label(selectedSpeed),
                onChanged: (value) {
                  selectedSpeed = (value * 10).round() / 10;
                  onSpeedChanged(selectedSpeed);
                  updateSheet(() {});
                },
              ),
              DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 12),
                child: const Row(
                  children: [
                    Expanded(child: Text('Slower  0.5×')),
                    Expanded(
                        child: Text('2.0×  Faster', textAlign: TextAlign.end)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    key: const ValueKey('hymn-scroll-speed-reset'),
                    onPressed: selectedSpeed == defaultSpeed
                        ? null
                        : () {
                            selectedSpeed = defaultSpeed;
                            onSpeedChanged(defaultSpeed);
                            updateSheet(() {});
                          },
                    child: Text('Reset to ${_label(defaultSpeed)}'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('hymn-scroll-toggle-sheet-button'),
                    onPressed: isRunning || canToggle
                        ? () {
                            final wasRunning = isRunning;
                            onToggle();
                            if (!wasRunning) {
                              Navigator.of(context).pop();
                            } else {
                              updateSheet(() => isRunning = false);
                            }
                          }
                        : null,
                    icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(isRunning ? 'Pause' : status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _label(speed);
    return Tooltip(
      message: 'Auto-scroll: $current',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => showControls(context),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(running ? Icons.pause : Icons.play_arrow, size: 14),
                const SizedBox(width: 3),
                Text('Scroll $current', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HymnAutoScrollState extends State<HymnAutoScroll>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scroll = ScrollController();
  late final AnimationController _progress;
  final _player = MidiPlayer.instance;
  Duration? _estimated;
  bool _loading = false;
  bool _requested = false;
  bool _choirPractice = MusicOptions.instance.choirPractice;
  bool _followingMusic = false;
  bool _wasLoaded = false;
  bool _visible = true;
  bool _foreground = true;
  bool _metricsPending = false;
  bool _manualScrolling = false;
  bool _reanchoringManual = false;
  double _extent = 0;
  int _loadGeneration = 0;
  late int _speedTenths;
  Duration _musicAnchorPosition = Duration.zero;
  double _musicAnchorProgress = 0;
  double? _pendingLayoutFraction;

  double get _scrollSpeed => _speedTenths / 10;
  int get _defaultSpeedTenths => widget.hymn.version == 'old' ? 13 : 10;

  bool get _enabled => AutoScroll.instance.value;
  bool get _loaded =>
      MidiPlayer.hasMidi(widget.hymn) &&
      MidiPlayer.isCurrent(_player.current.value, widget.hymn);
  Duration? get _duration => _loaded && _player.duration.value > Duration.zero
      ? _player.duration.value
      : _estimated;
  bool get _canRun =>
      _enabled &&
      _visible &&
      _foreground &&
      _duration != null &&
      _duration! > Duration.zero &&
      _extent > 0;

  @override
  void initState() {
    super.initState();
    _speedTenths = _defaultSpeedTenths;
    // Preserve timing even when the OS requests reduced UI animation; this
    // is a user-selected reading speed, not a decorative transition.
    _progress = AnimationController(
        vsync: this, animationBehavior: AnimationBehavior.preserve)
      ..addListener(_applyProgress)
      ..addStatusListener(_onStatus);
    if (widget.previewOnly) return;
    WidgetsBinding.instance.addObserver(this);
    AutoScroll.instance.addListener(_onSetting);
    InstrumentTheme.instance.addListener(_loadTiming);
    MusicOptions.instance.addListener(_onMusicOptionsChanged);
    _player.current.addListener(_onPlayback);
    _player.position.addListener(_syncMusic);
    _player.duration.addListener(_onDuration);
    _player.speed.addListener(_onSpeed);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _loadTiming();
    _onPlayback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Page routes disable ticker mode when this reader is covered. Transient
    // popup menus do not, so opening Reader options does not stop the hymn.
    _visible = TickerMode.valuesOf(context).enabled;
    if (!_visible) _pause(rebuild: false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _pause();
  }

  void _onMusicOptionsChanged() {
    final practice = MusicOptions.instance.choirPractice;
    if (practice == _choirPractice) return;
    _choirPractice = practice;
    _loadTiming();
  }

  Future<void> _loadTiming() async {
    final generation = ++_loadGeneration;
    _pause(rebuild: false);
    _estimated = null;
    _loading = _enabled && MidiPlayer.hasMidi(widget.hymn);
    if (mounted) setState(() {});
    if (!_loading) return;
    final duration = await _player.readingDuration(widget.hymn);
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _estimated = duration;
      _loading = false;
    });
    // Playback may have started while the asset was being read.
    if (_requested && _followingMusic) _syncMusic();
  }

  void _onSetting() {
    _wasLoaded = false;
    _loadTiming();
    _onPlayback();
  }

  void _pause({bool rebuild = true, bool preserveFraction = false}) {
    if (_requested) AppAnalytics.instance.event('auto_scroll_pause');
    if (_requested && preserveFraction) {
      _pendingLayoutFraction = _progress.value;
    }
    _progress.stop();
    _manualScrolling = false;
    _requested = false;
    if (rebuild && mounted) setState(() {});
  }

  void _beginManualScroll() {
    if (!_requested || _manualScrolling) return;
    AppAnalytics.instance.event('auto_scroll_correct');
    _manualScrolling = true;
    _progress.stop();
  }

  void _endManualScroll() {
    if (!_manualScrolling) return;
    _manualScrolling = false;
    if (!_requested || !_scroll.hasClients || _extent <= 0) return;
    final fraction = (_scroll.offset / _extent).clamp(0.0, 1.0);
    // Assigning exactly 1.0 normally marks silent scrolling complete. A user
    // can touch the bottom while adjusting, though, then move back upward.
    // Keep the active intent armed so that later adjustments still resume.
    _reanchoringManual = true;
    _progress.value = fraction;
    _reanchoringManual = false;
    if (_followingMusic && _loaded) {
      _musicAnchorPosition = _player.position.value;
      _musicAnchorProgress = fraction;
      _syncMusic();
    } else if (fraction < 1) {
      _runSilent();
    }
    if (mounted) setState(() {});
  }

  void _onPlayback() {
    final loaded = _loaded;
    if (_enabled && loaded && !_wasLoaded && _visible && _foreground) {
      _musicAnchorPosition = Duration.zero;
      _musicAnchorProgress = 0;
      _followingMusic = true;
      _requested = true;
    } else if (!loaded && _wasLoaded) {
      final completed = _player.duration.value > Duration.zero &&
          _player.position.value >= _player.duration.value;
      final finishReading = completed && _requested && _progress.value < 1;
      // Keep the final offset when the player clears its timeline. Never
      // rewind the lyrics just because playback stopped or completed.
      _followingMusic = false;
      if (finishReading) {
        // A slower reading pace may outlast the music. Finish the remaining
        // lyrics with the same pace, without restarting audio or jumping down.
        _estimated ??= _player.duration.value;
        _runSilent();
      } else {
        _pause(rebuild: false, preserveFraction: true);
      }
    }
    _wasLoaded = loaded;
    if (_followingMusic) _syncMusic();
    if (mounted) setState(() {});
  }

  void _onDuration() {
    if (_followingMusic) _syncMusic();
    if (mounted) setState(() {});
  }

  void _onSpeed() {
    if (_requested && !_followingMusic) _runSilent();
    if (mounted) setState(() {});
  }

  void _changeScrollSpeed(int tenths) {
    AppAnalytics.instance.event('auto_scroll_speed',
        variant: tenths < 10
            ? 'slow'
            : tenths == 10
                ? 'normal'
                : 'fast');
    final next = tenths.clamp(5, 20);
    if (next == _speedTenths) return;
    // Anchor a new slope at the current reading position, rather than
    // multiplying all elapsed time and jumping when +/- is tapped.
    if (_loaded) {
      if (_followingMusic) _progress.stop();
      _musicAnchorPosition = _player.position.value;
      _musicAnchorProgress = _requested || !_scroll.hasClients || _extent <= 0
          ? _progress.value
          : (_scroll.offset / _extent).clamp(0.0, 1.0);
    }
    _speedTenths = next;
    if (_requested && !_followingMusic) _runSilent();
    setState(() {});
  }

  void _syncMusic() {
    if (_manualScrolling ||
        !_requested ||
        !_followingMusic ||
        !_loaded ||
        !_canRun) {
      return;
    }
    final fraction = (_musicAnchorProgress +
            (_player.position.value - _musicAnchorPosition).inMicroseconds /
                _duration!.inMicroseconds *
                _scrollSpeed)
        .clamp(0.0, 1.0);
    if (_player.current.value!.paused ||
        fraction == 1 ||
        fraction < _progress.value) {
      // Pauses, backward seeks and completion must land exactly, without
      // an animation that could continue after the player stops.
      _progress.value = fraction;
    } else {
      _progress.animateTo(fraction,
          duration: const Duration(milliseconds: 150), curve: Curves.linear);
    }
  }

  void _runSilent() {
    if (_manualScrolling || !_canRun || !_requested) return;
    _progress.duration = Duration(
        microseconds:
            (_duration!.inMicroseconds / (_player.speed.value * _scrollSpeed))
                .round());
    _progress.forward();
  }

  void _start() {
    if (!_canRun || !_scroll.hasClients) return;
    AppAnalytics.instance
        .event('auto_scroll_start', variant: _loaded ? 'music' : 'silent');
    _followingMusic = _loaded;
    _requested = true;
    if (_followingMusic) {
      if (_speedTenths != 10 || _musicAnchorPosition != Duration.zero) {
        _musicAnchorPosition = _player.position.value;
        _musicAnchorProgress = (_scroll.offset / _extent).clamp(0.0, 1.0);
      }
      _syncMusic();
    } else {
      final fraction = (_scroll.offset / _extent).clamp(0.0, 1.0);
      _progress.value = fraction >= 0.999 ? 0 : fraction;
      _runSilent();
    }
    setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        !_followingMusic &&
        !_reanchoringManual) {
      AppAnalytics.instance.event('auto_scroll_complete');
      _pendingLayoutFraction = 1;
      _requested = false;
      if (mounted) setState(() {});
    }
  }

  void _applyProgress() {
    if (_manualScrolling ||
        !_scroll.hasClients ||
        !_requested ||
        !_visible ||
        !_foreground) {
      return;
    }
    _jumpToFraction(_progress.value);
  }

  void _jumpToFraction(double fraction) {
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final target = position.maxScrollExtent * fraction;
    if ((position.pixels - target).abs() > 0.01) _scroll.jumpTo(target);
  }

  void _scheduleMetrics() {
    if (_metricsPending) return;
    _metricsPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsPending = false;
      if (!mounted || !_scroll.hasClients) return;
      final extent = _scroll.position.maxScrollExtent;
      final pendingFraction = _pendingLayoutFraction;
      _pendingLayoutFraction = null;
      if (pendingFraction != null) _jumpToFraction(pendingFraction);
      if (_extent == extent) return;
      final couldRun = _canRun;
      setState(() => _extent = extent);
      // Re-map the same song fraction after rotation, font size, or player
      // panel changes. Do not restart the timer or use an obsolete distance.
      if (_requested) {
        _applyProgress();
        if (_followingMusic && !couldRun) _syncMusic();
        if (_extent <= 0) _pause();
      }
    });
  }

  @override
  void dispose() {
    ++_loadGeneration;
    WidgetsBinding.instance.removeObserver(this);
    AutoScroll.instance.removeListener(_onSetting);
    InstrumentTheme.instance.removeListener(_loadTiming);
    MusicOptions.instance.removeListener(_onMusicOptionsChanged);
    _player.current.removeListener(_onPlayback);
    _player.position.removeListener(_syncMusic);
    _player.duration.removeListener(_onDuration);
    _player.speed.removeListener(_onSpeed);
    _progress.dispose();
    _scroll.dispose();
    widget.controller?._attach(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewOnly) {
      return widget.builder(
          _scroll, _buildControls(context, 'Start auto-scroll'));
    }
    _scheduleMetrics();
    final startTooltip = !MidiPlayer.hasMidi(widget.hymn)
        ? 'Auto-scroll unavailable: no MIDI'
        : _loading
            ? 'Loading auto-scroll timing…'
            : _duration == null || _duration! <= Duration.zero
                ? 'Auto-scroll unavailable: no MIDI timing'
                : _extent <= 0
                    ? 'Entire hymn fits on screen'
                    : _followingMusic &&
                            _requested &&
                            _player.current.value?.paused == true
                        ? 'Auto-scroll • music paused'
                        : 'Start auto-scroll';
    final controls = _buildControls(context, startTooltip);
    widget.controller?._attach(controls is HymnAutoScrollControl
        ? () => controls.showControls(context)
        : null);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _scheduleMetrics();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // ScrollStart can occasionally arrive without drag details after a
          // ballistic transition. ScrollUpdate/Overscroll retain the direct
          // touch details, so use all three to recognize repeated adjustments.
          if ((notification is ScrollStartNotification &&
                  notification.dragDetails != null) ||
              (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null) ||
              (notification is OverscrollNotification &&
                  notification.dragDetails != null)) {
            _beginManualScroll();
          } else if (notification is ScrollEndNotification) {
            _endManualScroll();
          }
          return false;
        },
        child: Listener(
          onPointerSignal: (_) {
            _beginManualScroll();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _endManualScroll();
            });
          },
          child: widget.builder(_scroll, controls),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, String startTooltip) {
    if (!_enabled || !MidiPlayer.hasMidi(widget.hymn)) {
      return const SizedBox.shrink();
    }
    return HymnAutoScrollControl(
      key: const ValueKey('hymn-auto-scroll-toggle'),
      speed: _scrollSpeed,
      defaultSpeed: _defaultSpeedTenths / 10,
      running: _requested,
      canToggle: _requested || _canRun,
      status: startTooltip,
      onToggle: () => _requested ? _pause(preserveFraction: true) : _start(),
      onSpeedChanged: (speed) => _changeScrollSpeed((speed * 10).round()),
    );
  }
}
