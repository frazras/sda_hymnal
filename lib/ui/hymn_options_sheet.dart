import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/services/hymn_recordings.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/kit.dart';

/// Everything the reader can offer for one hymn. Unavailable media are
/// simply absent, so every language shows the same sheet with fewer rows.
class HymnOptions {
  const HymnOptions({
    required this.sheetMusicAvailable,
    required this.sheetMusicVisible,
    required this.videoAvailable,
    required this.videoVisible,
    required this.hasMidi,
    required this.hasMusic,
    this.recordingKinds = const [],
    required this.autoScrollAvailable,
    required this.onSheetMusic,
    required this.onVideo,
    required this.onTextSize,
    required this.onShare,
    required this.onReport,
    required this.onMusicalStyle,
    required this.onPlayer,
    required this.onChords,
    required this.onAutoScroll,
    required this.onScrollSpeed,
    required this.onChoir,
  });

  final bool sheetMusicAvailable;
  final bool sheetMusicVisible;
  final bool videoAvailable;
  final bool videoVisible;
  final bool hasMidi;
  final bool hasMusic;

  /// Recorded performances available for this hymn (two offers a choice).
  final List<RecordingKind> recordingKinds;
  final bool autoScrollAvailable;
  final VoidCallback onSheetMusic;
  final VoidCallback onVideo;
  final VoidCallback onTextSize;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onMusicalStyle;
  final ValueChanged<bool> onPlayer;
  final ValueChanged<bool> onChords;
  final ValueChanged<bool> onAutoScroll;
  final VoidCallback onScrollSpeed;
  final ValueChanged<bool> onChoir;
}

/// Reader options: quick actions on top, switches below, report last.
/// Every choice closes the sheet so its effect is visible at once.
Future<void> showHymnOptionsSheet(BuildContext context, HymnOptions o) {
  return showHymnalSheet<void>(
    context,
    title: context.appText.readerOptions,
    builder: (sheet) {
      void close(VoidCallback action) {
        Navigator.pop(sheet);
        action();
      }

      final t = sheet.tokens;
      return AnimatedBuilder(
        animation: Listenable.merge([
          RecordingVoice.instance,
          MusicPlayerVisible.instance,
          ChordTabs.instance,
          AutoScroll.instance,
          MusicOptions.instance,
          InstrumentTheme.instance,
        ]),
        builder: (context, _) {
          final tiles = <Widget>[
            if (o.sheetMusicAvailable)
              _ActionTile(
                key: const ValueKey('hymn-sheet-music'),
                icon: o.sheetMusicVisible
                    ? Icons.notes
                    : Icons.library_music_outlined,
                label: o.sheetMusicVisible
                    ? context.appText.showLyrics
                    : context.appText.sheetMusic,
                onTap: () => close(o.onSheetMusic),
              ),
            if (o.videoAvailable)
              _ActionTile(
                key: const ValueKey('hymn-youtube-button'),
                icon: Icons.smart_display_outlined,
                label: o.videoVisible
                    ? context.appText.restartHymnVideo
                    : context.appText.videoShort,
                onTap: () => close(o.onVideo),
              ),
            if (!o.sheetMusicVisible)
              _ActionTile(
                key: const ValueKey('hymn-font-size-button'),
                icon: Icons.text_fields,
                label: context.appText.textSize,
                onTap: () => close(o.onTextSize),
              ),
            _ActionTile(
              key: const ValueKey('hymn-share-lyrics'),
              icon: Icons.ios_share,
              label: context.appText.shareControl,
              onTap: () => close(o.onShare),
            ),
          ];
          final switches = <Widget>[
            if (o.recordingKinds.length > 1)
              Container(
                key: const ValueKey('hymn-recording-choice'),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: t.line2))),
                child: Row(children: [
                  const RowIcon(Icons.graphic_eq),
                  const SizedBox(width: 14),
                  Text(context.appText.recordingKindLabel,
                      style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.ink)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedPills<RecordingKind>(
                      options: [
                        for (final kind in o.recordingKinds)
                          (
                            kind,
                            kind == RecordingKind.sung
                                ? context.appText.recordingSung
                                : context.appText.recordingInstrumental
                          ),
                      ],
                      selected: RecordingVoice.instance.value,
                      onSelected: RecordingVoice.instance.set,
                    ),
                  ),
                ]),
              ),
            if (o.hasMidi)
              SettingsRow(
                key: const ValueKey('hymn-musical-style'),
                leading: const RowIcon(Icons.music_note_outlined),
                title: context.appText.musicalStyle,
                trailing: RowValue(MusicOptions.instance.choirPractice
                    ? context.appText.choirPractice
                    : context.appText.styleLabel(InstrumentTheme.instance.value)),
                divider: true,
                onTap: () => close(o.onMusicalStyle),
              ),
            if (o.hasMusic)
              SettingsSwitchRow(
                key: const ValueKey('hymn-player-visibility'),
                leading: const RowIcon(Icons.play_circle_outline),
                title: context.appText.musicPlayer,
                value: MusicPlayerVisible.instance.value,
                divider: true,
                onChanged: (on) => close(() => o.onPlayer(on)),
              ),
            if (o.hasMidi)
              SettingsSwitchRow(
                key: const ValueKey('hymn-chord-tabs'),
                leading: const RowIcon(Icons.piano),
                title: context.appText.chordTabs,
                value: ChordTabs.instance.value,
                divider: true,
                onChanged: (on) => close(() => o.onChords(on)),
              ),
            if (o.hasMidi)
              SettingsSwitchRow(
                key: const ValueKey('hymn-choir-practice'),
                leading: const RowIcon(Icons.groups_outlined),
                title: context.appText.choirPractice,
                // Says plainly that practice replaces the chosen style.
                subtitle: MusicOptions.instance.choirPractice
                    ? context.appText.choirPracticeOn
                    : null,
                value: MusicOptions.instance.choirPractice,
                divider: true,
                onChanged: (on) => close(() => o.onChoir(on)),
              ),
            if (o.autoScrollAvailable)
              SettingsSwitchRow(
                key: const ValueKey('hymn-auto-scroll'),
                leading: const RowIcon(Icons.vertical_align_bottom),
                title: context.appText.autoScroll,
                value: AutoScroll.instance.value,
                divider: true,
                onChanged: (on) => close(() {
                  o.onAutoScroll(on);
                  if (on) o.onScrollSpeed();
                }),
              ),
            if (o.autoScrollAvailable && AutoScroll.instance.value)
              SettingsRow(
                key: const ValueKey('hymn-scroll-speed-menu-item'),
                leading: const RowIcon(Icons.speed),
                title: context.appText.scrollSpeed,
                divider: true,
                onTap: () => close(o.onScrollSpeed),
              ),
          ];
          return Column(
            key: const ValueKey('hymn-options-sheet'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Row(children: [
                  for (final (i, tile) in tiles.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: tile),
                  ],
                ]),
              ),
              if (switches.isNotEmpty)
                Container(
                  decoration:
                      BoxDecoration(border: Border(top: BorderSide(color: t.line2))),
                  child: Column(children: switches),
                ),
              SettingsRow(
                key: const ValueKey('hymn-report-error'),
                leading: const RowIcon(Icons.flag_outlined),
                title: context.appText.reportErrors,
                onTap: () => close(o.onReport),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: t.surface2,
        borderRadius: BorderRadius.circular(t.isClassic ? 4 : 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.isClassic ? 4 : 14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: t.accent),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
