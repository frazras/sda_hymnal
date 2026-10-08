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
  /// **'Font Size'**
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
  /// **'Report Errors'**
  String get reportErrors;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
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

  /// No description provided for @readerOptions.
  ///
  /// In en, this message translates to:
  /// **'Reader options'**
  String get readerOptions;

  /// No description provided for @copyOrShareLyrics.
  ///
  /// In en, this message translates to:
  /// **'Copy or share lyrics'**
  String get copyOrShareLyrics;

  /// No description provided for @previousItem.
  ///
  /// In en, this message translates to:
  /// **'Previous item'**
  String get previousItem;

  /// No description provided for @nextItem.
  ///
  /// In en, this message translates to:
  /// **'Next item'**
  String get nextItem;

  /// No description provided for @swipeToTurn.
  ///
  /// In en, this message translates to:
  /// **'Swipe to turn the page'**
  String get swipeToTurn;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add favorite'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get removeFavorite;

  /// No description provided for @saveToFavoriteLists.
  ///
  /// In en, this message translates to:
  /// **'Save to favorites and categories'**
  String get saveToFavoriteLists;

  /// No description provided for @endOfHymn.
  ///
  /// In en, this message translates to:
  /// **'End of hymn'**
  String get endOfHymn;

  /// No description provided for @hymnalHome.
  ///
  /// In en, this message translates to:
  /// **'Hymnal home'**
  String get hymnalHome;

  /// No description provided for @searchHymns.
  ///
  /// In en, this message translates to:
  /// **'Search Hymns'**
  String get searchHymns;

  /// No description provided for @autoplayHelp.
  ///
  /// In en, this message translates to:
  /// **'After you press Play, continue through this list until paused'**
  String get autoplayHelp;

  /// No description provided for @musiciansAndChoir.
  ///
  /// In en, this message translates to:
  /// **'MUSICIANS & CHOIR'**
  String get musiciansAndChoir;

  /// No description provided for @customizeInstruments.
  ///
  /// In en, this message translates to:
  /// **'Customize musical style instruments'**
  String get customizeInstruments;

  /// No description provided for @customizeInstrumentsHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose instruments, volume and solos for each musical style'**
  String get customizeInstrumentsHelp;

  /// No description provided for @ensembleInstruments.
  ///
  /// In en, this message translates to:
  /// **'Ensemble instruments'**
  String get ensembleInstruments;

  /// No description provided for @choirPracticeHelp.
  ///
  /// In en, this message translates to:
  /// **'Show vocal part controls in the hymn player. Uses original music, without styles.'**
  String get choirPracticeHelp;

  /// No description provided for @choirPracticeOn.
  ///
  /// In en, this message translates to:
  /// **'Choir practice is on. It overrides the selected musical style and uses the original vocal parts.'**
  String get choirPracticeOn;

  /// No description provided for @choirPracticeOff.
  ///
  /// In en, this message translates to:
  /// **'Choir practice is off. Your selected musical style is active again.'**
  String get choirPracticeOff;

  /// No description provided for @reportGeneralIssue.
  ///
  /// In en, this message translates to:
  /// **'Report a general app issue'**
  String get reportGeneralIssue;

  /// No description provided for @whoMadeApp.
  ///
  /// In en, this message translates to:
  /// **'Who made this app?'**
  String get whoMadeApp;

  /// No description provided for @releaseFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features added in each version'**
  String get releaseFeatures;

  /// No description provided for @otherProjects.
  ///
  /// In en, this message translates to:
  /// **'Our Other Projects'**
  String get otherProjects;

  /// No description provided for @otherProjectsHelp.
  ///
  /// In en, this message translates to:
  /// **'Like this app? You will love our ministry!'**
  String get otherProjectsHelp;

  /// No description provided for @privacyAndStatistics.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY & STATISTICS'**
  String get privacyAndStatistics;

  /// No description provided for @communityStatistics.
  ///
  /// In en, this message translates to:
  /// **'Community statistics'**
  String get communityStatistics;

  /// No description provided for @communityStatisticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Popular hymns, repeat visits, and times of worship'**
  String get communityStatisticsHelp;

  /// No description provided for @shareStatistics.
  ///
  /// In en, this message translates to:
  /// **'Share usage statistics'**
  String get shareStatistics;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @appDesign.
  ///
  /// In en, this message translates to:
  /// **'App design'**
  String get appDesign;

  /// No description provided for @modern.
  ///
  /// In en, this message translates to:
  /// **'Modern'**
  String get modern;

  /// No description provided for @classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get classic;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @updatingIcon.
  ///
  /// In en, this message translates to:
  /// **'Updating home-screen icon…'**
  String get updatingIcon;

  /// No description provided for @retryIcon.
  ///
  /// In en, this message translates to:
  /// **'Retry icon change'**
  String get retryIcon;

  /// No description provided for @simple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get simple;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @original.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get original;

  /// No description provided for @simpleChordsHelp.
  ///
  /// In en, this message translates to:
  /// **'Major and minor only'**
  String get simpleChordsHelp;

  /// No description provided for @mediumChordsHelp.
  ///
  /// In en, this message translates to:
  /// **'Sevenths where they resolve'**
  String get mediumChordsHelp;

  /// No description provided for @originalChordsHelp.
  ///
  /// In en, this message translates to:
  /// **'As detected'**
  String get originalChordsHelp;

  /// No description provided for @modernGospel.
  ///
  /// In en, this message translates to:
  /// **'Modern Gospel'**
  String get modernGospel;

  /// No description provided for @jazz.
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get jazz;

  /// No description provided for @islandReggae.
  ///
  /// In en, this message translates to:
  /// **'Island Reggae'**
  String get islandReggae;

  /// No description provided for @jamaicanGospel.
  ///
  /// In en, this message translates to:
  /// **'Jamaican Gospel'**
  String get jamaicanGospel;

  /// No description provided for @steelPanCalypso.
  ///
  /// In en, this message translates to:
  /// **'Steel Pan Calypso'**
  String get steelPanCalypso;

  /// No description provided for @cathedralOrgan.
  ///
  /// In en, this message translates to:
  /// **'Cathedral Organ'**
  String get cathedralOrgan;

  /// No description provided for @strings.
  ///
  /// In en, this message translates to:
  /// **'Strings'**
  String get strings;

  /// No description provided for @choir.
  ///
  /// In en, this message translates to:
  /// **'Choir'**
  String get choir;

  /// No description provided for @musicBox.
  ///
  /// In en, this message translates to:
  /// **'Music Box'**
  String get musicBox;

  /// No description provided for @appDesignHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose the new look or the familiar original layout.\nThe home-screen icon changes to match. Your hymns, favorites and music settings stay the same.'**
  String get appDesignHelp;

  /// No description provided for @statisticsHelp.
  ///
  /// In en, this message translates to:
  /// **'Help improve the hymnal and community trends. Enabled by default; you can turn this off anytime. Usage and error summaries are sent about weekly. Country is estimated from the upload connection. No names, search text, advertising, or personalized content.'**
  String get statisticsHelp;

  /// No description provided for @statisticsStatusHelp.
  ///
  /// In en, this message translates to:
  /// **'{status}. Turning this off clears queued statistics and local analytics identifiers. Previously combined statistics follow the privacy policy retention periods.'**
  String statisticsStatusHelp(String status);

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @statisticsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Statistics unavailable'**
  String get statisticsUnavailable;

  /// No description provided for @statisticsOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get statisticsOff;

  /// No description provided for @statisticsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for weekly upload'**
  String get statisticsWaiting;

  /// No description provided for @statisticsUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get statisticsUploading;

  /// No description provided for @statisticsSent.
  ///
  /// In en, this message translates to:
  /// **'Weekly statistics sent'**
  String get statisticsSent;

  /// No description provided for @statisticsQueued.
  ///
  /// In en, this message translates to:
  /// **'More statistics queued'**
  String get statisticsQueued;

  /// No description provided for @statisticsSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved offline; upload will retry later'**
  String get statisticsSavedOffline;

  /// No description provided for @hymnsByOccasion.
  ///
  /// In en, this message translates to:
  /// **'Hymns by occasion'**
  String get hymnsByOccasion;

  /// No description provided for @additionalReadings.
  ///
  /// In en, this message translates to:
  /// **'Additional readings'**
  String get additionalReadings;

  /// No description provided for @hymnOrReadingNumber.
  ///
  /// In en, this message translates to:
  /// **'HYMN OR READING NUMBER'**
  String get hymnOrReadingNumber;

  /// No description provided for @hymnNumberHeading.
  ///
  /// In en, this message translates to:
  /// **'HYMN NUMBER'**
  String get hymnNumberHeading;

  /// No description provided for @clearNumber.
  ///
  /// In en, this message translates to:
  /// **'Clear number'**
  String get clearNumber;

  /// No description provided for @deleteDigit.
  ///
  /// In en, this message translates to:
  /// **'Delete digit'**
  String get deleteDigit;
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
