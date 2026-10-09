import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sdahymnal/l10n/release_text.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/theme.dart';

class ReleaseNotesService {
  ReleaseNotesService._();
  static final ReleaseNotesService instance = ReleaseNotesService._();

  static const assetPath = 'assets/release_notes.json';
  static const seenVersionsKey = 'seenReleaseVersions';

  ReleaseNotesCatalog? _catalog;

  Future<ReleaseNotesCatalog> load() async {
    // Parse the published English dates even in standalone English previews.
    await initializeDateFormatting('en');
    return _catalog ??=
        ReleaseNotesCatalog.fromJson(await rootBundle.loadString(assetPath));
  }

  Future<void> showIfNeeded(BuildContext context) async {
    final preferences = await SharedPreferences.getInstance();
    final seen = preferences.getStringList(seenVersionsKey) ?? const <String>[];
    if (!context.mounted || seen.contains(appReleaseVersion)) return;
    final catalog = await load();
    if (!context.mounted) return;
    await _show(context, catalog, updated: true);
    await preferences.setStringList(
      seenVersionsKey,
      {...seen, appReleaseVersion}.toList(),
    );
  }

  Future<void> showHistory(BuildContext context) async {
    final catalog = await load();
    if (!context.mounted) return;
    await _show(context, catalog, updated: false);
  }

  Future<void> _show(
    BuildContext context,
    ReleaseNotesCatalog catalog, {
    required bool updated,
  }) {
    AppAnalytics.instance.event('screen_view', variant: 'release_notes');
    return showDialog<void>(
      context: context,
      builder: (context) => _ReleaseHistoryDialog(
        catalog: catalog,
        updated: updated,
      ),
    );
  }
}

class _ReleaseHistoryDialog extends StatelessWidget {
  const _ReleaseHistoryDialog({required this.catalog, required this.updated});

  final ReleaseNotesCatalog catalog;
  final bool updated;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  key: const ValueKey('release-notes-history'),
                  children: [
                    Text(
                      updated
                          ? context.appText.appUpdated
                          : context.appText.whatsNew,
                      key: const ValueKey('release-notes-title'),
                      style: TextStyle(
                        color: t.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      updated
                          ? context.appText.updateHistoryIntro
                          : context.appText.releaseHistoryIntro,
                      style: TextStyle(color: t.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    for (var index = 0;
                        index < catalog.releases.length;
                        index++) ...[
                      if (index > 0) Divider(color: t.line),
                      _release(context, t, catalog.releases[index], index == 0),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('release-notes-done'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.appText.done),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _release(
      BuildContext context, HymnalTokens t, AppRelease release, bool latest) {
    final translated =
        translatedReleaseFeatures(context.appText, release.version);
    // New or amended release entries remain readable until their translations arrive.
    final features = translated?.length == release.features.length
        ? translated!
        : release.features;
    final date = DateFormat('MMMM d, y', 'en').tryParseStrict(release.date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.appText.versionLabel(release.version),
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (latest)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(context.appText.latestRelease,
                      style: TextStyle(
                          color: t.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          Text(
              date == null
                  ? release.date
                  : MaterialLocalizations.of(context).formatMediumDate(date),
              style: TextStyle(color: t.muted, fontSize: 12)),
          const SizedBox(height: 7),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: t.accent)),
                  Expanded(
                    child: Text(feature,
                        style: TextStyle(color: t.ink, height: 1.3)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
