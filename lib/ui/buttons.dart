import 'package:flutter/material.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

/// Numbers (home tab) — content-only: the shell renders the brand header
/// above and the bottom nav below. Layout: scrollable display zone (label,
/// giant Literata number + blinking caret, recents chips, NEW/OLD preview
/// cards) with the keypad pinned at the bottom.
class Buttons extends StatefulWidget {
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;

  const Buttons({super.key, required this.hymnsOld, required this.hymnsNew});

  @override
  State<Buttons> createState() => _ButtonsState();
}

class _ButtonsState extends State<Buttons>
    with SingleTickerProviderStateMixin {
  static const int _oldMax = 703;
  static const int _newMax = 695;

  String _display = '';
  late final AnimationController _caret;

  @override
  void initState() {
    super.initState();
    // Hard on/off blink: visible 0–55% of the 1.2s cycle, hidden 56–100%.
    _caret = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _caret.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Input
  // -------------------------------------------------------------------------

  void _press(String digit) {
    if (_display.length >= 3) return;
    final nn = int.tryParse(_display + digit) ?? 0;
    if (nn > _oldMax || nn < 1) return;
    setState(() => _display += digit);
  }

  void _clear() => setState(() => _display = '');

  void _back() {
    if (_display.isEmpty) return;
    setState(() => _display = _display.substring(0, _display.length - 1));
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  String _titleFor(List<Hymn> list, int n) => hymnByNumber(list, n)?.title ?? '';

  void _openHymn({required bool isNew, required int n}) {
    final list = isNew ? widget.hymnsNew : widget.hymnsOld;
    final hymn = hymnByNumber(list, n);
    if (hymn == null) return;
    Navigator.push(
      context,
      slideRoute(HymnPage(hymn: hymn, hymns: list)),
    );
  }

  void _open(bool isNew) {
    final n = int.tryParse(_display) ?? 0;
    if (n < 1) return;
    if (isNew && n > _newMax) return;
    _openHymn(isNew: isNew, n: n);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final vh = MediaQuery.sizeOf(context).height / 100;
    final numSize = (8 * vh).clamp(46.0, 62.0);
    final keyHeight = (6.5 * vh).clamp(44.0, 56.0);
    final displayTop = (2 * vh).clamp(6.0, 20.0);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: displayTop),
                _displayZone(t, numSize),
                _recentsRow(t),
                _previewZone(t),
              ],
            ),
          ),
        ),
        _keypad(t, keyHeight),
      ],
    );
  }

  // ---- Display zone: HYMN NUMBER label + giant number with blinking caret

  Widget _displayZone(HymnalTokens t, double numSize) {
    return Column(
      children: [
        const Center(child: SectionLabel('HYMN NUMBER')),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: numSize * 1.15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_display.isNotEmpty)
                Text(
                  _display,
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: numSize,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: trackingEm(0.02, numSize),
                    color: t.ink,
                  ),
                ),
              // flex gap 2 (only when the number is present) + caret margin 4.
              SizedBox(width: _display.isNotEmpty ? 6 : 4),
              AnimatedBuilder(
                animation: _caret,
                builder: (context, _) => Opacity(
                  opacity: _caret.value <= 0.55 ? 1.0 : 0.0,
                  child: Container(
                    width: 2,
                    height: numSize * 0.68,
                    decoration: BoxDecoration(
                      color: t.accentHi,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Recents chips row (rendered only when recents exist)

  Widget _recentsRow(HymnalTokens t) {
    return ValueListenableBuilder<List<({int n, String v})>>(
      valueListenable: Recents.instance,
      builder: (context, recents, _) {
        if (recents.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                // flex gap 6 + label margin-right 2.
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Recent',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 11,
                    color: t.muted,
                  ),
                ),
              ),
              for (final (i, r) in recents.take(3).indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Pressable(
                  onTap: () =>
                      _openHymn(isNew: r.v.contains('new'), n: r.n),
                  pressedScale: 0.94,
                  builder: (context, pressed) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.line),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${r.n}',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---- Preview zone: NEW/OLD cards when a number is typed, hint otherwise

  Widget _previewZone(HymnalTokens t) {
    final n = int.tryParse(_display) ?? 0;
    final hasNum = n >= 1;
    final newOk = hasNum && n <= _newMax;

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: hasNum
            ? [
                _previewCard(
                  t,
                  isNew: true,
                  title: newOk
                      ? _titleFor(widget.hymnsNew, n)
                      : 'Not in the New Hymnal',
                  invalid: !newOk,
                  onTap: newOk ? () => _open(true) : null,
                ),
                const SizedBox(height: 8),
                _previewCard(
                  t,
                  isNew: false,
                  title: _titleFor(widget.hymnsOld, n),
                  invalid: false,
                  onTap: () => _open(false),
                ),
              ]
            : [
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                        text: 'Type a hymn number to preview it here\n'),
                    TextSpan(
                      text: 'New Hymnal 1–695 · Old Hymnal 1–703',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ]),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    color: t.faint,
                  ),
                ),
              ],
      ),
    );
  }

  Widget _previewCard(
    HymnalTokens t, {
    required bool isNew,
    required String title,
    required bool invalid,
    required VoidCallback? onTap,
  }) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.985,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(14),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          children: [
            VersionBadge(isNew: isNew),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  fontStyle: invalid ? FontStyle.italic : FontStyle.normal,
                  color: invalid ? t.faint : t.ink,
                ),
              ),
            ),
            if (!invalid) ...[
              const SizedBox(width: 12),
              HymnalIcons.rowChevron(t.faint),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Keypad: 3-column grid, 9px gaps, pinned at the bottom

  Widget _keypad(HymnalTokens t, double keyHeight) {
    Widget digit(String d) => _key(t, keyHeight,
        onTap: () => _press(d),
        child: Text(
          d,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: t.ink,
          ),
        ));

    Widget row(List<Widget> cells) => Row(children: [
          for (final (i, c) in cells.indexed) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(child: c),
          ],
        ]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      child: Column(
        children: [
          row([digit('1'), digit('2'), digit('3')]),
          const SizedBox(height: 9),
          row([digit('4'), digit('5'), digit('6')]),
          const SizedBox(height: 9),
          row([digit('7'), digit('8'), digit('9')]),
          const SizedBox(height: 9),
          row([
            _key(t, keyHeight,
                utility: true,
                onTap: _clear,
                child: HymnalIcons.clearX(t.muted)),
            digit('0'),
            _key(t, keyHeight,
                utility: true,
                onTap: _back,
                child: HymnalIcons.backspace(t.muted)),
          ]),
        ],
      ),
    );
  }

  Widget _key(
    HymnalTokens t,
    double height, {
    bool utility = false,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.95,
      builder: (context, pressed) => Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed ? t.tint : (utility ? t.surface2 : t.key),
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(14),
          boxShadow: t.cardShadow,
        ),
        child: child,
      ),
    );
  }
}
