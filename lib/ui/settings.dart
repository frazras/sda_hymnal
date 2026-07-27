import 'package:flutter/material.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/about.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/donate.dart';
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/fontsize.dart';
import 'package:sdahymnal/ui/sp.dart';

/// Settings tab — content only (the shell renders the brand header above and
/// the bottom nav below). Sections: APPEARANCE (theme segmented control),
/// READING (font size row), SOUND (instrument theme row + picker sheet),
/// MORE (favorites / about / donate / other projects), footer. Holds the
/// hymn lists so Favorites can resolve titles.
class Settings extends StatelessWidget {
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;

  const Settings(
      {super.key, required this.hymnsNew, required this.hymnsOld});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        const SectionLabel('APPEARANCE',
            padding: EdgeInsets.fromLTRB(24, 18, 24, 8)),
        _card(
          t,
          padding: const EdgeInsets.all(12),
          child: const _ThemeSegmentedControl(),
        ),
        const SectionLabel('READING',
            padding: EdgeInsets.fromLTRB(24, 22, 24, 8)),
        _card(
          t,
          child: _SettingsRow(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            leading: Text(
              'Aa',
              style: TextStyle(
                fontFamily: kSerif,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: t.muted,
              ),
            ),
            title: 'Font Size',
            trailing: ValueListenableBuilder<double>(
              valueListenable: FontSizeController.instance,
              builder: (context, size, _) => Text(
                '${size.round()} pt',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
                  color: t.muted,
                ),
              ),
            ),
            onTap: () =>
                Navigator.push(context, slideRoute(const FontSizer())),
          ),
        ),
        const SectionLabel('SOUND',
            padding: EdgeInsets.fromLTRB(24, 22, 24, 8)),
        _card(
          t,
          child: Column(
            children: [
              _SettingsRow(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                leading: HymnalIcons.organPipes(t.muted),
                title: 'Instrument',
                subtitle: 'How hymn music sounds',
                divider: true,
                trailing: ValueListenableBuilder<String>(
                  valueListenable: InstrumentTheme.instance,
                  builder: (context, _, __) => Text(
                    InstrumentTheme.instance.label,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      color: t.muted,
                    ),
                  ),
                ),
                onTap: () => _showInstrumentSheet(context, t),
              ),
              _SettingsRow(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                leading: HymnalIcons.grid2x2(t.muted),
                title: 'Chord tabs',
                subtitle: 'Play-along chords for musicians',
                trailing: const _MiniSwitch(),
                chevron: false,
                onTap: () =>
                    ChordTabs.instance.set(!ChordTabs.instance.value),
              ),
            ],
          ),
        ),
        const SectionLabel('MORE',
            padding: EdgeInsets.fromLTRB(24, 22, 24, 8)),
        _card(
          t,
          child: Column(
            children: [
              _SettingsRow(
                leading: HymnalIcons.heart(t.muted),
                title: 'Favorites',
                subtitle: 'Your saved hymns',
                divider: true,
                onTap: () => Navigator.push(
                    context,
                    slideRoute(FavoritesPage(
                        hymnsNew: hymnsNew, hymnsOld: hymnsOld))),
              ),
              _SettingsRow(
                leading: HymnalIcons.person(t.muted),
                title: 'About Us',
                subtitle: 'Who made this app?',
                divider: true,
                onTap: () =>
                    Navigator.push(context, slideRoute(const About())),
              ),
              _SettingsRow(
                leading: HymnalIcons.heart(t.muted),
                title: 'Donate',
                subtitle: 'Support the development',
                divider: true,
                onTap: () =>
                    Navigator.push(context, slideRoute(const Donate())),
              ),
              _SettingsRow(
                leading: HymnalIcons.grid2x2(t.muted),
                title: 'Our Other Projects',
                subtitle: 'Like this app? You will love our ministry!',
                onTap: () => Navigator.push(context, slideRoute(const Sp())),
              ),
            ],
          ),
        ),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
          child: Column(
            children: [
              HymnalIcons.logoMark(t, size: 22),
              const SizedBox(height: 6),
              Text(
                'Old & New SDA Hymnal',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12,
                  color: t.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Version 3.0',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 11,
                  color: t.faint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Settings card: margin 20 sides, surface bg, line border, radius 16,
  /// card shadow. Clips children so pressed-row backgrounds respect corners.
  Widget _card(HymnalTokens t, {EdgeInsets? padding, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: t.cardShadow,
      ),
      child: child,
    );
  }

  /// Instrument picker sheet (same pattern as the hymn page's speed sheet):
  /// one row per theme, tap applies and closes.
  void _showInstrumentSheet(BuildContext context, HymnalTokens t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          decoration: BoxDecoration(
            color: t.isDark ? const Color(0xFF171E1A) : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('INSTRUMENT'),
              const SizedBox(height: 6),
              for (final (i, theme) in InstrumentTheme.themes.indexed)
                _instrumentRow(
                  t,
                  theme,
                  sheetContext,
                  divider: i < InstrumentTheme.themes.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instrumentRow(
    HymnalTokens t,
    (String, String, int?) theme,
    BuildContext sheetContext, {
    required bool divider,
  }) {
    final selected = InstrumentTheme.instance.value == theme.$1;
    return Pressable(
      onTap: () {
        InstrumentTheme.instance.set(theme.$1);
        Navigator.pop(sheetContext);
      },
      pressedScale: 1.0,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        decoration: BoxDecoration(
          color: pressed ? t.surface2 : Colors.transparent,
          border:
              divider ? Border(bottom: BorderSide(color: t.line2)) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                theme.$2,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected ? t.accent : t.ink,
                ),
              ),
            ),
            if (selected)
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: t.accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}

/// Light / Dark / System segmented control wired to ThemeController.
class _ThemeSegmentedControl extends StatelessWidget {
  const _ThemeSegmentedControl();

  static const _options = [
    ('light', 'Light'),
    ('dark', 'Dark'),
    ('system', 'System'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, _, __) {
        final current = ThemeController.instance.pref;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: t.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _options.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _segment(
                    t,
                    label: _options[i].$2,
                    selected: current == _options[i].$1,
                    onTap: () =>
                        ThemeController.instance.setPref(_options[i].$1),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _segment(
    HymnalTokens t, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.97,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? t.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? t.cardShadow : const [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? t.accent : t.muted,
          ),
        ),
      ),
    );
  }
}

/// A tappable settings-card row: leading widget, title (+ optional subtitle),
/// optional trailing value, chevron ([chevron] false drops it — toggle rows).
/// Pressed state highlights with surface2.
class _SettingsRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool divider;
  final bool chevron;
  final EdgeInsets padding;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.divider = false,
    this.chevron = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final titleText = Text(
      title,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: t.ink,
      ),
    );
    return Pressable(
      onTap: onTap,
      pressedScale: 1.0,
      builder: (context, pressed) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: pressed ? t.surface2 : Colors.transparent,
          border: divider
              ? Border(bottom: BorderSide(color: t.line2))
              : null,
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: subtitle == null
                  ? titleText
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleText,
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 12.5,
                            color: t.muted,
                          ),
                        ),
                      ],
                    ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 14),
              trailing!,
            ],
            if (chevron) ...[
              const SizedBox(width: 14),
              HymnalIcons.rowChevron(t.faint, size: 15),
            ],
          ],
        ),
      ),
    );
  }
}

/// Flat mini switch for the Chord-tabs row (no Material Switch — wrong look):
/// 44×24 pill track, accent when on, thumb sliding via AnimatedAlign. Taps
/// land on the enclosing row, which toggles [ChordTabs].
class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ValueListenableBuilder<bool>(
      valueListenable: ChordTabs.instance,
      builder: (context, on, _) => Container(
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? t.accent : t.surface2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          curve: Curves.ease,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: on ? t.onAccent : t.surface,
              shape: BoxShape.circle,
              border: Border.all(color: t.line),
              boxShadow: t.thumbShadow,
            ),
          ),
        ),
      ),
    );
  }
}
