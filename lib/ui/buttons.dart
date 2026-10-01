import 'package:flutter/material.dart';
import 'package:sdahymnal/services/popular_hymns.dart';
import 'package:sdahymnal/services/trends.dart';
import 'package:sdahymnal/services/analytics.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/classic.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/hymn_occasions.dart';
import 'package:sdahymnal/ui/additional_readings.dart';

/// Numbers (home tab) — content-only: the shell renders the brand header
/// above and the bottom nav below. Layout: scrollable display zone (label,
/// giant Literata number + blinking caret, recents chips, NEW/OLD preview
/// cards) with the keypad pinned at the bottom.
class Buttons extends StatefulWidget {
  final bool active;
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;
  final AdditionalReadingCatalog additionalReadings;

  const Buttons({
    super.key,
    this.active = true,
    required this.hymnsOld,
    required this.hymnsNew,
    this.additionalReadings = const AdditionalReadingCatalog([]),
  });

  @override
  State<Buttons> createState() => _ButtonsState();
}

class _ButtonsState extends State<Buttons> with SingleTickerProviderStateMixin {
  static const int _newMax = 695;
  static const int _readingMax = 920;

  String _display = '';
  late final AnimationController _caret;
  List<Hymn> _popular = [];
  TrendsSnapshot? _trends;
  bool _routeWasCurrent = false;

  @override
  void initState() {
    super.initState();
    _selectPopular();
    _loadPopular();
    // Hard on/off blink: visible 0–55% of the 1.2s cycle, hidden 56–100%.
    _caret = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _selectPopular() {
    _popular = popularHymns([...widget.hymnsNew, ...widget.hymnsOld],
        snapshot: _trends);
  }

  Future<void> _loadPopular() async {
    try {
      final snapshot = await TrendsRepository().load();
      if (!mounted) return;
      setState(() {
        _trends = snapshot;
        _selectPopular();
      });
    } catch (_) {
      // Keep the bundled selection when the community report is unavailable.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Track the shell route, including returns after reader replacements.
    final current = ModalRoute.isCurrentOf(context) ?? true;
    if (current && !_routeWasCurrent && widget.active) _selectPopular();
    _routeWasCurrent = current;
  }

  @override
  void didUpdateWidget(covariant Buttons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.active && widget.active) ||
        oldWidget.hymnsNew != widget.hymnsNew ||
        oldWidget.hymnsOld != widget.hymnsOld) {
      _selectPopular();
    }
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
    if (_display.length >= 3) {
      AppAnalytics.instance.event('keypad_reject');
      return;
    }
    final nn = int.tryParse(_display + digit) ?? 0;
    if (nn > _readingMax || nn < 1) {
      AppAnalytics.instance.event('keypad_reject');
      return;
    }
    setState(() => _display += digit);
  }

  void _clear() => setState(() => _display = '');

