import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sdahymnal/theme.dart';

// ---------------------------------------------------------------------------
// Color helpers for templated SVG icons
// ---------------------------------------------------------------------------

String _rgb(Color c) {
  String two(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${two((c.r * 255).round())}${two((c.g * 255).round())}${two((c.b * 255).round())}';
}

String _op(Color c) => (c.a).toStringAsFixed(3);

// ---------------------------------------------------------------------------
// Pressable: flat press feedback (scale and/or pressed styling), no ripple
// ---------------------------------------------------------------------------

class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final double pressedScale;
  final Widget Function(BuildContext context, bool pressed) builder;

  const Pressable({
    super.key,
    required this.onTap,
    this.pressedScale = 0.95,
    required this.builder,
  });

  /// Convenience for children that only scale while pressed.
  Pressable.child({
    super.key,
    required this.onTap,
    this.pressedScale = 0.95,
    required Widget child,
  }) : builder = ((_, __) => child);

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v && widget.onTap != null) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 80),
        child: widget.builder(context, _pressed),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icons — exact geometry from the mockups, colors from tokens
// ---------------------------------------------------------------------------

class HymnalIcons {
  HymnalIcons._();

  static Widget _svg(String markup, double w, double h) =>
      SvgPicture.string(markup, width: w, height: h);

  /// Organ-pipe logo mark (tile + three pipes).
  static Widget logoMark(HymnalTokens t, {double size = 26}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 26 26">
<rect width="26" height="26" rx="7" fill="${_rgb(t.markTile)}" fill-opacity="${_op(t.markTile)}"/>
<rect x="6.5" y="10" width="2.6" height="9" rx="1.3" fill="${_rgb(t.markPipe)}"/>
<rect x="11.7" y="6.5" width="2.6" height="12.5" rx="1.3" fill="${_rgb(t.markPipe)}"/>
<rect x="16.9" y="12" width="2.6" height="7" rx="1.3" fill="${_rgb(t.markPipe2)}"/>
</svg>''', size, size);

  static Widget backChevron(Color c, {double size = 20, double stroke = 1.8}) =>
      _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none">
<path d="M12.5 4 L6.5 10 L12.5 16" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''', size, size);

  static Widget forwardChevron(Color c,
          {double size = 16, double stroke = 1.8}) =>
      _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="none">
<path d="M7.5 4 L13.5 10 L7.5 16" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''', size, size);

  /// List/row chevron (16 preview cards, 15 settings rows, 14 search rows).
  static Widget rowChevron(Color c, {double size = 16}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="none">
<path d="M6 3.5 L10.5 8 L6 12.5" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''', size, size);

  static Widget playTriangle(Color c, {double size = 16}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
<path d="M5.5 3.5 L12 8 L5.5 12.5 Z" fill="${_rgb(c)}"/>
</svg>''', size, size);

  /// Skip-10-seconds arc arrow (backward when [forward] is false) with a
  /// small "10" set inside the arc.
  static Widget seek10(Color c, {required bool forward, double size = 22}) {
    final arc = forward
        ? '<path d="M11 5 A7 7 0 1 1 4 12" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
            '<path d="M11 5 L7.8 2.6 M11 5 L7.8 7.4" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
        : '<path d="M11 5 A7 7 0 1 0 18 12" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
            '<path d="M11 5 L14.2 2.6 M11 5 L14.2 7.4" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" fill="none" stroke-linecap="round"/>';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _svg(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22">$arc</svg>',
              size,
              size),
          Padding(
            padding: EdgeInsets.only(top: size * 0.14),
            child: Text(
              '10',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget pauseBars(Color c, {double size = 16}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
<rect x="4.2" y="3.5" width="2.6" height="9" rx="1.3" fill="${_rgb(c)}"/>
<rect x="9.2" y="3.5" width="2.6" height="9" rx="1.3" fill="${_rgb(c)}"/>
</svg>''', size, size);

  static Widget clearX(Color c, {double size = 18}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" fill="none">
<path d="M4.5 4.5 L13.5 13.5 M13.5 4.5 L4.5 13.5" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" stroke-linecap="round"/>
</svg>''', size, size);

  static Widget backspace(Color c, {double width = 24, double height = 20}) =>
      _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 20" fill="none">
<path d="M8.5 3.5 H20 V16.5 H8.5 L3 10 Z" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" stroke-linejoin="round"/>
<path d="M11.5 7.5 L16.5 12.5 M16.5 7.5 L11.5 12.5" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.5" stroke-linecap="round"/>
</svg>''', width, height);

  static Widget navNumbers(Color c, {double size = 22}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22">
<circle cx="5.5" cy="5.5" r="1.8" fill="${_rgb(c)}"/>
<circle cx="11" cy="5.5" r="1.8" fill="${_rgb(c)}"/>
<circle cx="16.5" cy="5.5" r="1.8" fill="${_rgb(c)}"/>
<circle cx="5.5" cy="11" r="1.8" fill="${_rgb(c)}"/>
<circle cx="11" cy="11" r="1.8" fill="${_rgb(c)}"/>
<circle cx="16.5" cy="11" r="1.8" fill="${_rgb(c)}"/>
<circle cx="11" cy="16.5" r="1.8" fill="${_rgb(c)}"/>
</svg>''', size, size);

  static Widget magnifier(Color c, {double size = 22, double stroke = 1.6}) =>
      _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" fill="none">
<circle cx="10" cy="10" r="6" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="$stroke"/>
<path d="M14.5 14.5 L18.5 18.5" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="$stroke" stroke-linecap="round"/>
</svg>''', size, size);

  static Widget navSettings(Color c, Color bg,
          {double size = 22, double stroke = 1.6}) =>
      _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" fill="none">
