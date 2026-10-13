import 'package:sdahymnal/l10n/app_text.dart';
import 'report_error.dart';
import 'app_language_picker.dart';
import 'language_packs.dart';
import '../services/app_language.dart';
import 'reading_history.dart';
import 'package:flutter/material.dart';
import 'musical_style_sheet.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/ui/music_options.dart';
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
import 'package:sdahymnal/ui/kit.dart';
import 'package:sdahymnal/ui/sp.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/ui/statistics.dart';

/// Settings tab — content only (the shell renders the brand header above and
/// the bottom nav below). Every row uses the shared kit, so toggles, values
/// and links look the same in each section and both designs.
class Settings extends StatelessWidget {
  const Settings(
      {super.key,
      this.hymns = const [],
      this.historyHymns,
      this.onPacksChanged});
  final List<Hymn> hymns;
  final List<Hymn>? historyHymns;
  final Future<void> Function()? onPacksChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = context.appText;
    return ListView(
      key: const ValueKey('settings-list'),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        // ------------------------------------------------------------ Reading
        SectionLabel(text.reading.toUpperCase(),
            padding: sectionPadding(first: true)),
        HymnalCard(
          child: Column(children: [
            ValueListenableBuilder<double>(
              valueListenable: FontSizeController.instance,
              builder: (context, size, _) => SettingsRow(
                leading: Text('Aa',
                    style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.muted)),
                title: text.textSize,
                trailing: RowValue('${size.round()} pt'),
                divider: true,
                onTap: () =>
                    Navigator.push(context, slideRoute(const FontSizer())),
              ),
            ),
            _Toggle(
              listenable: KeepScreenOn.instance,
              leading: HymnalIcons.sun(t.muted),
              title: text.keepScreenOn,
              subtitle: text.keepScreenOnHelp,
              divider: true,
              onChanged: KeepScreenOn.instance.set,
            ),
            _Toggle(
              listenable: AutoScroll.instance,
              leading: const RowIcon(Icons.vertical_align_bottom),
              title: text.autoScroll,
              subtitle: text.autoScrollHelp,
              onChanged: AutoScroll.instance.set,
            ),
          ]),
        ),

        // -------------------------------------------------------------- Sound
        SectionLabel(text.sound.toUpperCase(), padding: sectionPadding()),
        HymnalCard(
          child: Column(children: [
            ValueListenableBuilder<String>(
              valueListenable: InstrumentTheme.instance,
              builder: (context, style, _) => SettingsRow(
                leading: HymnalIcons.organPipes(t.muted),
                title: text.musicalStyle,
                subtitle: text.musicalStyleHelp,
                trailing: RowValue(text.styleLabel(style)),
                divider: true,
                onTap: () => showMusicalStyleSheet(context),
              ),
            ),
            _Toggle(
              listenable: Autoplay.instance,
              leading: const RowIcon(Icons.play_circle_outline),
              title: text.autoplay,
              subtitle: text.autoplayHelp,
              onChanged: Autoplay.instance.set,
            ),
          ]),
        ),