  void _back() {
    if (_display.isEmpty) return;
    AppAnalytics.instance.event('keypad_correct');
    setState(() => _display = _display.substring(0, _display.length - 1));
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  String _titleFor(List<Hymn> list, int n) =>
      hymnByNumber(list, n)?.title ?? '';

  AdditionalReading? _readingByNumber(int number) {
    for (final reading in widget.additionalReadings.readings) {
      if (reading.number == number) return reading;
    }
    return null;
  }

  void _openHymn(
      {required bool isNew, required int n, String source = 'keypad'}) {
    final list = isNew ? widget.hymnsNew : widget.hymnsOld;
    final hymn = hymnByNumber(list, n);
    if (hymn == null) return;
    Navigator.push(
      context,
      slideRoute(HymnPage(hymn: hymn, hymns: list, analyticsSource: source)),
    );
  }

  void _open(bool isNew) {
    final n = int.tryParse(_display) ?? 0;
    if (n < 1) return;
    if (isNew && n > _newMax) return;
    _openHymn(isNew: isNew, n: n);
  }

  void _openReading(AdditionalReading reading) {
    Navigator.push(
      context,
      slideRoute(AdditionalReadingPage(
        reading: reading,
        readings: widget.additionalReadings.readings,
      )),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (t.isClassic) {
      final n = int.tryParse(_display) ?? 0;
      final reading = _readingByNumber(n);
      return ValueListenableBuilder<double>(
        valueListenable: FontSizeController.instance,
        builder: (context, fontSize, _) => ClassicNumberPad(
          discoveryRows: Column(children: [_recentsRow(t), _popularRow(t)]),
          display: _display,
          oldTitle: _titleFor(widget.hymnsOld, n),
          newTitle: _titleFor(widget.hymnsNew, n),
          readingTitle: reading?.title ?? '',
          readingCategory: reading?.category ?? '',
          fontSize: fontSize,
          onDigit: _press,
          onClear: _clear,
          onBackspace: _back,
          onOld: hymnByNumber(widget.hymnsOld, n) == null
              ? null
              : () => _open(false),
          onNew: hymnByNumber(widget.hymnsNew, n) == null
              ? null
              : () => _open(true),
          onReading: reading == null ? null : () => _openReading(reading),
          onOccasions: widget.hymnsNew.isEmpty && widget.hymnsOld.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    slideRoute(HymnOccasionsPage(
                      hymns: [...widget.hymnsNew, ...widget.hymnsOld],
                    )),
                  ),
          onReadings: widget.additionalReadings.readings.isEmpty
              ? null
              : () => Navigator.push(
                    context,
                    slideRoute(AdditionalReadingsPage(
                        catalog: widget.additionalReadings)),
                  ),
        ),
      );
    }
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
                _browseLinks(t),
                _recentsRow(t),
                _popularRow(t),
                if (_display.isEmpty) _previewZone(t),
              ],
            ),
          ),
        ),
        if (_display.isNotEmpty) _previewZone(t),
        _keypad(t, keyHeight),
      ],
    );
  }

  Widget _browseLinks(HymnalTokens t) {
    final linkStyle = TextStyle(
      fontFamily: kSans,
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: t.accent,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6)),
              onPressed: widget.hymnsNew.isEmpty && widget.hymnsOld.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        slideRoute(HymnOccasionsPage(
                          hymns: [...widget.hymnsNew, ...widget.hymnsOld],
                        )),
                      ),
              icon:
                  Icon(Icons.library_music_outlined, size: 17, color: t.accent),
              label: Text('Hymns by occasion',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: linkStyle),
            ),
          ),
          Flexible(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6)),
              onPressed: widget.additionalReadings.readings.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        slideRoute(AdditionalReadingsPage(
                            catalog: widget.additionalReadings)),
                      ),
              icon: Icon(Icons.menu_book_outlined, size: 17, color: t.accent),
              label: Text('Additional readings',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: linkStyle),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Display zone: HYMN NUMBER label + giant number with blinking caret

  Widget _displayZone(HymnalTokens t, double numSize) {
    return Column(
      children: [
        const Center(child: SectionLabel('HYMN OR READING NUMBER')),
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
                  onTap: () => _openHymn(
                      isNew: r.v.contains('new'), n: r.n, source: 'recent'),
                  pressedScale: 0.94,
                  builder: (context, pressed) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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

  Widget _popularRow(HymnalTokens t) {
    if (_popular.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('popular-hymns'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          Text('Popular',
              style:
                  TextStyle(fontFamily: kSans, fontSize: 11, color: t.muted)),
          for (final hymn in _popular)
            Tooltip(
              message:
                  '${hymn.version == 'new' ? 'New' : 'Old'} Hymnal · ${hymn.title.trim()}',
              child: Pressable(
                key: ValueKey('popular-${hymn.version}-${hymn.number}'),
                onTap: () =>
                    _openHymn(isNew: hymn.version == 'new', n: hymn.number),
                pressedScale: 0.94,
                builder: (context, pressed) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.surface,
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${hymn.number}',
                      style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.ink)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Preview zone: NEW/OLD cards when a number is typed, hint otherwise

  Widget _previewZone(HymnalTokens t) {
    final n = int.tryParse(_display) ?? 0;
    final hasNum = n >= 1;
    final newOk = hasNum && n <= _newMax;
    final reading = hasNum ? _readingByNumber(n) : null;
    final oldHymn = hasNum ? hymnByNumber(widget.hymnsOld, n) : null;

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: hasNum
            ? [
                if (reading != null) ...[
                  _readingPreviewCard(t, reading),
                  if (oldHymn != null) const SizedBox(height: 8),
                ] else ...[
                  _previewCard(
                    t,
                    isNew: true,
                    title: newOk
                        ? _titleFor(widget.hymnsNew, n)
                        : 'Not in the New Hymnal',
                    invalid: !newOk,
                    onTap: newOk ? () => _open(true) : null,
                  ),
                  if (oldHymn != null) const SizedBox(height: 8),
                ],
                if (oldHymn != null)
                  _previewCard(
                    t,
                    isNew: false,
                    title: oldHymn.title,
                    invalid: false,
                    onTap: () => _open(false),
                  ),
              ]
            : [
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(
                        text:
                            'Type a hymn or reading number to preview it here\n'),
                    TextSpan(
                      text:
                          'New Hymnal 1–695 · Readings 696–920 · Old Hymnal 1–703',
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

  Widget _readingPreviewCard(HymnalTokens t, AdditionalReading reading) {
    return Pressable(
      onTap: () => _openReading(reading),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: t.tint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('READING',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                    color: t.accent,
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reading.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        color: t.ink,
                      )),
                  const SizedBox(height: 2),
                  Text(reading.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 11.5,
                        color: t.muted,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 12),
            HymnalIcons.rowChevron(t.faint),
          ],
        ),
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
      key: ValueKey(isNew ? 'number-preview-new' : 'number-preview-old'),
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