<path d="M4 7 H18 M4 15 H18" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="$stroke" stroke-linecap="round"/>
<circle cx="8" cy="7" r="2.4" fill="${_rgb(bg)}" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="$stroke"/>
<circle cx="14" cy="15" r="2.4" fill="${_rgb(bg)}" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="$stroke"/>
</svg>''', size, size);

  static Widget person(Color c, {double size = 20}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" fill="none">
<circle cx="11" cy="7.5" r="3.2" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6"/>
<path d="M4.5 18c1.2-3.4 11.8-3.4 13 0" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" stroke-linecap="round"/>
</svg>''', size, size);

  static Widget heart(Color c, {double size = 20, bool filled = false}) =>
      _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" fill="none">
<path d="M11 18.2s-6.6-4.1-6.6-8.6a3.7 3.7 0 016.6-2.2 3.7 3.7 0 016.6 2.2c0 4.5-6.6 8.6-6.6 8.6z"${filled ? ' fill="${_rgb(c)}"' : ''} stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" stroke-linejoin="round"/>
</svg>''', size, size);

  /// The logo mark's three organ pipes, single-color (SOUND settings row).
  static Widget organPipes(Color c, {double size = 20}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22">
<rect x="4.7" y="8.5" width="2.6" height="9" rx="1.3" fill="${_rgb(c)}" fill-opacity="${_op(c)}"/>
<rect x="9.7" y="5" width="2.6" height="12.5" rx="1.3" fill="${_rgb(c)}" fill-opacity="${_op(c)}"/>
<rect x="14.7" y="10.5" width="2.6" height="7" rx="1.3" fill="${_rgb(c)}" fill-opacity="${_op(c)}"/>
</svg>''', size, size);

  /// Sun (READING settings row: keep the screen awake).
  static Widget sun(Color c, {double size = 20}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" fill="none">
<circle cx="11" cy="11" r="4" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6"/>
<path d="M11 5V2.8M11 17v2.2M17 11h2.2M2.8 11H5M15.24 6.76l1.56-1.56M5.2 16.8l1.56-1.56M15.24 15.24l1.56 1.56M5.2 5.2l1.56 1.56" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6" stroke-linecap="round"/>
</svg>''', size, size);

  static Widget grid2x2(Color c, {double size = 20}) => _svg('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22" fill="none">
<rect x="4" y="4" width="6" height="6" rx="1.8" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6"/>
<rect x="12.5" y="4" width="6" height="6" rx="1.8" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6"/>
<rect x="4" y="12.5" width="6" height="6" rx="1.8" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6"/>
<rect x="12.5" y="12.5" width="6" height="6" rx="1.8" stroke="${_rgb(c)}" stroke-opacity="${_op(c)}" stroke-width="1.6"/>
</svg>''', size, size);
}

// ---------------------------------------------------------------------------
// Brand header (52px) — tab screens
// ---------------------------------------------------------------------------

class BrandHeader extends StatelessWidget {
  /// When set, the logo mark + wordmark become tappable (Numbers tab home).
  final VoidCallback? onLogoTap;

