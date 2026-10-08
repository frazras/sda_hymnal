import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';

/// Standalone previews and older widget tests retain English without delegates.
extension HymnalAppText on BuildContext {
  AppLocalizations get appText =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();
}