        // ---------------------------------------------------- Musicians/choir
        SectionLabel(text.musiciansAndChoir, padding: sectionPadding()),
        HymnalCard(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              ChordTabs.instance,
              ChordLevelPref.instance,
              MusicOptions.instance,
            ]),
            builder: (context, _) => Column(children: [
              SettingsSwitchRow(
                leading: HymnalIcons.grid2x2(t.muted),
                title: text.chordTabs,
                subtitle: text.chordTabsHelp,
                value: ChordTabs.instance.value,
                divider: true,
                onChanged: ChordTabs.instance.set,
              ),
              if (ChordTabs.instance.value)
                SettingsRow(
                  leading: Text('C7',
                      style: TextStyle(
                          fontFamily: kSerif,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: t.muted)),
                  title: text.chordDifficulty,
                  subtitle: text.chordDifficultyHelp,
                  trailing: RowValue(
                      text.chordLevelLabel(ChordLevelPref.instance.value)),
                  divider: true,
                  onTap: () => _showChordLevelSheet(context),
                ),
              SettingsSwitchRow(
                key: const ValueKey('settings-choir-practice'),
                leading: const RowIcon(Icons.groups_outlined),
                title: text.choirPractice,
                subtitle: text.choirPracticeHelp,
                value: MusicOptions.instance.choirPractice,
                divider: true,
                onChanged: (value) async {
                  await MusicOptions.instance.setChoirPractice(value);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(value
                        ? context.appText.choirPracticeOn
                        : context.appText.choirPracticeOff),
                    duration: const Duration(seconds: 4),
                  ));
                },
              ),
              SettingsSwitchRow(
                key: const ValueKey('settings-custom-instruments'),
                leading: const RowIcon(Icons.tune),
                title: text.customizeInstruments,
                subtitle: text.customizeInstrumentsHelp,
                value: MusicOptions.instance.customInstruments,
                divider: MusicOptions.instance.customInstruments,
                onChanged: MusicOptions.instance.setCustomInstruments,
              ),
              if (MusicOptions.instance.customInstruments)
                SettingsRow(
                  key: const ValueKey('settings-ensemble-instruments'),
                  leading: const RowIcon(Icons.piano_outlined),
                  title: text.ensembleInstruments,
                  onTap: () => Navigator.push(
                      context, slideRoute(const EnsembleInstrumentsPage())),
                ),
            ]),
          ),
        ),

        // ---------------------------------------------------------- Languages
        SectionLabel(text.languagesSection.toUpperCase(),
            padding: sectionPadding()),
        HymnalCard(
          child: Column(children: [
            ValueListenableBuilder<Locale>(
              valueListenable: AppLanguage.instance,
              builder: (context, locale, _) => SettingsRow(
                leading: const RowIcon(Icons.translate),
                title: text.interfaceLanguage,
                trailing: RowValue(
                    interfaceLanguageNames[locale.languageCode] ?? 'English'),
                divider: true,
                onTap: () => showAppLanguagePicker(context),
              ),
            ),
            SettingsRow(
              key: const ValueKey('settings-hymnal-downloads'),
              leading: const RowIcon(Icons.download_outlined),
              title: text.languagePacks,
              subtitle: text.moreLanguagesHelp,
              onTap: () => Navigator.push(
                  context,
                  slideRoute(LanguagePacksPage(
                    onChanged: onPacksChanged ?? () async {},
                  ))),
            ),
          ]),
        ),

        // --------------------------------------------------------- Appearance
        SectionLabel(text.appearance.toUpperCase(), padding: sectionPadding()),
        HymnalCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DesignSelector(),
              const SizedBox(height: 16),
              Text(text.themeLabel,
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: t.ink)),
              const SizedBox(height: 10),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance,
                builder: (context, _, __) => SegmentedPills<String>(
                  options: [
                    ('light', text.light),
                    ('dark', text.dark),
                    ('system', text.system),
                  ],
                  selected: ThemeController.instance.pref,
                  onSelected: ThemeController.instance.setPref,
                ),
              ),
            ],
          ),
        ),

        // --------------------------------------------------------------- More
        SectionLabel(text.more.toUpperCase(), padding: sectionPadding()),
        HymnalCard(
          child: Column(children: [
            SettingsRow(
              leading: const RowIcon(Icons.history),
              title: text.readingHistory,
              divider: true,
              onTap: () => Navigator.push(context,
                  slideRoute(ReadingHistoryPage(hymns: historyHymns ?? hymns))),
            ),
            SettingsRow(
              leading: const RowIcon(Icons.auto_awesome_outlined),
              title: text.whatsNew,
              subtitle: text.releaseFeatures,
              divider: true,
              onTap: () => ReleaseNotesService.instance.showHistory(context),
            ),
            SettingsRow(
              leading: const RowIcon(Icons.flag_outlined),
              title: text.reportErrors,
              subtitle: text.reportGeneralIssue,
              divider: true,
              onTap: () =>
                  Navigator.push(context, slideRoute(const ReportErrorPage())),
            ),
            SettingsRow(
              leading: HymnalIcons.person(t.muted),
              title: text.aboutUs,
              subtitle: text.whoMadeApp,
              divider: true,
              onTap: () {
                AppAnalytics.instance.event('screen_view', variant: 'about');
                Navigator.push(context, slideRoute(const About()));
              },
            ),
            SettingsRow(
              leading: const RowIcon(Icons.volunteer_activism_outlined),
              title: text.otherProjects,
              subtitle: text.otherProjectsHelp,
              onTap: () {
                AppAnalytics.instance.event('screen_view', variant: 'projects');
                Navigator.push(context, slideRoute(const Sp()));
              },
            ),
          ]),
        ),

        // ------------------------------------------------ Privacy/statistics
        SectionLabel(text.privacyAndStatistics, padding: sectionPadding()),
        HymnalCard(
          child: AnimatedBuilder(
            animation: AppAnalytics.instance,
            builder: (context, _) => Column(children: [
              SettingsRow(
                leading: RowIcon(Icons.bar_chart_rounded, color: t.accent),
                title: text.communityStatistics,
                subtitle: text.communityStatisticsHelp,
                divider: true,
                onTap: () => Navigator.push(context,
                    slideRoute(StatisticsPage(hymns: historyHymns ?? hymns))),
              ),
              SettingsSwitchRow(
                key: const ValueKey('analytics-toggle'),
                leading: const RowIcon(Icons.insights_outlined),
                title: text.shareStatistics,
                subtitle: text.statisticsHelp,
                value: AppAnalytics.instance.enabled,
                onChanged: AppAnalytics.instance.available
                    ? AppAnalytics.instance.setEnabled
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(52, 0, 16, 4),
                child: Text(
                  text.statisticsStatusHelp(
                      text.statisticsStatus(AppAnalytics.instance.status)),
                  style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 11.5,
                      height: 1.35,
                      color: t.faint),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(44, 0, 8, 6),
                  child: TextButton(
                      onPressed: () => launchUrl(
                          Uri.parse('$analyticsEndpoint/privacy-policy'),
                          mode: LaunchMode.externalApplication),
                      child: Text(text.privacyPolicy)),
                ),
              ),
            ]),
          ),
        ),

        // ------------------------------------------------------------- Footer
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
              Text('Old & New SDA Hymnal',
                  style:
                      TextStyle(fontFamily: kSans, fontSize: 12, color: t.muted)),
              const SizedBox(height: 6),
              Text(text.versionLabel(appReleaseVersion),
                  style:
                      TextStyle(fontFamily: kSans, fontSize: 11, color: t.faint)),
            ],
          ),
        ),
      ],
    );
  }

  /// Chord-difficulty options: (pref id, label, description).
  List<(String, String, String)> _chordLevels(BuildContext context) => [
        ('simple', context.appText.simple, context.appText.simpleChordsHelp),
        ('medium', context.appText.medium, context.appText.mediumChordsHelp),
        (
          'original',
          context.appText.original,
          context.appText.originalChordsHelp
        ),
      ];

  void _showChordLevelSheet(BuildContext context) {
    final levels = _chordLevels(context);
    showHymnalSheet<void>(
      context,
      title: context.appText.chordDifficulty,
      builder: (sheet) => Column(children: [
        for (final (i, level) in levels.indexed)
          SheetOption(
            title: level.$2,
            subtitle: level.$3,
            selected: ChordLevelPref.instance.value == level.$1,
            divider: i < levels.length - 1,
            onTap: () {
              ChordLevelPref.instance.set(level.$1);
              Navigator.pop(sheet);
            },
          ),
      ]),
    );
  }
}