  const BrandHeader({super.key, this.onLogoTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Canticle Ampersand wordmark (assets/brand): custom lettering with the
    // staff-threaded '&'; separate renders per theme.
    final brand = Image.asset(
      t.isDark
          ? 'assets/brand/wordmark_dark.png'
          : 'assets/brand/wordmark_light.png',
      height: 38,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: onLogoTap == null
          ? brand
          : Pressable.child(
              onTap: onLogoTap,
              pressedScale: 0.97,
              child: brand,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-page header (56px): back chevron, centered title, optional right slot
// ---------------------------------------------------------------------------

class SubPageHeader extends StatelessWidget {
  final String title;

  /// Defaults to a 42px spacer to keep the title optically centered.
  final Widget? trailing;

  /// Replaces the title text (Hymn Page's crumb + title stack).
  final Widget? center;

  const SubPageHeader({super.key, this.title = '', this.trailing, this.center});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line2)),
      ),
      child: Row(
        children: [
          Pressable(
            onTap: () => Navigator.pop(context),
            pressedScale: 1.0,
            builder: (context, pressed) => Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pressed ? t.surface2 : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: HymnalIcons.backChevron(t.ink),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: center ??
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
          ),
          const SizedBox(width: 6),
          trailing ?? const SizedBox(width: 42),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom nav (76px + safe area) — tab screens
// ---------------------------------------------------------------------------

class HymnalBottomNav extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;

  const HymnalBottomNav(
      {super.key, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final inset = MediaQuery.of(context).padding.bottom;
    Widget item(int i, String label, Widget icon) {
      final isActive = i == active;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(i),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 10.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? t.accent : t.faint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Color c(int i) => i == active ? t.accent : t.faint;
    double s(int i) => i == active ? 1.8 : 1.6;

    return Container(
      height: 76 + (inset > 12 ? inset : 12),
      padding: EdgeInsets.only(bottom: inset > 12 ? inset : 12),
      decoration: BoxDecoration(
        color: t.bg,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          item(0, context.appText.numbers, HymnalIcons.navNumbers(c(0))),
          item(1, context.appText.search,
              HymnalIcons.magnifier(c(1), stroke: s(1))),
          item(2, context.appText.favorites,
              HymnalIcons.heart(c(2), size: 22, filled: active == 2)),
          item(3, context.appText.settings,
              HymnalIcons.navSettings(c(3), t.bg, stroke: s(3))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NEW HYMNAL / OLD HYMNAL pill badges
// ---------------------------------------------------------------------------

class VersionBadge extends StatelessWidget {
  final bool isNew;
  final String? label;

  /// Per-line size of the wrapped two-line label ('NEW' over 'HYMNAL');
  /// smaller than the old single-line sizes so the pill keeps a reasonable
  /// height. Preview cards use the 8px default; list rows pass 7.5.
  final double fontSize;
  final EdgeInsets padding;

  const VersionBadge(
      {super.key,
      required this.isNew,
      this.label,
      this.fontSize = 8,
      this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3)});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isNew ? t.tint : t.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label ?? (isNew ? 'NEW\nHYMNAL' : 'OLD\nHYMNAL'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: fontSize,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: trackingEm(0.1, fontSize),
          color: isNew ? t.accent : t.muted,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label (APPEARANCE / READING / MORE / PREVIEW / HYMN NUMBER)
// ---------------------------------------------------------------------------

class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text, {super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: trackingEm(0.14, 11),
          color: t.muted,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide route (kept from the old app; sub-pages slide in from the right)
// ---------------------------------------------------------------------------

PageRouteBuilder slideRoute(Widget page, {bool fromLeft = false}) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: Offset(fromLeft ? -1.0 : 1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.ease));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

// ---------------------------------------------------------------------------
// Hymn body HTML transform (mockup styleBody(), variant A)
// ---------------------------------------------------------------------------

/// Rewrites the legacy `<font>` markup in hymn bodies into styled spans:
/// verse numbers -> accent sans 700 at 0.68em with 0.14em tracking;
/// "CHORUS:" -> gold sans 700 "CHORUS" at 0.62em, not italic.
/// Sizes are emitted in px because flutter_html resolves em against the
/// parent inconsistently across nested tags.
String styleHymnBody(String html, HymnalTokens t, double fontSize) {
  final accent = _rgb(t.accent);
  final gold = _rgb(t.gold);
  final versePx = fontSize * 1.36;
  final chorusPx = fontSize * 1.24;

  return html
      .replaceAllMapped(
        RegExp(r'<font color="#0B6138"><b>(\d+)</b></font>'),
        (m) =>
            '<span style="font-family:$kSans;font-size:${versePx.toStringAsFixed(1)}px;font-weight:700;letter-spacing:${trackingEm(0.14, versePx).toStringAsFixed(2)}px;color:$accent">${m[1]}</span>',
      )
      .replaceAll(
        '<font color="#CD9B1D">CHORUS:</font>',
        '<span style="font-family:$kSans;font-size:${chorusPx.toStringAsFixed(1)}px;font-weight:700;letter-spacing:${trackingEm(0.14, chorusPx).toStringAsFixed(2)}px;color:$gold;font-style:normal">CHORUS</span>',
      )
      .replaceAllMapped(RegExp(r'<font color="([^"]*)"[^>]*>'), (m) {
    final lc = m[1]!.toLowerCase();
    final col = lc == '#0b6138'
        ? accent
        : lc == '#cd9b1d'
            ? gold
            : 'inherit';
    return '<span style="color:$col">';
  }).replaceAll('</font>', '</span>');
}
