import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
    Locale('ru')
  ];

  /// No description provided for @numbers.
  ///
  /// In en, this message translates to:
  /// **'Numbers'**
  String get numbers;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get interfaceLanguage;

  /// No description provided for @interfaceLanguageHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for menus and controls.'**
  String get interfaceLanguageHelp;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @keepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get keepScreenOn;

  /// No description provided for @keepScreenOnHelp.
  ///
  /// In en, this message translates to:
  /// **'Stay awake while a hymn is open'**
  String get keepScreenOnHelp;

  /// No description provided for @autoScroll.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll'**
  String get autoScroll;

  /// No description provided for @autoScrollHelp.
  ///
  /// In en, this message translates to:
  /// **'Follow the hymn automatically, with or without music'**
  String get autoScrollHelp;

  /// No description provided for @musicalStyle.
  ///
  /// In en, this message translates to:
  /// **'Musical style'**
  String get musicalStyle;

  /// No description provided for @musicalStyleHelp.
  ///
  /// In en, this message translates to:
  /// **'How hymn music sounds'**
  String get musicalStyleHelp;

  /// No description provided for @autoplay.
  ///
  /// In en, this message translates to:
  /// **'Autoplay video and music'**
  String get autoplay;

  /// No description provided for @choirPractice.
  ///
  /// In en, this message translates to:
  /// **'Choir practice'**
  String get choirPractice;

  /// No description provided for @chordTabs.
  ///
  /// In en, this message translates to:
  /// **'Chord tabs'**
  String get chordTabs;

  /// No description provided for @chordTabsHelp.
  ///
  /// In en, this message translates to:
  /// **'Play-along chords for musicians'**
  String get chordTabsHelp;

  /// No description provided for @chordDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Chord difficulty'**
  String get chordDifficulty;

  /// No description provided for @chordDifficultyHelp.
  ///
  /// In en, this message translates to:
  /// **'Simplify chords for learners'**
  String get chordDifficultyHelp;

  /// No description provided for @readingHistory.
  ///
  /// In en, this message translates to:
  /// **'Reading history'**
  String get readingHistory;

  /// No description provided for @reportErrors.
  ///
  /// In en, this message translates to:
  /// **'Report errors'**
  String get reportErrors;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About us'**
  String get aboutUs;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What’s new'**
  String get whatsNew;

  /// No description provided for @playHymn.
  ///
  /// In en, this message translates to:
  /// **'Play hymn'**
  String get playHymn;

  /// No description provided for @pauseHymn.
  ///
  /// In en, this message translates to:
  /// **'Pause hymn'**
  String get pauseHymn;

  /// No description provided for @previousHymn.
  ///
  /// In en, this message translates to:
  /// **'Previous hymn'**
  String get previousHymn;

  /// No description provided for @nextHymn.
  ///
  /// In en, this message translates to:
  /// **'Next hymn'**
  String get nextHymn;

  /// No description provided for @sheetMusic.
  ///
  /// In en, this message translates to:
  /// **'Sheet music'**
  String get sheetMusic;

  /// No description provided for @showLyrics.
  ///
  /// In en, this message translates to:
  /// **'Show lyrics'**
  String get showLyrics;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @scrollSpeed.
  ///
  /// In en, this message translates to:
  /// **'Scroll speed'**
  String get scrollSpeed;

  /// No description provided for @showMusicPlayer.
  ///
  /// In en, this message translates to:
  /// **'Show music player'**
  String get showMusicPlayer;

  /// No description provided for @hideMusicPlayer.
  ///
  /// In en, this message translates to:
  /// **'Hide music player'**
  String get hideMusicPlayer;

  /// No description provided for @showChordTabs.
  ///
  /// In en, this message translates to:
  /// **'Show chord tabs'**
  String get showChordTabs;

  /// No description provided for @hideChordTabs.
  ///
  /// In en, this message translates to:
  /// **'Hide chord tabs'**
  String get hideChordTabs;

  /// No description provided for @playHymnVideo.
  ///
  /// In en, this message translates to:
  /// **'Play hymn video'**
  String get playHymnVideo;

  /// No description provided for @restartHymnVideo.
  ///
  /// In en, this message translates to:
  /// **'Restart hymn video'**
  String get restartHymnVideo;

  /// No description provided for @copyLyrics.
  ///
  /// In en, this message translates to:
  /// **'Copy lyrics'**
  String get copyLyrics;

  /// No description provided for @shareLyrics.
  ///
  /// In en, this message translates to:
  /// **'Share lyrics'**
  String get shareLyrics;

  /// No description provided for @topics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get topics;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @allHymnals.
  ///
  /// In en, this message translates to:
  /// **'All hymnals'**
  String get allHymnals;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @musicLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load music. Check your connection and try again.'**
  String get musicLoadError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