/// Switch row bound to a persisted preference.
class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.listenable,
    required this.leading,
    required this.title,
    this.subtitle,
    this.divider = false,
    required this.onChanged,
  });

  final ValueNotifier<bool> listenable;
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool divider;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: listenable,
        builder: (context, on, _) => SettingsSwitchRow(
          leading: leading,
          title: title,
          subtitle: subtitle,
          value: on,
          divider: divider,
          onChanged: onChanged,
        ),
      );
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
      builder: (context, _) {
        Widget option(AppDesign design, String label) {
          final selected = controller.value == design;
          return Expanded(
            child: Semantics(
              selected: selected,
              button: true,
              child: Pressable(
                key: ValueKey('design-${design.name}'),
                onTap: controller.iconBusy.value
                    ? null
                    : () => controller.set(design),
                pressedScale: 0.97,
                builder: (context, pressed) => Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? t.accent : t.surface,
                    border: Border.all(color: selected ? t.accent : t.line),
                    borderRadius: BorderRadius.circular(t.isClassic ? 4 : 999),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? t.onAccent : t.ink)),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.appText.appDesign,
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.ink)),
            const SizedBox(height: 4),
            Text(context.appText.appDesignHelp,
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 12.5,
                    height: 1.35,
                    color: t.muted)),
            const SizedBox(height: 12),
            Row(children: [
              option(AppDesign.modern, context.appText.modern),
              const SizedBox(width: 10),
              option(AppDesign.classic, context.appText.classic),
            ]),
            if (controller.iconBusy.value)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(context.appText.updatingIcon,
                    style: TextStyle(fontSize: 12.5, color: t.muted)),
              ),
            if (controller.iconError.value case final String message) ...[
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: t.ink, fontSize: 13)),
              TextButton(
                key: const ValueKey('retry-app-icon'),
                onPressed:
                    controller.iconBusy.value ? null : controller.syncIcon,
                child: Text(context.appText.retryIcon),
              ),
            ],
          ],
        );
      },
    );
  }
}
