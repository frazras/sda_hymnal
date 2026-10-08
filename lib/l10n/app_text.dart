import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// Standalone previews and older widget tests retain English without delegates.
extension HymnalAppText on BuildContext {
  AppLocalizations get appText =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}

/// Translate presentation labels without changing persisted music/analytics IDs.
extension HymnalOptionText on AppLocalizations {
  String styleLabel(String id) => switch (id) {
        'gospel' => modernGospel,
        'jazz' => jazz,
        'reggae' => islandReggae,
        'jamaican_gospel' => jamaicanGospel,
        'calypso' => steelPanCalypso,
        'organ' => cathedralOrgan,
        'strings' => strings,
        'choir' => choir,
        'musicbox' => musicBox,
        _ => classic,
      };
  String chordLevelLabel(String id) => switch (id) {
        'simple' => simple,
        'medium' => medium,
        _ => original,
      };
  String statisticsStatus(String status) => switch (status) {
        'Off' => statisticsOff,
        'Waiting for weekly upload' => statisticsWaiting,
        'Uploading' => statisticsUploading,
        'Weekly statistics sent' => statisticsSent,
        'More statistics queued' => statisticsQueued,
        'Saved offline; upload will retry later' => statisticsSavedOffline,
        _ => statisticsUnavailable,
      };
}
