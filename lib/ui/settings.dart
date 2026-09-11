import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:sdahymnal/services/analytics_endpoint.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/about.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/fontsize.dart';
import 'package:sdahymnal/ui/sp.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/ui/statistics.dart';

/// Settings tab — content only (the shell renders the brand header above and
/// the bottom nav below). Sections: READING, SOUND, APPEARANCE, MORE, footer.
class Settings extends StatelessWidget {
  const Settings({super.key, this.hymns = const []});
  final List<Hymn> hymns;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView(
      key: const ValueKey('settings-list'),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        const SectionLabel('READING',
            padding: EdgeInsets.fromLTRB(24, 18, 24, 8)),
        _card(
          t,
          child: Column(
            children: [
              _SettingsRow(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                divider: true,
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
              _SettingsRow(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                leading: HymnalIcons.sun(t.muted),
                title: 'Keep screen on',
                subtitle: 'Stay awake while a hymn is open',
                divider: true,
                trailing: _MiniSwitch(KeepScreenOn.instance),
                chevron: false,
                onTap: () =>
                    KeepScreenOn.instance.set(!KeepScreenOn.instance.value),
              ),
              _SettingsRow(
                leading: Icon(Icons.vertical_align_bottom, color: t.muted),
                title: 'Auto-scroll',
                subtitle:
                    'Follow the hymn automatically, with or without music',
                trailing: _MiniSwitch(AutoScroll.instance),
                chevron: false,
                onTap: () =>
                    AutoScroll.instance.set(!AutoScroll.instance.value),
              ),
            ],
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
              // Chord tabs + its dependent difficulty row rebuild together:
              // the divider under Chord tabs exists exactly while the
              // difficulty row is visible, so the card's last row never
              // carries a stray hairline.
              ValueListenableBuilder<bool>(
                valueListenable: ChordTabs.instance,
                builder: (context, chordsOn, _) => Column(
                  children: [
                    _SettingsRow(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      leading: HymnalIcons.grid2x2(t.muted),
                      title: 'Chord tabs',
                      subtitle: 'Play-along chords for musicians',
                      divider: chordsOn,
                      trailing: _MiniSwitch(ChordTabs.instance),
                      chevron: false,
                      onTap: () =>
                          ChordTabs.instance.set(!ChordTabs.instance.value),
                    ),
                    if (chordsOn)
                      _SettingsRow(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 15),
                        leading: Text(
                          'C7',
                          style: TextStyle(
                            fontFamily: kSerif,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: t.muted,
                          ),
                        ),
                        title: 'Chord difficulty',
                        subtitle: 'Simplify chords for learners',
                        trailing: ValueListenableBuilder<String>(
                          valueListenable: ChordLevelPref.instance,
                          builder: (context, _, __) => Text(
                            ChordLevelPref.instance.label,
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 13,
                              color: t.muted,
                            ),
                          ),
                        ),
                        onTap: () => _showChordLevelSheet(context, t),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('APPEARANCE',
            padding: EdgeInsets.fromLTRB(24, 22, 24, 8)),
        _card(t,
            padding: const EdgeInsets.all(16), child: const _DesignSelector()),
        const SizedBox(height: 10),
        _card(
          t,
          padding: const EdgeInsets.all(12),
          child: const _ThemeSegmentedControl(),
        ),
        const SectionLabel('MORE', padding: EdgeInsets.fromLTRB(24, 22, 24, 8)),
        _card(
          t,
          child: Column(
            children: [
              _SettingsRow(
                leading: HymnalIcons.person(t.muted),
                title: 'About Us',
                subtitle: 'Who made this app?',
                divider: true,
                onTap: () {
                  AppAnalytics.instance.event('screen_view', variant: 'about');
                  Navigator.push(context, slideRoute(const About()));
                },
              ),
              _SettingsRow(
                leading: Icon(Icons.new_releases_outlined, color: t.muted),
                title: 'What’s new',
                subtitle: 'Features added in each version',
                divider: true,
                onTap: () => ReleaseNotesService.instance.showHistory(context),
              ),
              _SettingsRow(
                leading: HymnalIcons.grid2x2(t.muted),
                title: 'Our Other Projects',
                subtitle: 'Like this app? You will love our ministry!',
                onTap: () {
                  AppAnalytics.instance
                      .event('screen_view', variant: 'projects');
                  Navigator.push(context, slideRoute(const Sp()));
                },
              ),
            ],
          ),
        ),
        const SectionLabel('PRIVACY & STATISTICS',
            padding: EdgeInsets.fromLTRB(24, 22, 24, 8)),
        _card(t,
            child: _SettingsRow(
              leading: Icon(Icons.bar_chart_rounded, color: t.accent),
              title: 'Community statistics',
              subtitle: 'Popular hymns, repeat visits, and times of worship',
              onTap: () => Navigator.push(
                  context, slideRoute(StatisticsPage(hymns: hymns))),
            )),
        const SizedBox(height: 10),
        _card(t,
            child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: AnimatedBuilder(
                  animation: AppAnalytics.instance,
                  builder: (context, _) => Column(children: [
                    SwitchListTile.adaptive(
                      key: const ValueKey('analytics-toggle'),
                      title: const Text('Share usage statistics'),
                      subtitle: const Text(
                          'Help improve the hymnal and community trends. '
                          'Enabled by default; you can turn this off anytime. '
                          'Usage and error summaries are sent about weekly. '
                          'Country is estimated from the upload connection. No names, '
                          'search text, advertising, or personalized content.'),
                      value: AppAnalytics.instance.enabled,
                      onChanged: AppAnalytics.instance.available
                          ? AppAnalytics.instance.setEnabled
                          : null,
                    ),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                            '${AppAnalytics.instance.status}. Turning this off '
                            'clears queued statistics and local analytics identifiers. '
                            'Previously combined statistics follow the privacy policy retention periods.',
                            style: TextStyle(fontSize: 12, color: t.muted))),
                    TextButton(
                        onPressed: () => launchUrl(
                            Uri.parse('$analyticsEndpoint/privacy-policy'),
                            mode: LaunchMode.externalApplication),
                        child: const Text('Privacy policy')),
                  ]),
                ))),
        // Footer
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
          child: Column(
            children: [
              Image.asset(
                t.isDark
                    ? 'assets/brand/mark_dark.png'
                    : 'assets/brand/mark_light.png',
                height: 30,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
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
                'Version $appReleaseVersion',
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
        borderRadius: BorderRadius.circular(t.isClassic ? 4 : 16),
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

  /// Chord-difficulty options: (pref id, label, description).
  static const List<(String, String, String)> _chordLevels = [
    ('simple', 'Simple', 'Major and minor only'),
    ('medium', 'Medium', 'Sevenths where they resolve'),
    ('original', 'Original', 'As detected'),
  ];

  /// Chord-difficulty picker sheet (same pattern as the instrument sheet):
  /// one row per level, tap applies and closes.
  void _showChordLevelSheet(BuildContext context, HymnalTokens t) {
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
              const SectionLabel('CHORD DIFFICULTY'),
              const SizedBox(height: 6),
              for (final (i, level) in _chordLevels.indexed)
                _chordLevelRow(
                  t,
                  level,
                  sheetContext,
                  divider: i < _chordLevels.length - 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chordLevelRow(
    HymnalTokens t,
    (String, String, String) level,
    BuildContext sheetContext, {
    required bool divider,
  }) {
    final selected = ChordLevelPref.instance.value == level.$1;
    return Pressable(
      onTap: () {
        ChordLevelPref.instance.set(level.$1);
        Navigator.pop(sheetContext);
      },
      pressedScale: 1.0,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        decoration: BoxDecoration(
          color: pressed ? t.surface2 : Colors.transparent,
          border: divider ? Border(bottom: BorderSide(color: t.line2)) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.$2,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: selected ? t.accent : t.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    level.$3,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      color: t.muted,
                    ),
                  ),
                ],
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
          border: divider ? Border(bottom: BorderSide(color: t.line2)) : null,
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

/// Layout choice is separate from brightness and the instrument theme.
class _DesignSelector extends StatelessWidget {
  const _DesignSelector();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final controller = AppDesignController.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([
        controller,
        controller.iconBusy,
        controller.iconError,
      ]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('App design',
              style: TextStyle(
                  color: t.ink, fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
              'Choose the new look or the familiar original layout.\n'
              'The home-screen icon changes to match. Your hymns, favorites '
              'and music settings stay the same.',
              style: TextStyle(color: t.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            for (final design in AppDesign.values) ...[
              if (design == AppDesign.classic) const SizedBox(width: 12),
              Expanded(
                  child: Semantics(
                selected: controller.value == design,
                child: OutlinedButton(
                  key: ValueKey('design-${design.name}'),
                  onPressed: controller.iconBusy.value
                      ? null
                      : () => controller.set(design),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        controller.value == design ? t.onAccent : t.ink,
                    backgroundColor:
                        controller.value == design ? t.accent : t.surface,
                    minimumSize: const Size(0, 48),
                  ),
                  child:
                      Text(design == AppDesign.modern ? 'Modern' : 'Classic'),
                ),
              )),
            ],
          ]),
          if (controller.iconBusy.value)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Updating home-screen icon…'),
            ),
          if (controller.iconError.value case final String message) ...[
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: t.ink, fontSize: 13)),
            TextButton(
              key: const ValueKey('retry-app-icon'),
              onPressed: controller.iconBusy.value ? null : controller.syncIcon,
              child: const Text('Retry icon change'),
            ),
          ],
        ],
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
          border: divider ? Border(bottom: BorderSide(color: t.line2)) : null,
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

/// Flat mini switch for the toggle rows (no Material Switch — wrong look):
/// 44×24 pill track, accent when on, thumb sliding via AnimatedAlign. Taps
/// land on the enclosing row, which flips [listenable].
class _MiniSwitch extends StatelessWidget {
  final ValueListenable<bool> listenable;

  const _MiniSwitch(this.listenable);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
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
