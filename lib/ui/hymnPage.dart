// ignore_for_file: file_names

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/chord_detect.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/fontsize.dart';

/// Hymn reading page (full-screen sub-page, pushed with slideRoute).
///
/// Header: crumb + number/title stack, favorite heart, "Aa" shortcut.
/// Body: hymn HTML at the user's font size, max-width 560, centered.
/// Floating player bar: prev/next, key pill (transpose sheet), seek ±10,
/// play/pause, speed pill — key/play/speed dimmed on Old-Hymnal pages.
class HymnPage extends StatefulWidget {
  final Hymn hymn;
  final List<Hymn> hymns;

  const HymnPage({super.key, required this.hymn, required this.hymns});

  @override
  State<HymnPage> createState() => _HymnPageState();
}

class _HymnPageState extends State<HymnPage> {
  /// Accumulated horizontal drag distance for the swipe gesture.
  double _dragDx = 0;

  @override
  void initState() {
    super.initState();
    // Single recents recording point: every open (keypad, search, chip) and
    // every prev/next/swipe move constructs a new HymnPage, so this covers
    // them all.
    Recents.instance.push(widget.hymn);
    // Publishes this hymn's written key for the key pill and resets the
    // transposition when the page moved to a different hymn.
    MidiPlayer.instance.prepareKey(widget.hymn);
  }

  @override
  void dispose() {
    // Leaving the page (back, or prev/next replacing it) stops its playback;
    // guarded so it never cuts off a newer page that already started its own.
    MidiPlayer.instance.stopIfCurrent(widget.hymn.number);
    super.dispose();
  }

