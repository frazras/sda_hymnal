// ignore_for_file: file_names

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:sdahymnal/models/hymn.dart';
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
            child: Row(
              children: [
                _circleButton(
                  t,
                  onTap: () => _move(-1),
                  icon: HymnalIcons.backChevron(t.ink, size: 16),
                ),
                const Spacer(),
                _pill(
                  'Key · F',
                  color: t.accent,
                  background: t.tint,
                  letterSpacing: trackingEm(0.06, 11.5),
                ),
                const SizedBox(width: 10),
                _playButton(t),
                const SizedBox(width: 10),
                _pill('1.0×', color: t.muted, background: t.surface2),
                const Spacer(),
                _circleButton(
                  t,
                  onTap: () => _move(1),
                  icon: HymnalIcons.forwardChevron(t.ink, size: 16),
                ),
              ],
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
    return Pressable(
      // Inert placeholder for upcoming audio features: press feedback only,
      // no action wired.
      onTap: () {},
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
        child: HymnalIcons.playTriangle(t.onAccent),
      ),
    );
  }

  Widget _pill(String text,
      {required Color color,
      required Color background,
      double? letterSpacing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: letterSpacing,
          color: color,
        ),
      ),
    );
  }
}
