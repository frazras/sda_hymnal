// ignore_for_file: file_names

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/fontsize.dart';

/// Hymn reading page (full-screen sub-page, pushed with slideRoute).
///
/// Header: crumb + number/title stack, "Aa" shortcut to Font Size.
/// Body: hymn HTML at the user's font size, max-width 560, centered.
/// Floating player bar: functional prev/next, inert play/key/speed
/// placeholders for upcoming audio features.
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
  }

  @override
  void dispose() {
    // Leaving the page (back, or prev/next replacing it) stops its playback;
    // guarded so it never cuts off a newer page that already started its own.
    MidiPlayer.instance.stopIfCurrent(widget.hymn.number);
    super.dispose();
  }

  /// Navigate to the adjacent hymn: dir = -1 previous, 1 next.
  /// Silently no-ops outside 1..max (new <= 695, old <= 703) or when the
  /// target index is missing from the list.
  void _move(int dir) {
    final n = widget.hymn.number + dir;
    final max = widget.hymn.version == 'new' ? 695 : 703;
    if (n < 1 || n > max) return;
    // Same indexing as before: hymns[number - 2] is prev, hymns[number] is
    // next, i.e. target index n - 1.
    final index = n - 1;
    if (index < 0 || index >= widget.hymns.length) return;
    Navigator.pushReplacement(
      context,
      slideRoute(
        HymnPage(hymn: widget.hymns[index], hymns: widget.hymns),
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
                  trailing: _fontSizeButton(t),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color: t.ink,
                ),
              ),
            ),
          ],
        ),
      ],
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
                _progressLine(t),
                Row(
                  children: [
                    _circleButton(
                      t,
                      onTap: () => _move(-1),
                      icon: HymnalIcons.backChevron(t.ink, size: 16),
                    ),
                    const Spacer(),
                    _seekButton(t, forward: false),
                    const SizedBox(width: 10),
                    _playButton(t),
                    const SizedBox(width: 10),
                    _seekButton(t, forward: true),
                    const SizedBox(width: 10),
                    _speedPill(t),
                    const Spacer(),
                    _circleButton(
                      t,
                      onTap: () => _move(1),
                      icon: HymnalIcons.forwardChevron(t.ink, size: 16),
                    ),
                  ],
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

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

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
              Row(
                children: [
                  for (final (i, s) in _speeds.indexed) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(
                      child: _speedChip(t, s, sheetContext),
                    ),
                  ],
                ],
              ),
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