  /// Navigate to the adjacent hymn: dir = -1 previous, 1 next.
  /// Silently no-ops at the ends of the hymnal (new <= 695, old <= 703).
  /// Numbers the hymnal does not carry are stepped over rather than landed
  /// on — see [adjacentHymn].
  void _move(int dir) {
    final max = widget.hymn.version == 'new' ? 695 : 703;
    final target = adjacentHymn(widget.hymns, widget.hymn.number, dir, max);
    if (target == null) return;
    Navigator.pushReplacement(
      context,
      slideRoute(
        HymnPage(hymn: target, hymns: widget.hymns),
        fromLeft: dir < 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        },
        child: Focus(
          autofocus: true,
          child: SafeArea(
            child: Column(
              children: [
                SubPageHeader(
                  center: _headerCenter(t),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _favoriteButton(t),
                      _fontSizeButton(t),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _scrollArea(t)),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 18,
                        child: _playerBar(t),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  Widget _headerCenter(HymnalTokens t) {
    final crumb =
        widget.hymn.version == 'new' ? 'NEW HYMNAL' : 'OLD HYMNAL';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          crumb,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: trackingEm(0.14, 10),
            color: t.muted,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${widget.hymn.number}',
              style: TextStyle(
                fontFamily: kSerif,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                widget.hymn.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: t.ink,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Heart toggle: accent + filled while this hymn is favorited, muted
  /// outline otherwise. Re-renders via the Favorites notifier.
  Widget _favoriteButton(HymnalTokens t) {
    return ValueListenableBuilder<List<({int n, String v})>>(
      valueListenable: Favorites.instance,
      builder: (context, _, __) {
        final favorited = Favorites.instance
            .contains(widget.hymn.number, widget.hymn.version);
        return Pressable(
          onTap: () => Favorites.instance.toggle(widget.hymn),
          pressedScale: 1.0,
          builder: (context, pressed) => Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pressed ? t.surface2 : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: HymnalIcons.heart(
              favorited ? t.accent : t.muted,
              filled: favorited,
            ),
          ),
        );
      },
    );
  }

  Widget _fontSizeButton(HymnalTokens t) {
    return Pressable(
      onTap: () => Navigator.push(context, slideRoute(const FontSizer())),
      pressedScale: 1.0,
      builder: (context, pressed) => Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? t.surface2 : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Aa',
          style: TextStyle(
            fontFamily: kSerif,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: t.muted,
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Body
  // -------------------------------------------------------------------------

  Widget _scrollArea(HymnalTokens t) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragDx = 0,
      onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDx > 40) {
          _move(-1); // swipe right = previous
        } else if (_dragDx < -40) {
          _move(1); // swipe left = next
        }
      },
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 150),
              child: ValueListenableBuilder<double>(
                valueListenable: FontSizeController.instance,
                builder: (context, fontSize, _) => Html(
                  data: styleHymnBody(widget.hymn.body, t, fontSize),
                  style: {
                    'html': Style(
                      fontFamily: kSerif,
                      fontSize: FontSize(fontSize),
                      lineHeight: const LineHeight(1.7),
                      color: t.ink,
                    ),
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Floating player bar
  // -------------------------------------------------------------------------

  Widget _playerBar(HymnalTokens t) {
    return Container(
      // Shadow lives outside the clip so it is not cut off by ClipRRect.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: t.barShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.barBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chordStrip(t),
                _progressLine(t),
                // FittedBox lets the whole control strip scale down as one
                // unit on narrow screens instead of overflowing.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _circleButton(
                        t,
                        onTap: () => _move(-1),
                        icon: HymnalIcons.backChevron(t.ink, size: 16),
                      ),
                      const SizedBox(width: 10),
                      _keyPill(t),
                      const SizedBox(width: 10),
                      _seekButton(t, forward: false),
                      const SizedBox(width: 10),
                      _playButton(t),
                      const SizedBox(width: 10),
                      _seekButton(t, forward: true),
                      const SizedBox(width: 10),
                      _speedPill(t),
                      const SizedBox(width: 10),
                      _circleButton(
                        t,
                        onTap: () => _move(1),
                        icon: HymnalIcons.forwardChevron(t.ink, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thin progress line across the bar while this hymn's MIDI is loaded.
  Widget _progressLine(HymnalTokens t) {
    return ValueListenableBuilder<({int n, bool paused})?>(
      valueListenable: MidiPlayer.instance.current,
      builder: (context, cur, _) {
        if (cur == null || cur.n != widget.hymn.number) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ValueListenableBuilder<Duration>(
            valueListenable: MidiPlayer.instance.duration,
            builder: (context, dur, _) => ValueListenableBuilder<Duration>(
              valueListenable: MidiPlayer.instance.position,
              builder: (context, pos, _) {
                final frac = dur.inMilliseconds > 0
                    ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                    : 0.0;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 3,
                    color: t.surface2,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(color: t.accent),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Chord tabs (live strip + chart sheet)
  // -------------------------------------------------------------------------

  /// Live chord strip above the progress line: the current chord and the next
  /// two, sliding left as playback advances. Shown only when the Chord-tabs
  /// setting is on and this hymn's tune yielded a chord track; before play it
  /// previews the opening chords. Tap opens the full chord chart sheet.
  Widget _chordStrip(HymnalTokens t) {
    if (!MidiPlayer.hasMidi(widget.hymn)) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: ChordTabs.instance,
      builder: (context, enabled, _) {
        if (!enabled) return const SizedBox.shrink();
        return ValueListenableBuilder<ChordTrack?>(
          valueListenable: MidiPlayer.instance.chordTrack,
          builder: (context, raw, _) {
            if (raw == null) return const SizedBox.shrink();
            return ValueListenableBuilder<String>(
              valueListenable: ChordLevelPref.instance,
              builder: (context, _, __) {
                // Simplified once per track/level change (not per position
                // tick); slots, indexAt sync and beat dots all read it.
                final track =
                    simplifyTrack(raw, ChordLevelPref.instance.level);
                return ValueListenableBuilder<({int n, bool paused})?>(
                  valueListenable: MidiPlayer.instance.current,
                  builder: (context, cur, _) => ValueListenableBuilder<int>(
                    valueListenable: MidiPlayer.instance.transpose,
                    builder: (context, semis, _) =>
                        ValueListenableBuilder<Duration>(
                      valueListenable: MidiPlayer.instance.position,
                      builder: (context, pos, _) {
                        final loaded =
                            cur != null && cur.n == widget.hymn.number;
                        final at =
                            loaded ? track.indexAt(pos.inMilliseconds) : 0;
                        final index = at < 0 ? 0 : at;
                        return Pressable(
                          onTap: () => _showChordSheet(t),
                          pressedScale: 0.98,
                          builder: (context, pressed) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              height: 36,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) {
                                  // Incoming slides in from the right; the
                                  // outgoing child (reversed animation)
                                  // slides out to the left — the row reads
                                  // as sliding left on each chord hit.
                                  final incoming =
                                      child.key == ValueKey<int>(index);
                                  final slide = Tween<Offset>(
                                    begin:
                                        Offset(incoming ? 0.35 : -0.35, 0),
                                    end: Offset.zero,
                                  );
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: animation.drive(slide),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Row(
                                  key: ValueKey<int>(index),
                                  children: [
                                    for (var slot = 0; slot < 3; slot++)
                                      Expanded(
                                        child: _chordSlot(
                                            t,
                                            track,
                                            index + slot,
                                            slot,
                                            semis,
                                            loaded
                                                ? pos.inMilliseconds
                                                : -1),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// One fixed-width strip slot: 0 = current chord (accent pill), 1 and 2 =
  /// the upcoming chords, visibly receding. Empty past the end of the track.
  /// A chord held across several beats shows one dot per repeat; on the
  /// current chord each dot lights as its beat strikes ([positionMs] is -1
  /// when this hymn is not the one loaded).
  Widget _chordSlot(HymnalTokens t, ChordTrack track, int i, int slot,
      int semis, int positionMs) {
    if (i >= track.chords.length) return const SizedBox.shrink();
    final e = track.chords[i];
    final label = chordLabel(e.rootPc, e.quality, track.key, semis);
    final repeats = e.beatMs.length - 1;
    if (slot == 0) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
                if (repeats > 0) const SizedBox(width: 6),
                for (var k = 1; k <= repeats; k++) ...[
                  if (k > 1) const SizedBox(width: 3),
                  _beatDot(
                    // Lit once its beat has struck.
                    positionMs >= 0 && positionMs >= e.beatMs[k]
                        ? t.accent
                        : t.accent.withValues(alpha: 0.25),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    final tone = slot == 1 ? t.muted : t.faint;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: slot == 1 ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: tone,
              ),
            ),
            if (repeats > 0) const SizedBox(width: 5),
            for (var k = 1; k <= repeats; k++) ...[
              if (k > 1) const SizedBox(width: 3),
              _beatDot(tone.withValues(alpha: 0.35)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _beatDot(Color color) => Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  /// Chord chart sheet (same visual pattern as the speed sheet, but taller
  /// and scrollable): the whole tune as a measure grid, four bars per row,
  /// with the playing measure highlighted live. Relabels on transpose.
  void _showChordSheet(HymnalTokens t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
          ),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF171E1A) : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ValueListenableBuilder<ChordTrack?>(
            valueListenable: MidiPlayer.instance.chordTrack,
            builder: (context, raw, _) {
              if (raw == null) return const SizedBox.shrink();
              return ValueListenableBuilder<String>(
                valueListenable: ChordLevelPref.instance,
                builder: (context, _, __) {
                  // The chart reads the same simplified track as the strip,
                  // so bars, labels and beat dots track the level live.
                  final track =
                      simplifyTrack(raw, ChordLevelPref.instance.level);
                  return ValueListenableBuilder<int>(
                    valueListenable: MidiPlayer.instance.transpose,
                    builder: (context, semis, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SectionLabel('CHORDS'),
                            const Spacer(),
                            Text(
                              _chordMeta(track, semis),
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 12,
                                color: t.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Flexible(child: _measureGrid(t, track, semis)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Sheet meta line: 'Key of G · 4/4' (key part omitted when the file has
  /// no key signature); the key relabels with the transposition.
  String _chordMeta(ChordTrack track, int semis) {
    final key = track.key;
    final meter = '${track.beatsPerBar}/4';
    return key == null
        ? meter
        : 'Key of ${transposedKeyLabel(key, semis)} · $meter';
  }

  /// Scrollable measure grid: one cell per measure, four per row, barline on
  /// the left edge of each cell. Each cell is a beat grid — every chord beat
  /// onset in the measure's window, sorted by time — so its symbols always
  /// add up to the bar's beats. The measure under the playhead is highlighted
  /// while this hymn is loaded and pulses beat by beat.
  Widget _measureGrid(HymnalTokens t, ChordTrack track, int semis) {
    final measures = List.generate(
        track.measureStartMs.length, (_) => <_MeasureBeat>[]);
    if (measures.isNotEmpty) {
      for (final e in track.chords) {
        for (final b in e.beatMs) {
          final m = track.measureAt(b);
          measures[m < 0 ? 0 : m]
              .add((ms: b, onset: b == e.beatMs.first, chord: e));
        }
      }
      for (final beats in measures) {
        beats.sort((a, b) => a.ms - b.ms);
      }
    }
    return ValueListenableBuilder<({int n, bool paused})?>(
      valueListenable: MidiPlayer.instance.current,
      builder: (context, cur, _) => ValueListenableBuilder<Duration>(
        valueListenable: MidiPlayer.instance.position,
        builder: (context, pos, _) {
          final loaded = cur != null && cur.n == widget.hymn.number;
          final at = loaded ? track.measureAt(pos.inMilliseconds) : -1;
          return GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 2.2,
            ),
            itemCount: measures.length,
            itemBuilder: (context, i) => _measureCell(
                t, measures[i], track.key, semis,
                current: i == at,
                positionMs: loaded ? pos.inMilliseconds : -1),
          );
        },
      ),
    );
  }

  /// One measure cell: a symbol per beat — the chord label on its onset beat,
  /// a dot for every further beat it is held — with the left border as the
  /// barline. In the current measure, symbols light up in accent as their
  /// beats strike ([positionMs] is -1 when this hymn is not the one loaded).
  Widget _measureCell(
    HymnalTokens t,
    List<_MeasureBeat> beats,
    MidiKey? key,
    int semis, {
    required bool current,
    required int positionMs,
  }) {
    Color tone(int ms, {required bool dot}) {
      if (current) {
        return ms <= positionMs
            ? t.accent
            : t.accent.withValues(alpha: 0.35);
      }
      return dot ? t.ink.withValues(alpha: 0.35) : t.ink;
    }

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: current ? t.tint : Colors.transparent,
        border: Border(left: BorderSide(color: t.line2)),
      ),
      child: beats.isEmpty
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var k = 0; k < beats.length; k++) ...[
                    if (k > 0) const SizedBox(width: 5),
                    // A chord carried over the barline is spelled out when it
                    // is the bar's first symbol; dots are only ever holds
                    // WITHIN the bar.
                    if (k == 0 || beats[k].onset)
                      Text(
                        chordLabel(beats[k].chord.rootPc,
                            beats[k].chord.quality, key, semis),
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: tone(beats[k].ms, dot: false),
                        ),
                      )
                    else
                      _beatDot(tone(beats[k].ms, dot: true)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _seekButton(HymnalTokens t, {required bool forward}) {
    final canPlay = MidiPlayer.hasMidi(widget.hymn);
    return Opacity(
      opacity: canPlay ? 1.0 : 0.45,
      child: Pressable(
        onTap: canPlay
            ? () => MidiPlayer.instance
                .seekBy(Duration(seconds: forward ? 10 : -10))
            : null,
        pressedScale: 0.92,
        builder: (context, pressed) => Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: t.surface2, shape: BoxShape.circle),
          child: HymnalIcons.seek10(t.ink, forward: forward, size: 20),
        ),
      ),
    );
  }

  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  static String _speedLabel(double s) =>
      '${s == s.roundToDouble() ? s.round() : s}×';

  /// Current-speed pill (mockup's "1.0×" placeholder, now live): tap opens
  /// the speed picker sheet.
  Widget _speedPill(HymnalTokens t) {
    final canPlay = MidiPlayer.hasMidi(widget.hymn);
    return Opacity(
      opacity: canPlay ? 1.0 : 0.45,
      child: ValueListenableBuilder<double>(
        valueListenable: MidiPlayer.instance.speed,
        builder: (context, speed, _) => Pressable(
          onTap: canPlay ? () => _showSpeedSheet(t) : null,
          pressedScale: 0.95,
          builder: (context, pressed) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: speed == 1.0 ? t.surface2 : t.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _speedLabel(speed),
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: speed == 1.0 ? t.muted : t.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSpeedSheet(HymnalTokens t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF171E1A) : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAYBACK SPEED',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: trackingEm(0.14, 11),
                  color: t.muted,
                ),
              ),
              const SizedBox(height: 14),
              // Eight speeds flow as two rows of four; the slow half is for
              // learning parts, the fast half for review.
              for (final row in [
                _speeds.sublist(0, 4),
                _speeds.sublist(4)
              ]) ...[
                Row(
                  children: [
                    for (final (i, s) in row.indexed) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: _speedChip(t, s, sheetContext),
                      ),
                    ],
                  ],
                ),
                if (row.first == _speeds.first) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedChip(HymnalTokens t, double s, BuildContext sheetContext) {
    final selected = MidiPlayer.instance.speed.value == s;
    return Pressable(
      onTap: () {
        MidiPlayer.instance.setSpeed(s);
        Navigator.pop(sheetContext);
      },
      pressedScale: 0.95,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.accent : Colors.transparent,
          border: Border.all(color: selected ? t.accent : t.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _speedLabel(s),
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? t.onAccent : t.muted,
          ),
        ),
      ),
    );
  }

  /// Current-key pill: shows the (possibly transposed) key of this hymn's
  /// tune; tap opens the transpose sheet. Dimmed and inert on Old-Hymnal
  /// pages, like the play button.
  Widget _keyPill(HymnalTokens t) {
    final canPlay = MidiPlayer.hasMidi(widget.hymn);
    return Opacity(
      opacity: canPlay ? 1.0 : 0.45,
      child: ValueListenableBuilder<MidiKey?>(
        valueListenable: MidiPlayer.instance.originalKey,
        builder: (context, key, _) => ValueListenableBuilder<int>(
          valueListenable: MidiPlayer.instance.transpose,
          builder: (context, semis, _) {
            final shifted = semis != 0;
            final label = key != null
                ? 'Key · ${transposedKeyLabel(key, semis)}'
                : shifted
                    ? '${semis > 0 ? '+' : ''}$semis st'
                    : 'Key';
            return Pressable(
              onTap: canPlay ? () => _showKeySheet(t) : null,
              pressedScale: 0.95,
              builder: (context, pressed) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: shifted ? t.tint : t.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: shifted ? t.accent : t.muted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Transpose sheet: −/+ steppers around the current key, live (-6..+6,
  /// each tap re-renders playback immediately; the sheet stays open and
  /// rebuilds off the transpose notifier).
  void _showKeySheet(HymnalTokens t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF171E1A) : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: MidiPlayer.instance.transpose,
            builder: (context, semis, _) {
              final key = MidiPlayer.instance.originalKey.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'KEY',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: trackingEm(0.14, 11),
                          color: t.muted,
                        ),
                      ),
                      const Spacer(),
                      if (semis != 0)
                        Pressable(
                          onTap: () => MidiPlayer.instance.setTranspose(0),
                          pressedScale: 0.95,
                          builder: (context, pressed) => Text(
                            'Reset',
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: t.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _keyStepper(t, semis: semis, delta: -1),
                      Expanded(child: _keyReadout(t, key, semis)),
                      _keyStepper(t, semis: semis, delta: 1),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Center of the transpose sheet: big current key, shift indicator when
  /// transposed, and the written key underneath.
  Widget _keyReadout(HymnalTokens t, MidiKey? key, int semis) {
    final big = key != null
        ? transposedKeyLabel(key, semis)
        : semis != 0
            ? '${semis > 0 ? '+' : ''}$semis st'
            : '±0';
    return Column(
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: big,
              style: TextStyle(
                fontFamily: kSerif,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: t.accent,
              ),
            ),
            if (key != null && semis != 0)
              TextSpan(
                text: '  (${semis > 0 ? '+' : ''}$semis)',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
          ]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          'Original · ${key?.label ?? '—'}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 11.5,
            color: t.muted,
          ),
        ),
      ],
    );
  }

  /// −/+ stepper (42px surface2 circle); dimmed and inert at the -6/+6 ends.
  Widget _keyStepper(HymnalTokens t, {required int semis, required int delta}) {
    final target = semis + delta;
    final enabled = target >= -6 && target <= 6;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Pressable(
        onTap:
            enabled ? () => MidiPlayer.instance.setTranspose(target) : null,
        pressedScale: 0.92,
        builder: (context, pressed) => Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
          child: Text(
            delta < 0 ? '−' : '+',
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: t.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(HymnalTokens t,
      {required VoidCallback onTap, required Widget icon}) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.92,
      builder: (context, pressed) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.surface2, shape: BoxShape.circle),
        child: icon,
      ),
    );
  }

  Widget _playButton(HymnalTokens t) {
    // MIDI exists for the New Hymnal only; Old-Hymnal pages show the button
    // dimmed and inert.
    final canPlay = MidiPlayer.hasMidi(widget.hymn);
    return ValueListenableBuilder<({int n, bool paused})?>(
      valueListenable: MidiPlayer.instance.current,
      builder: (context, cur, _) {
        final isPlaying = canPlay &&
            cur != null &&
            cur.n == widget.hymn.number &&
            !cur.paused;
        return Opacity(
          opacity: canPlay ? 1.0 : 0.45,
          child: Pressable(
            onTap: canPlay
                ? () => MidiPlayer.instance.toggle(widget.hymn)
                : null,
            pressedScale: 0.92,
            builder: (context, pressed) => Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.accent,
                shape: BoxShape.circle,
                boxShadow: t.playShadow,
              ),
              child: isPlaying
                  ? HymnalIcons.pauseBars(t.onAccent)
                  : HymnalIcons.playTriangle(t.onAccent),
            ),
          ),
        );
      },
    );
  }

}

/// One beat slot of a chord-chart measure cell: the beat's media-time ms,
/// whether it is the chord's onset beat (label) or a hold beat (dot), and the
/// chord sounding on it.
typedef _MeasureBeat = ({int ms, bool onset, ChordEvent chord});
