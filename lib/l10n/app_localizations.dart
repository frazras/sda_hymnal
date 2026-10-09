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

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @newHymnal.
  ///
  /// In en, this message translates to:
  /// **'New Hymnal'**
  String get newHymnal;

  /// No description provided for @oldHymnal.
  ///
  /// In en, this message translates to:
  /// **'Old Hymnal'**
  String get oldHymnal;

  /// No description provided for @newEdition.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newEdition;

  /// No description provided for @oldEdition.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get oldEdition;

  /// No description provided for @hymnsLabel.
  ///
  /// In en, this message translates to:
  /// **'Hymns'**
  String get hymnsLabel;

  /// No description provided for @searchByTitleLyricsNumber.
  ///
  /// In en, this message translates to:
  /// **'Search by title, lyrics or number'**
  String get searchByTitleLyricsNumber;

  /// No description provided for @hymnNumber.
  ///
  /// In en, this message translates to:
  /// **'Hymn number'**
  String get hymnNumber;

  /// No description provided for @chooseHymnal.
  ///
  /// In en, this message translates to:
  /// **'Choose hymnal'**
  String get chooseHymnal;

  /// No description provided for @allLanguages.
  ///
  /// In en, this message translates to:
  /// **'All languages'**
  String get allLanguages;

  /// No description provided for @searchAllLanguages.
  ///
  /// In en, this message translates to:
  /// **'Search all languages'**
  String get searchAllLanguages;

  /// No description provided for @allHymns.
  ///
  /// In en, this message translates to:
  /// **'All hymns'**
  String get allHymns;

  /// No description provided for @noMatchingHymns.
  ///
  /// In en, this message translates to:
  /// **'No matching hymns.'**
  String get noMatchingHymns;

  /// No description provided for @noHymnInEdition.
  ///
  /// In en, this message translates to:
  /// **'No hymn found in this edition.'**
  String get noHymnInEdition;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @hymnCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} hymn} other{{count} hymns}}'**
  String hymnCount(num count);

  /// No description provided for @matchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} match} other{{count} matches}}'**
  String matchCount(num count);

  /// No description provided for @hymnCountScope.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} hymn} other{{count} hymns}} · {scope}'**
  String hymnCountScope(num count, String scope);

  /// No description provided for @hymnalFilter.
  ///
  /// In en, this message translates to:
  /// **'Hymnal filter: {filter}'**
  String hymnalFilter(String filter);

  /// No description provided for @titleLyricsNumber.
  ///
  /// In en, this message translates to:
  /// **'Title, lyrics or number'**
  String get titleLyricsNumber;

  /// No description provided for @newFavoriteCategory.
  ///
  /// In en, this message translates to:
  /// **'New favorite category'**
  String get newFavoriteCategory;

  /// No description provided for @renameFavoriteCategory.
  ///
  /// In en, this message translates to:
  /// **'Rename favorite category'**
  String get renameFavoriteCategory;

  /// No description provided for @moreFavoritesOptions.
  ///
  /// In en, this message translates to:
  /// **'More favorites options'**
  String get moreFavoritesOptions;

  /// No description provided for @servicePlaylists.
  ///
  /// In en, this message translates to:
  /// **'Service playlists'**
  String get servicePlaylists;

  /// No description provided for @deleteCategoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Hymns saved in other categories or Favorites will stay there.'**
  String get deleteCategoryHelp;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @reorderHymns.
  ///
  /// In en, this message translates to:
  /// **'Reorder hymns'**
  String get reorderHymns;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete category'**
  String get deleteCategory;

  /// No description provided for @emptyFavoriteCategory.
  ///
  /// In en, this message translates to:
  /// **'Tap a hymn’s heart to add it to this favorite category.'**
  String get emptyFavoriteCategory;

  /// No description provided for @mainFavorites.
  ///
  /// In en, this message translates to:
  /// **'Main favorites'**
  String get mainFavorites;

  /// No description provided for @mainFavoritesList.
  ///
  /// In en, this message translates to:
  /// **'Main favorites list'**
  String get mainFavoritesList;

  /// No description provided for @reorderFavorites.
  ///
  /// In en, this message translates to:
  /// **'Reorder favorites'**
  String get reorderFavorites;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @addFavoritesHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any hymn to save it here'**
  String get addFavoritesHelp;

  /// No description provided for @saveToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Save to favorites'**
  String get saveToFavorites;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @categoryNameExample.
  ///
  /// In en, this message translates to:
  /// **'My childhood songs'**
  String get categoryNameExample;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @listNameLengthError.
  ///
  /// In en, this message translates to:
  /// **'Use a name between 1 and 60 characters.'**
  String get listNameLengthError;

  /// No description provided for @listNameDuplicateError.
  ///
  /// In en, this message translates to:
  /// **'Choose a different list name.'**
  String get listNameDuplicateError;

  /// No description provided for @reorderHelp.
  ///
  /// In en, this message translates to:
  /// **'Drag a handle to change the order. Changes are saved automatically.'**
  String get reorderHelp;

  /// No description provided for @hymnUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Hymn unavailable'**
  String get hymnUnavailable;

  /// No description provided for @favoritesAndRecents.
  ///
  /// In en, this message translates to:
  /// **'Favorites and recent hymns'**
  String get favoritesAndRecents;

  /// No description provided for @recentHymns.
  ///
  /// In en, this message translates to:
  /// **'Recent hymns'**
  String get recentHymns;

  /// No description provided for @manageList.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String manageList(String name);

  /// No description provided for @deleteListQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteListQuestion(String name);

  /// No description provided for @reorderList.
  ///
  /// In en, this message translates to:
  /// **'Reorder {name}'**
  String reorderList(String name);

  /// No description provided for @moveHymn.
  ///
  /// In en, this message translates to:
  /// **'Move {name}'**
  String moveHymn(String name);

  /// No description provided for @savedListError.
  ///
  /// In en, this message translates to:
  /// **'{name} could not be loaded or saved. Changes are paused to protect your saved lists.'**
  String savedListError(String name);

  /// No description provided for @retryLoading.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryLoading;

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @key.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get key;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @chords.
  ///
  /// In en, this message translates to:
  /// **'Chords'**
  String get chords;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @notDocumented.
  ///
  /// In en, this message translates to:
  /// **'Not documented'**
  String get notDocumented;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @lyricsSize.
  ///
  /// In en, this message translates to:
  /// **'Lyrics size'**
  String get lyricsSize;

  /// No description provided for @autoScrollSpeed.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll speed'**
  String get autoScrollSpeed;

  /// No description provided for @slowerScroll.
  ///
  /// In en, this message translates to:
  /// **'Slower  0.5×'**
  String get slowerScroll;

  /// No description provided for @fasterScroll.
  ///
  /// In en, this message translates to:
  /// **'2.0×  Faster'**
  String get fasterScroll;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @autoScrollNoMidi.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll unavailable: no MIDI'**
  String get autoScrollNoMidi;

  /// No description provided for @loadingScrollTiming.
  ///
  /// In en, this message translates to:
  /// **'Loading auto-scroll timing…'**
  String get loadingScrollTiming;

  /// No description provided for @autoScrollNoTiming.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll unavailable: no MIDI timing'**
  String get autoScrollNoTiming;

  /// No description provided for @entireHymnFits.
  ///
  /// In en, this message translates to:
  /// **'Entire hymn fits on screen'**
  String get entireHymnFits;

  /// No description provided for @scrollMusicPaused.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll • music paused'**
  String get scrollMusicPaused;

  /// No description provided for @startAutoScroll.
  ///
  /// In en, this message translates to:
  /// **'Start auto-scroll'**
  String get startAutoScroll;

  /// No description provided for @wordsCredit.
  ///
  /// In en, this message translates to:
  /// **'Words: {names}'**
  String wordsCredit(String names);

  /// No description provided for @musicCredit.
  ///
  /// In en, this message translates to:
  /// **'Music: {names}'**
  String musicCredit(String names);

  /// No description provided for @keyValue.
  ///
  /// In en, this message translates to:
  /// **'Key · {value}'**
  String keyValue(String value);

  /// No description provided for @keyOf.
  ///
  /// In en, this message translates to:
  /// **'Key of {value}'**
  String keyOf(String value);

  /// No description provided for @originalKey.
  ///
  /// In en, this message translates to:
  /// **'Original · {value}'**
  String originalKey(String value);

  /// No description provided for @resetScrollSpeed.
  ///
  /// In en, this message translates to:
  /// **'Reset to {speed}'**
  String resetScrollSpeed(String speed);

  /// No description provided for @scrollSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Scroll {speed}'**
  String scrollSpeedLabel(String speed);

  /// No description provided for @scrollSpeedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-scroll: {speed}'**
  String scrollSpeedTooltip(String speed);

  /// No description provided for @readStories.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Read story} other{Read {count} stories}}'**
  String readStories(num count);

  /// No description provided for @clearHistoryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear reading history?'**
  String get clearHistoryQuestion;

  /// No description provided for @clearHistoryHelp.
  ///
  /// In en, this message translates to:
  /// **'This removes recently opened hymns. Your favorites and categories will stay.'**
  String get clearHistoryHelp;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @noRecentHymns.
  ///
  /// In en, this message translates to:
  /// **'No recently opened hymns'**
  String get noRecentHymns;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @scoreLoadError.
  ///
  /// In en, this message translates to:
  /// **'Sheet music could not be loaded.'**
  String get scoreLoadError;

  /// No description provided for @scoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sheet music is not available for this hymn yet.'**
  String get scoreUnavailable;

  /// No description provided for @scorePageError.
  ///
  /// In en, this message translates to:
  /// **'This score page could not be loaded.'**
  String get scorePageError;

  /// No description provided for @previousScorePage.
  ///
  /// In en, this message translates to:
  /// **'Previous score page'**
  String get previousScorePage;

  /// No description provided for @nextScorePage.
  ///
  /// In en, this message translates to:
  /// **'Next score page'**
  String get nextScorePage;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @fitScore.
  ///
  /// In en, this message translates to:
  /// **'Fit score to screen'**
  String get fitScore;

  /// No description provided for @printedScoreHelp.
  ///
  /// In en, this message translates to:
  /// **'Original printed score · Pinch to zoom'**
  String get printedScoreHelp;

  /// No description provided for @closeVideo.
  ///
  /// In en, this message translates to:
  /// **'Close video'**
  String get closeVideo;

  /// No description provided for @hymnStory.
  ///
  /// In en, this message translates to:
  /// **'Story Behind the Hymn'**
  String get hymnStory;

  /// No description provided for @storyPublisherHelp.
  ///
  /// In en, this message translates to:
  /// **'A full supplemental story is available from this publisher.'**
  String get storyPublisherHelp;

  /// No description provided for @pageOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{page} of {total}'**
  String pageOfTotal(int page, int total);

  /// No description provided for @scorePageDescription.
  ///
  /// In en, this message translates to:
  /// **'Printed score for hymn {number}, page {page} of {total}'**
  String scorePageDescription(int number, int page, int total);

  /// No description provided for @reportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your error report has been submitted.'**
  String get reportSubmitted;

  /// No description provided for @reportSendError.
  ///
  /// In en, this message translates to:
  /// **'Could not send your report. Check your connection and try again. Your text is still here.'**
  String get reportSendError;

  /// No description provided for @reportGeneralInstead.
  ///
  /// In en, this message translates to:
  /// **'Report a general app issue instead'**
  String get reportGeneralInstead;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reportTitle;

  /// No description provided for @reportTitleHint.
  ///
  /// In en, this message translates to:
  /// **'What is the error about?'**
  String get reportTitleHint;

  /// No description provided for @reportTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get reportTitleRequired;

  /// No description provided for @reportDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe the error'**
  String get reportDescription;

  /// No description provided for @reportDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what is wrong and, if possible, what it should say.'**
  String get reportDescriptionHint;

  /// No description provided for @reportPrivacyHelp.
  ///
  /// In en, this message translates to:
  /// **'Your report will be sent to the app administrators. Please do not include personal or sensitive information.'**
  String get reportPrivacyHelp;

  /// No description provided for @sendingReport.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sendingReport;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get submitReport;

  /// No description provided for @hymnLabel.
  ///
  /// In en, this message translates to:
  /// **'Hymn'**
  String get hymnLabel;

  /// No description provided for @reportSubject.
  ///
  /// In en, this message translates to:
  /// **'{book} · {kind} {number}'**
  String reportSubject(String book, String kind, int number);

  /// No description provided for @gmProgram0.
  ///
  /// In en, this message translates to:
  /// **'Grand piano'**
  String get gmProgram0;

  /// No description provided for @gmProgram1.
  ///
  /// In en, this message translates to:
  /// **'Bright grand piano'**
  String get gmProgram1;

  /// No description provided for @gmProgram2.
  ///
  /// In en, this message translates to:
  /// **'Electric grand piano'**
  String get gmProgram2;

  /// No description provided for @gmProgram3.
  ///
  /// In en, this message translates to:
  /// **'Honky-tonk piano'**
  String get gmProgram3;

  /// No description provided for @gmProgram4.
  ///
  /// In en, this message translates to:
  /// **'Electric piano'**
  String get gmProgram4;

  /// No description provided for @gmProgram5.
  ///
  /// In en, this message translates to:
  /// **'FM electric piano'**
  String get gmProgram5;

  /// No description provided for @gmProgram6.
  ///
  /// In en, this message translates to:
  /// **'Harpsichord'**
  String get gmProgram6;

  /// No description provided for @gmProgram7.
  ///
  /// In en, this message translates to:
  /// **'Clavinet'**
  String get gmProgram7;

  /// No description provided for @gmProgram16.
  ///
  /// In en, this message translates to:
  /// **'Drawbar organ'**
  String get gmProgram16;

  /// No description provided for @gmProgram17.
  ///
  /// In en, this message translates to:
  /// **'Percussive organ'**
  String get gmProgram17;

  /// No description provided for @gmProgram18.
  ///
  /// In en, this message translates to:
  /// **'Rock organ'**
  String get gmProgram18;

  /// No description provided for @gmProgram19.
  ///
  /// In en, this message translates to:
  /// **'Church organ'**
  String get gmProgram19;

  /// No description provided for @gmProgram20.
  ///
  /// In en, this message translates to:
  /// **'Reed organ'**
  String get gmProgram20;

  /// No description provided for @gmProgram21.
  ///
  /// In en, this message translates to:
  /// **'Accordion'**
  String get gmProgram21;

  /// No description provided for @gmProgram22.
  ///
  /// In en, this message translates to:
  /// **'Harmonica'**
  String get gmProgram22;

  /// No description provided for @gmProgram23.
  ///
  /// In en, this message translates to:
  /// **'Bandoneon'**
  String get gmProgram23;

  /// No description provided for @gmProgram24.
  ///
  /// In en, this message translates to:
  /// **'Nylon guitar'**
  String get gmProgram24;

  /// No description provided for @gmProgram25.
  ///
  /// In en, this message translates to:
  /// **'Steel-string guitar'**
  String get gmProgram25;

  /// No description provided for @gmProgram26.
  ///
  /// In en, this message translates to:
  /// **'Jazz guitar'**
  String get gmProgram26;

  /// No description provided for @gmProgram27.
  ///
  /// In en, this message translates to:
  /// **'Clean electric guitar'**
  String get gmProgram27;

  /// No description provided for @gmProgram28.
  ///
  /// In en, this message translates to:
  /// **'Muted guitar'**
  String get gmProgram28;

  /// No description provided for @gmProgram29.
  ///
  /// In en, this message translates to:
  /// **'Overdrive guitar'**
  String get gmProgram29;

  /// No description provided for @gmProgram30.
  ///
  /// In en, this message translates to:
  /// **'Distortion guitar'**
  String get gmProgram30;

  /// No description provided for @gmProgram31.
  ///
  /// In en, this message translates to:
  /// **'Guitar harmonics'**
  String get gmProgram31;

  /// No description provided for @gmProgram32.
  ///
  /// In en, this message translates to:
  /// **'Acoustic bass'**
  String get gmProgram32;

  /// No description provided for @gmProgram33.
  ///
  /// In en, this message translates to:
  /// **'Finger bass'**
  String get gmProgram33;

  /// No description provided for @gmProgram34.
  ///
  /// In en, this message translates to:
  /// **'Pick bass'**
  String get gmProgram34;

  /// No description provided for @gmProgram35.
  ///
  /// In en, this message translates to:
  /// **'Fretless bass'**
  String get gmProgram35;

  /// No description provided for @gmProgram36.
  ///
  /// In en, this message translates to:
  /// **'Slap bass 1'**
  String get gmProgram36;

  /// No description provided for @gmProgram37.
  ///
  /// In en, this message translates to:
  /// **'Slap bass 2'**
  String get gmProgram37;

  /// No description provided for @gmProgram38.
  ///
  /// In en, this message translates to:
  /// **'Synth bass 1'**
  String get gmProgram38;

  /// No description provided for @gmProgram39.
  ///
  /// In en, this message translates to:
  /// **'Synth bass 2'**
  String get gmProgram39;

  /// No description provided for @gmProgram40.
  ///
  /// In en, this message translates to:
  /// **'Violin'**
  String get gmProgram40;

  /// No description provided for @gmProgram41.
  ///
  /// In en, this message translates to:
  /// **'Viola'**
  String get gmProgram41;

  /// No description provided for @gmProgram42.
  ///
  /// In en, this message translates to:
  /// **'Cello'**
  String get gmProgram42;

  /// No description provided for @gmProgram43.
  ///
  /// In en, this message translates to:
  /// **'Double bass'**
  String get gmProgram43;

  /// No description provided for @gmProgram44.
  ///
  /// In en, this message translates to:
  /// **'Tremolo strings'**
  String get gmProgram44;

  /// No description provided for @gmProgram45.
  ///
  /// In en, this message translates to:
  /// **'Pizzicato strings'**
  String get gmProgram45;

  /// No description provided for @gmProgram46.
  ///
  /// In en, this message translates to:
  /// **'Orchestral harp'**
  String get gmProgram46;

  /// No description provided for @gmProgram48.
  ///
  /// In en, this message translates to:
  /// **'String ensemble'**
  String get gmProgram48;

  /// No description provided for @gmProgram49.
  ///
  /// In en, this message translates to:
  /// **'Slow strings'**
  String get gmProgram49;

  /// No description provided for @gmProgram50.
  ///
  /// In en, this message translates to:
  /// **'Synth strings 1'**
  String get gmProgram50;

  /// No description provided for @gmProgram51.
  ///
  /// In en, this message translates to:
  /// **'Synth strings 2'**
  String get gmProgram51;

  /// No description provided for @gmProgram52.
  ///
  /// In en, this message translates to:
  /// **'Choir voices'**
  String get gmProgram52;

  /// No description provided for @gmProgram53.
  ///
  /// In en, this message translates to:
  /// **'Voice oohs'**
  String get gmProgram53;

  /// No description provided for @gmProgram54.
  ///
  /// In en, this message translates to:
  /// **'Synth voice'**
  String get gmProgram54;

  /// No description provided for @gmProgram56.
  ///
  /// In en, this message translates to:
  /// **'Trumpet'**
  String get gmProgram56;

  /// No description provided for @gmProgram57.
  ///
  /// In en, this message translates to:
  /// **'Trombone'**
  String get gmProgram57;

  /// No description provided for @gmProgram58.
  ///
  /// In en, this message translates to:
  /// **'Tuba'**
  String get gmProgram58;

  /// No description provided for @gmProgram59.
  ///
  /// In en, this message translates to:
  /// **'Muted trumpet'**
  String get gmProgram59;

  /// No description provided for @gmProgram60.
  ///
  /// In en, this message translates to:
  /// **'French horns'**
  String get gmProgram60;

  /// No description provided for @gmProgram61.
  ///
  /// In en, this message translates to:
  /// **'Brass section'**
  String get gmProgram61;

  /// No description provided for @gmProgram62.
  ///
  /// In en, this message translates to:
  /// **'Synth brass 1'**
  String get gmProgram62;

  /// No description provided for @gmProgram63.
  ///
  /// In en, this message translates to:
  /// **'Synth brass 2'**
  String get gmProgram63;

  /// No description provided for @gmProgram64.
  ///
  /// In en, this message translates to:
  /// **'Soprano sax'**
  String get gmProgram64;

  /// No description provided for @gmProgram65.
  ///
  /// In en, this message translates to:
  /// **'Alto sax'**
  String get gmProgram65;

  /// No description provided for @gmProgram66.
  ///
  /// In en, this message translates to:
  /// **'Tenor sax'**
  String get gmProgram66;

  /// No description provided for @gmProgram67.
  ///
  /// In en, this message translates to:
  /// **'Baritone sax'**
  String get gmProgram67;

  /// No description provided for @gmProgram68.
  ///
  /// In en, this message translates to:
  /// **'Oboe'**
  String get gmProgram68;

  /// No description provided for @gmProgram69.
  ///
  /// In en, this message translates to:
  /// **'English horn'**
  String get gmProgram69;

  /// No description provided for @gmProgram70.
  ///
  /// In en, this message translates to:
  /// **'Bassoon'**
  String get gmProgram70;

  /// No description provided for @gmProgram71.
  ///
  /// In en, this message translates to:
  /// **'Clarinet'**
  String get gmProgram71;

  /// No description provided for @gmProgram72.
  ///
  /// In en, this message translates to:
  /// **'Piccolo'**
  String get gmProgram72;

  /// No description provided for @gmProgram73.
  ///
  /// In en, this message translates to:
  /// **'Flute'**
  String get gmProgram73;

  /// No description provided for @gmProgram74.
  ///
  /// In en, this message translates to:
  /// **'Recorder'**
  String get gmProgram74;

  /// No description provided for @gmProgram75.
  ///
  /// In en, this message translates to:
  /// **'Pan flute'**
  String get gmProgram75;

  /// No description provided for @gmProgram76.
  ///
  /// In en, this message translates to:
  /// **'Bottle blow'**
  String get gmProgram76;

  /// No description provided for @gmProgram77.
  ///
  /// In en, this message translates to:
  /// **'Shakuhachi'**
  String get gmProgram77;

  /// No description provided for @gmProgram78.
  ///
  /// In en, this message translates to:
  /// **'Whistle'**
  String get gmProgram78;

  /// No description provided for @gmProgram79.
  ///
  /// In en, this message translates to:
  /// **'Ocarina'**
  String get gmProgram79;

  /// No description provided for @gmProgram8.
  ///
  /// In en, this message translates to:
  /// **'Celeste'**
  String get gmProgram8;

  /// No description provided for @gmProgram9.
  ///
  /// In en, this message translates to:
  /// **'Glockenspiel'**
  String get gmProgram9;

  /// No description provided for @gmProgram10.
  ///
  /// In en, this message translates to:
  /// **'Music box'**
  String get gmProgram10;

  /// No description provided for @gmProgram11.
  ///
  /// In en, this message translates to:
  /// **'Vibraphone'**
  String get gmProgram11;

  /// No description provided for @gmProgram12.
  ///
  /// In en, this message translates to:
  /// **'Marimba'**
  String get gmProgram12;

  /// No description provided for @gmProgram13.
  ///
  /// In en, this message translates to:
  /// **'Xylophone'**
  String get gmProgram13;

  /// No description provided for @gmProgram14.
  ///
  /// In en, this message translates to:
  /// **'Tubular bells'**
  String get gmProgram14;

  /// No description provided for @gmProgram15.
  ///
  /// In en, this message translates to:
  /// **'Dulcimer'**
  String get gmProgram15;

  /// No description provided for @gmProgram47.
  ///
  /// In en, this message translates to:
  /// **'Timpani'**
  String get gmProgram47;

  /// No description provided for @gmProgram112.
  ///
  /// In en, this message translates to:
  /// **'Tinker bell'**
  String get gmProgram112;

  /// No description provided for @gmProgram113.
  ///
  /// In en, this message translates to:
  /// **'Agogo'**
  String get gmProgram113;

  /// No description provided for @gmProgram114.
  ///
  /// In en, this message translates to:
  /// **'Steelpan'**
  String get gmProgram114;

  /// No description provided for @gmProgram115.
  ///
  /// In en, this message translates to:
  /// **'Wood block'**
  String get gmProgram115;

  /// No description provided for @gmProgram116.
  ///
  /// In en, this message translates to:
  /// **'Taiko drum'**
  String get gmProgram116;

  /// No description provided for @gmProgram117.
  ///
  /// In en, this message translates to:
  /// **'Melodic tom'**
  String get gmProgram117;

  /// No description provided for @gmProgram118.
  ///
  /// In en, this message translates to:
  /// **'Synth drum'**
  String get gmProgram118;

  /// No description provided for @gmProgram119.
  ///
  /// In en, this message translates to:
  /// **'Reverse cymbal'**
  String get gmProgram119;

  /// No description provided for @gmProgram104.
  ///
  /// In en, this message translates to:
  /// **'Sitar'**
  String get gmProgram104;

  /// No description provided for @gmProgram105.
  ///
  /// In en, this message translates to:
  /// **'Banjo'**
  String get gmProgram105;

  /// No description provided for @gmProgram106.
  ///
  /// In en, this message translates to:
  /// **'Shamisen'**
  String get gmProgram106;

  /// No description provided for @gmProgram107.
  ///
  /// In en, this message translates to:
  /// **'Koto'**
  String get gmProgram107;

  /// No description provided for @gmProgram108.
  ///
  /// In en, this message translates to:
  /// **'Kalimba'**
  String get gmProgram108;

  /// No description provided for @gmProgram109.
  ///
  /// In en, this message translates to:
  /// **'Bagpipes'**
  String get gmProgram109;

  /// No description provided for @gmProgram110.
  ///
  /// In en, this message translates to:
  /// **'Fiddle'**
  String get gmProgram110;

  /// No description provided for @gmProgram111.
  ///
  /// In en, this message translates to:
  /// **'Shenai'**
  String get gmProgram111;

  /// No description provided for @gmProgram80.
  ///
  /// In en, this message translates to:
  /// **'Square lead'**
  String get gmProgram80;

  /// No description provided for @gmProgram81.
  ///
  /// In en, this message translates to:
  /// **'Saw lead'**
  String get gmProgram81;

  /// No description provided for @gmProgram82.
  ///
  /// In en, this message translates to:
  /// **'Synth calliope'**
  String get gmProgram82;

  /// No description provided for @gmProgram83.
  ///
  /// In en, this message translates to:
  /// **'Chiffer lead'**
  String get gmProgram83;

  /// No description provided for @gmProgram84.
  ///
  /// In en, this message translates to:
  /// **'Charang'**
  String get gmProgram84;

  /// No description provided for @gmProgram85.
  ///
  /// In en, this message translates to:
  /// **'Solo vox'**
  String get gmProgram85;

  /// No description provided for @gmProgram86.
  ///
  /// In en, this message translates to:
  /// **'5th saw wave'**
  String get gmProgram86;

  /// No description provided for @gmProgram87.
  ///
  /// In en, this message translates to:
  /// **'Bass & lead'**
  String get gmProgram87;

  /// No description provided for @gmProgram88.
  ///
  /// In en, this message translates to:
  /// **'Fantasia'**
  String get gmProgram88;

  /// No description provided for @gmProgram89.
  ///
  /// In en, this message translates to:
  /// **'Warm pad'**
  String get gmProgram89;

  /// No description provided for @gmProgram90.
  ///
  /// In en, this message translates to:
  /// **'Polysynth'**
  String get gmProgram90;

  /// No description provided for @gmProgram91.
  ///
  /// In en, this message translates to:
  /// **'Space voice'**
  String get gmProgram91;

  /// No description provided for @gmProgram92.
  ///
  /// In en, this message translates to:
  /// **'Bowed glass'**
  String get gmProgram92;

  /// No description provided for @gmProgram93.
  ///
  /// In en, this message translates to:
  /// **'Metal pad'**
  String get gmProgram93;

  /// No description provided for @gmProgram94.
  ///
  /// In en, this message translates to:
  /// **'Halo pad'**
  String get gmProgram94;

  /// No description provided for @gmProgram95.
  ///
  /// In en, this message translates to:
  /// **'Sweep pad'**
  String get gmProgram95;

  /// No description provided for @instrumentFamily0.
  ///
  /// In en, this message translates to:
  /// **'Piano & Keyboards'**
  String get instrumentFamily0;

  /// No description provided for @instrumentFamily1.
  ///
  /// In en, this message translates to:
  /// **'Organs & Accordions'**
  String get instrumentFamily1;

  /// No description provided for @instrumentFamily2.
  ///
  /// In en, this message translates to:
  /// **'Guitars'**
  String get instrumentFamily2;

  /// No description provided for @instrumentFamily3.
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get instrumentFamily3;

  /// No description provided for @instrumentFamily4.
  ///
  /// In en, this message translates to:
  /// **'Strings'**
  String get instrumentFamily4;

  /// No description provided for @instrumentFamily5.
  ///
  /// In en, this message translates to:
  /// **'Choir & Voices'**
  String get instrumentFamily5;

  /// No description provided for @instrumentFamily6.
  ///
  /// In en, this message translates to:
  /// **'Brass'**
  String get instrumentFamily6;

  /// No description provided for @instrumentFamily7.
  ///
  /// In en, this message translates to:
  /// **'Woodwinds'**
  String get instrumentFamily7;

  /// No description provided for @instrumentFamily8.
  ///
  /// In en, this message translates to:
  /// **'Percussion'**
  String get instrumentFamily8;

  /// No description provided for @instrumentFamily9.
  ///
  /// In en, this message translates to:
  /// **'Folk & Traditional'**
  String get instrumentFamily9;

  /// No description provided for @instrumentFamily10.
  ///
  /// In en, this message translates to:
  /// **'Synthesizers'**
  String get instrumentFamily10;

  /// No description provided for @instrumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Instrument {number}'**
  String instrumentNumber(int number);

  /// No description provided for @backToInstrumentFamilies.
  ///
  /// In en, this message translates to:
  /// **'Back to categories'**
  String get backToInstrumentFamilies;

  /// No description provided for @instrumentCategory.
  ///
  /// In en, this message translates to:
  /// **'Instrument category'**
  String get instrumentCategory;

  /// No description provided for @steelpanRollHelp.
  ///
  /// In en, this message translates to:
  /// **'Automatic rolls on sustained notes'**
  String get steelpanRollHelp;

  /// No description provided for @musicalStyleInstruments.
  ///
  /// In en, this message translates to:
  /// **'Musical style instruments'**
  String get musicalStyleInstruments;

  /// No description provided for @ensembleInstrumentHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose instruments for each musical style. These choices apply to the full ensemble. For Choir practice, choose each track’s instrument in the hymn’s choir mixer.'**
  String get ensembleInstrumentHelp;

  /// No description provided for @drumKit.
  ///
  /// In en, this message translates to:
  /// **'Drum kit'**
  String get drumKit;

  /// No description provided for @styleDefault.
  ///
  /// In en, this message translates to:
  /// **'Style default'**
  String get styleDefault;

  /// No description provided for @solo.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get solo;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @previewError.
  ///
  /// In en, this message translates to:
  /// **'Unable to play the preview. Please try again.'**
  String get previewError;

  /// No description provided for @stopPreview.
  ///
  /// In en, this message translates to:
  /// **'Stop preview'**
  String get stopPreview;

  /// No description provided for @previewHymn.
  ///
  /// In en, this message translates to:
  /// **'Preview • {title}'**
  String previewHymn(String title);

  /// No description provided for @previewPlaybackHelp.
  ///
  /// In en, this message translates to:
  /// **'Preview replaces any currently playing hymn and stops when you leave this page.'**
  String get previewPlaybackHelp;

  /// No description provided for @choirPartsOriginal.
  ///
  /// In en, this message translates to:
  /// **'Choir parts • Original music'**
  String get choirPartsOriginal;

  /// No description provided for @separatePartsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Separate parts unavailable'**
  String get separatePartsUnavailable;

  /// No description provided for @choirMixerHelp.
  ///
  /// In en, this message translates to:
  /// **'Original parts only; musical styles are bypassed. Mute silences a part. Solo lets you hear just the selected parts. Mute takes priority. Choose an instrument for each track below. Changes apply to hymn playback and are saved for this hymn. Tap a name to rename it.'**
  String get choirMixerHelp;

  /// No description provided for @noSeparateMidiTracks.
  ///
  /// In en, this message translates to:
  /// **'This MIDI does not contain separate playable tracks. Individual voices cannot be isolated.'**
  String get noSeparateMidiTracks;

  /// No description provided for @pauseParts.
  ///
  /// In en, this message translates to:
  /// **'Pause parts'**
  String get pauseParts;

  /// No description provided for @playParts.
  ///
  /// In en, this message translates to:
  /// **'Play parts'**
  String get playParts;

  /// No description provided for @partsPlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Unable to play the parts. Please try again.'**
  String get partsPlaybackError;

  /// No description provided for @namePart.
  ///
  /// In en, this message translates to:
  /// **'Name this part'**
  String get namePart;

  /// No description provided for @partNameHint.
  ///
  /// In en, this message translates to:
  /// **'Soprano, Alto, Tenor, Bass…'**
  String get partNameHint;

  /// No description provided for @originalInstrument.
  ///
  /// In en, this message translates to:
  /// **'Original instrument'**
  String get originalInstrument;

  /// No description provided for @instrumentChangeError.
  ///
  /// In en, this message translates to:
  /// **'Unable to change this instrument. Please try again.'**
  String get instrumentChangeError;

  /// No description provided for @noMelodicInstrument.
  ///
  /// In en, this message translates to:
  /// **'This track has no melodic instrument to change.'**
  String get noMelodicInstrument;

  /// No description provided for @noFreeMidiChannels.
  ///
  /// In en, this message translates to:
  /// **'This MIDI has no free channels for another independent instrument.'**
  String get noFreeMidiChannels;

  /// No description provided for @resetChoirMix.
  ///
  /// In en, this message translates to:
  /// **'Reset mix • Hear all parts'**
  String get resetChoirMix;

  /// No description provided for @volumeLabel.
  ///
  /// In en, this message translates to:
  /// **'{name} volume'**
  String volumeLabel(String name);

  /// No description provided for @volumePercent.
  ///
  /// In en, this message translates to:
  /// **'{name} volume {value} percent'**
  String volumePercent(String name, int value);

  /// No description provided for @percentValue.
  ///
  /// In en, this message translates to:
  /// **'{value} percent'**
  String percentValue(int value);

  /// No description provided for @roleMelody.
  ///
  /// In en, this message translates to:
  /// **'Melody'**
  String get roleMelody;

  /// No description provided for @rolePianoChords.
  ///
  /// In en, this message translates to:
  /// **'Piano chords'**
  String get rolePianoChords;

  /// No description provided for @roleWalkingBass.
  ///
  /// In en, this message translates to:
  /// **'Walking bass'**
  String get roleWalkingBass;

  /// No description provided for @roleDescant.
  ///
  /// In en, this message translates to:
  /// **'Descant (when present)'**
  String get roleDescant;

  /// No description provided for @roleOffbeatOrgan.
  ///
  /// In en, this message translates to:
  /// **'Offbeat organ'**
  String get roleOffbeatOrgan;

  /// No description provided for @roleOffbeatChords.
  ///
  /// In en, this message translates to:
  /// **'Offbeat chords'**
  String get roleOffbeatChords;

  /// No description provided for @roleOrganBacking.
  ///
  /// In en, this message translates to:
  /// **'Organ backing'**
  String get roleOrganBacking;

  /// No description provided for @roleStrum.
  ///
  /// In en, this message translates to:
  /// **'Strum'**
  String get roleStrum;

  /// No description provided for @roleShimmer.
  ///
  /// In en, this message translates to:
  /// **'Shimmer'**
  String get roleShimmer;

  /// No description provided for @roleAllMelodicParts.
  ///
  /// In en, this message translates to:
  /// **'All melodic parts'**
  String get roleAllMelodicParts;

  /// No description provided for @appDeveloper.
  ///
  /// In en, this message translates to:
  /// **'App developer'**
  String get appDeveloper;

  /// No description provided for @developerBio.
  ///
  /// In en, this message translates to:
  /// **'I am a software developer for Mobile Apps and Websites. This project is my contribution to help you develop a closer relationship with the Lord. I pray you keep your heart pure and lift your praises high.'**
  String get developerBio;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @jamaica.
  ///
  /// In en, this message translates to:
  /// **'Jamaica'**
  String get jamaica;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @statisticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statisticsTitle;

  /// No description provided for @refreshStatistics.
  ///
  /// In en, this message translates to:
  /// **'Refresh statistics'**
  String get refreshStatistics;

  /// No description provided for @communityInSong.
  ///
  /// In en, this message translates to:
  /// **'A community in song'**
  String get communityInSong;

  /// No description provided for @communityInSongHelp.
  ///
  /// In en, this message translates to:
  /// **'Discover the hymns our community opens, returns to, and adds to favorites.'**
  String get communityInSongHelp;

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get lastWeek;

  /// No description provided for @statisticsWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count} weeks'**
  String statisticsWeeks(int count);

  /// No description provided for @reportUpdated.
  ///
  /// In en, this message translates to:
  /// **'Report updated'**
  String get reportUpdated;

  /// No description provided for @savedReport.
  ///
  /// In en, this message translates to:
  /// **'Offline · Saved report'**
  String get savedReport;

  /// No description provided for @reportDateHelp.
  ///
  /// In en, this message translates to:
  /// **'{status} {date}. Completed weeks only; weekly uploads can arrive later.'**
  String reportDateHelp(String status, String date);

  /// No description provided for @olderReportHelp.
  ///
  /// In en, this message translates to:
  /// **'You’re viewing a saved or older report. Refresh when connected for the latest available statistics.'**
  String get olderReportHelp;

  /// No description provided for @mostOpenedHymns.
  ///
  /// In en, this message translates to:
  /// **'Most-opened hymns'**
  String get mostOpenedHymns;

  /// No description provided for @mostOpenedHelp.
  ///
  /// In en, this message translates to:
  /// **'A place to begin your next time of worship.'**
  String get mostOpenedHelp;

  /// No description provided for @returningHymns.
  ///
  /// In en, this message translates to:
  /// **'Hymns we return to'**
  String get returningHymns;

  /// No description provided for @returningHymnsHelp.
  ///
  /// In en, this message translates to:
  /// **'Additional opens of the same hymn on one installation within a calendar week. This does not measure complete performances.'**
  String get returningHymnsHelp;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get addedToFavorites;

  /// No description provided for @addedToFavoritesHelp.
  ///
  /// In en, this message translates to:
  /// **'Hymns people saved during this period. These are additions, not everyone’s current favorites.'**
  String get addedToFavoritesHelp;

  /// No description provided for @whenHymnalOpened.
  ///
  /// In en, this message translates to:
  /// **'When we open the hymnal'**
  String get whenHymnalOpened;

  /// No description provided for @whenHymnalOpenedHelp.
  ///
  /// In en, this message translates to:
  /// **'Times are local to each device when the hymn was opened.'**
  String get whenHymnalOpenedHelp;

  /// No description provided for @statisticsNight.
  ///
  /// In en, this message translates to:
  /// **'Night · 12–6 am'**
  String get statisticsNight;

  /// No description provided for @statisticsMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning · 6 am–12 pm'**
  String get statisticsMorning;

  /// No description provided for @statisticsAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon · 12–6 pm'**
  String get statisticsAfternoon;

  /// No description provided for @statisticsEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening · 6 pm–12 am'**
  String get statisticsEvening;

  /// No description provided for @daysFilledWithSong.
  ///
  /// In en, this message translates to:
  /// **'Days filled with song'**
  String get daysFilledWithSong;

  /// No description provided for @daysFilledWithSongHelp.
  ///
  /// In en, this message translates to:
  /// **'Hymn opens by the local day of the week.'**
  String get daysFilledWithSongHelp;

  /// No description provided for @aroundTheWorld.
  ///
  /// In en, this message translates to:
  /// **'Around the world'**
  String get aroundTheWorld;

  /// No description provided for @aroundTheWorldHelp.
  ///
  /// In en, this message translates to:
  /// **'Popular hymns by upload country. Travel and network routing can affect country estimates.'**
  String get aroundTheWorldHelp;

  /// No description provided for @countryIsoCode.
  ///
  /// In en, this message translates to:
  /// **'Country (ISO code)'**
  String get countryIsoCode;

  /// No description provided for @statisticsExplanation.
  ///
  /// In en, this message translates to:
  /// **'About these numbers\n\nThese are shared activity counts, not unique people or the number of times a hymn was sung. Each published weekly group needs at least 20 participating installations. Small groups and some related totals are withheld, so charts may be incomplete. New measurements need time to gather enough contributions.\n\nEveryone sees the same community report. You can view it even when sharing is off in Settings.'**
  String get statisticsExplanation;

  /// No description provided for @communityStatisticsFailed.
  ///
  /// In en, this message translates to:
  /// **'Community statistics are unavailable right now. Connect to the internet and try again. After your first successful download, the saved report will be available offline.'**
  String get communityStatisticsFailed;

  /// No description provided for @loadingCommunityStatistics.
  ///
  /// In en, this message translates to:
  /// **'Loading community statistics…'**
  String get loadingCommunityStatistics;

  /// No description provided for @communityInsightsGrowing.
  ///
  /// In en, this message translates to:
  /// **'Community insights are growing. Results appear here when enough people have contributed.'**
  String get communityInsightsGrowing;

  /// No description provided for @notEnoughPublishedData.
  ///
  /// In en, this message translates to:
  /// **'Not enough published data'**
  String get notEnoughPublishedData;

  /// No description provided for @statisticsNewEdition.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get statisticsNewEdition;

  /// No description provided for @statisticsOldEdition.
  ///
  /// In en, this message translates to:
  /// **'Old'**
  String get statisticsOldEdition;

  /// No description provided for @countryUS.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get countryUS;

  /// No description provided for @countryGB.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get countryGB;

  /// No description provided for @countryCA.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get countryCA;

  /// No description provided for @countryTT.
  ///
  /// In en, this message translates to:
  /// **'Trinidad and Tobago'**
  String get countryTT;

  /// No description provided for @countryGY.
  ///
  /// In en, this message translates to:
  /// **'Guyana'**
  String get countryGY;

  /// No description provided for @countryBB.
  ///
  /// In en, this message translates to:
  /// **'Barbados'**
  String get countryBB;

  /// No description provided for @countryBS.
  ///
  /// In en, this message translates to:
  /// **'Bahamas'**
  String get countryBS;

  /// No description provided for @countryZA.
  ///
  /// In en, this message translates to:
  /// **'South Africa'**
  String get countryZA;

  /// No description provided for @countryKE.
  ///
  /// In en, this message translates to:
  /// **'Kenya'**
  String get countryKE;

  /// No description provided for @countryNG.
  ///
  /// In en, this message translates to:
  /// **'Nigeria'**
  String get countryNG;

  /// No description provided for @countryGH.
  ///
  /// In en, this message translates to:
  /// **'Ghana'**
  String get countryGH;

  /// No description provided for @countryPH.
  ///
  /// In en, this message translates to:
  /// **'Philippines'**
  String get countryPH;

  /// No description provided for @countryAU.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get countryAU;

  /// No description provided for @countryNZ.
  ///
  /// In en, this message translates to:
  /// **'New Zealand'**
  String get countryNZ;

  /// No description provided for @countryIN.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get countryIN;

  /// No description provided for @countryZW.
  ///
  /// In en, this message translates to:
  /// **'Zimbabwe'**
  String get countryZW;

  /// No description provided for @statisticsOpens.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} open} other{{count} opens}}'**
  String statisticsOpens(int count);

  /// No description provided for @statisticsRepeatOpens.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} repeat open} other{{count} repeat opens}}'**
  String statisticsRepeatOpens(int count);

  /// No description provided for @statisticsAdditions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} addition} other{{count} additions}}'**
  String statisticsAdditions(int count);

  /// No description provided for @serviceArrangementHelp.
  ///
  /// In en, this message translates to:
  /// **'Arrange hymns and readings for a service. You can use a hymn more than once.'**
  String get serviceArrangementHelp;

  /// No description provided for @serviceDeleteHelp.
  ///
  /// In en, this message translates to:
  /// **'Your hymns and favorites will stay saved.'**
  String get serviceDeleteHelp;

  /// No description provided for @newService.
  ///
  /// In en, this message translates to:
  /// **'New service'**
  String get newService;

  /// No description provided for @renameService.
  ///
  /// In en, this message translates to:
  /// **'Rename service'**
  String get renameService;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get serviceName;

  /// No description provided for @serviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Sabbath worship'**
  String get serviceNameHint;

  /// No description provided for @serviceNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use 1–60 characters.'**
  String get serviceNameInvalid;

  /// No description provided for @serviceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The service could not be saved. Please try again.'**
  String get serviceSaveFailed;

  /// No description provided for @serviceStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved services could not be read or updated.'**
  String get serviceStorageFailed;

  /// No description provided for @serviceEditingPaused.
  ///
  /// In en, this message translates to:
  /// **'Editing is paused to protect your saved data.'**
  String get serviceEditingPaused;

  /// No description provided for @serviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get serviceUnavailable;

  /// No description provided for @serviceOrderHelp.
  ///
  /// In en, this message translates to:
  /// **'Add hymns and readings in service order.'**
  String get serviceOrderHelp;

  /// No description provided for @unavailableItem.
  ///
  /// In en, this message translates to:
  /// **'Unavailable item'**
  String get unavailableItem;

  /// No description provided for @repeatAtEnd.
  ///
  /// In en, this message translates to:
  /// **'Repeat at end'**
  String get repeatAtEnd;

  /// No description provided for @addHymnOrReading.
  ///
  /// In en, this message translates to:
  /// **'Add hymn or reading'**
  String get addHymnOrReading;

  /// No description provided for @numberOrTitle.
  ///
  /// In en, this message translates to:
  /// **'Number or title'**
  String get numberOrTitle;

  /// No description provided for @noMatchingServiceItems.
  ///
  /// In en, this message translates to:
  /// **'No matching hymns or readings'**
  String get noMatchingServiceItems;

  /// No description provided for @serviceItemNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'This item is not installed. It remains in your service.'**
  String get serviceItemNotInstalled;

  /// No description provided for @servicePosition.
  ///
  /// In en, this message translates to:
  /// **'Service: {name} · {position} of {total}'**
  String servicePosition(String name, int position, int total);

  /// No description provided for @serviceItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String serviceItemCount(int count);

  /// No description provided for @previousControl.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousControl;

  /// No description provided for @nextControl.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextControl;

  /// No description provided for @includeLyrics.
  ///
  /// In en, this message translates to:
  /// **'Include'**
  String get includeLyrics;

  /// No description provided for @fullHymn.
  ///
  /// In en, this message translates to:
  /// **'Full hymn'**
  String get fullHymn;

  /// No description provided for @lyricsCopied.
  ///
  /// In en, this message translates to:
  /// **'Lyrics copied'**
  String get lyricsCopied;

  /// No description provided for @copyLyricsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not copy lyrics. Please try again.'**
  String get copyLyricsFailed;

  /// No description provided for @shareLyricsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open sharing. You can copy the lyrics instead.'**
  String get shareLyricsFailed;

  /// No description provided for @lyricVerse.
  ///
  /// In en, this message translates to:
  /// **'Verse {number}'**
  String lyricVerse(String number);

  /// No description provided for @lyricSection.
  ///
  /// In en, this message translates to:
  /// **'Section {number}'**
  String lyricSection(int number);

  /// No description provided for @copyControl.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyControl;

  /// No description provided for @shareControl.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareControl;

  /// No description provided for @additionalReadingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Additional Readings'**
  String get additionalReadingsTitle;

  /// No description provided for @searchReadings.
  ///
  /// In en, this message translates to:
  /// **'Search readings'**
  String get searchReadings;

  /// No description provided for @allReadings.
  ///
  /// In en, this message translates to:
  /// **'All readings'**
  String get allReadings;

  /// No description provided for @noMatchingReadings.
  ///
  /// In en, this message translates to:
  /// **'No matching readings'**
  String get noMatchingReadings;

  /// No description provided for @readingOptions.
  ///
  /// In en, this message translates to:
  /// **'Reading options'**
  String get readingOptions;

  /// No description provided for @pauseReading.
  ///
  /// In en, this message translates to:
  /// **'Pause reading'**
  String get pauseReading;

  /// No description provided for @readingScripture.
  ///
  /// In en, this message translates to:
  /// **'Scripture: {reference}'**
  String readingScripture(String reference);

  /// No description provided for @categoryPosition.
  ///
  /// In en, this message translates to:
  /// **'Category: {name} · {position} of {total}'**
  String categoryPosition(String name, int position, int total);

  /// No description provided for @topicsHeading.
  ///
  /// In en, this message translates to:
  /// **'Hymns and readings by topic'**
  String get topicsHeading;

  /// No description provided for @topicsIntro.
  ///
  /// In en, this message translates to:
  /// **'Explore the hymnal’s topical index alongside our existing occasion selections.'**
  String get topicsIntro;

  /// No description provided for @searchTopicsOccasions.
  ///
  /// In en, this message translates to:
  /// **'Search topics and occasions'**
  String get searchTopicsOccasions;

  /// No description provided for @noMatchingTopics.
  ///
  /// In en, this message translates to:
  /// **'No matching topics.'**
  String get noMatchingTopics;

  /// No description provided for @occasionNoSelections.
  ///
  /// In en, this message translates to:
  /// **'No selections are available in this hymnal yet.'**
  String get occasionNoSelections;

  /// No description provided for @readingsLoadRetry.
  ///
  /// In en, this message translates to:
  /// **'Could not load readings. Retry'**
  String get readingsLoadRetry;

  /// No description provided for @scriptureReadings.
  ///
  /// In en, this message translates to:
  /// **'Scripture readings'**
  String get scriptureReadings;

  /// No description provided for @hymnsPopularityRanked.
  ///
  /// In en, this message translates to:
  /// **'Hymns popularity ranked'**
  String get hymnsPopularityRanked;

  /// No description provided for @topicReadingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} reading} other{{count} readings}}'**
  String topicReadingCount(int count);

  /// No description provided for @topicReadingsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading readings…'**
  String get topicReadingsLoading;

  /// No description provided for @topicReadingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Readings unavailable'**
  String get topicReadingsUnavailable;

  /// No description provided for @enterHymnOrReadingNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter hymn or reading number'**
  String get enterHymnOrReadingNumber;

  /// No description provided for @enterHymnNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter hymn number'**
  String get enterHymnNumber;

  /// No description provided for @previewHymnOrReadingHelp.
  ///
  /// In en, this message translates to:
  /// **'Type a hymn or reading number to preview it here'**
  String get previewHymnOrReadingHelp;

  /// No description provided for @previewHymnHelp.
  ///
  /// In en, this message translates to:
  /// **'Type a hymn number to preview it here'**
  String get previewHymnHelp;

  /// No description provided for @notInHymnal.
  ///
  /// In en, this message translates to:
  /// **'Not in {book}'**
  String notInHymnal(String book);

  /// No description provided for @keypadEnglishRange.
  ///
  /// In en, this message translates to:
  /// **'{newBook} 1–695 · Readings 696–920 · {oldBook} 1–703'**
  String keypadEnglishRange(String newBook, String oldBook);

  /// No description provided for @visitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Visit the website'**
  String get visitWebsite;

  /// No description provided for @sabbathProgramsDescription.
  ///
  /// In en, this message translates to:
  /// **'Sabbath Programs is an initiative to improve the quality of church services by providing Christ-centered, creative and purpose-driven programs to congregations across the world. We provide innovative programs for Sabbath School, Divine Service and Adventist Youth (AY).'**
  String get sabbathProgramsDescription;

  /// No description provided for @additionalHymnalsRetry.
  ///
  /// In en, this message translates to:
  /// **'Additional hymnals unavailable · Retry'**
  String get additionalHymnalsRetry;

  /// No description provided for @appUpdated.
  ///
  /// In en, this message translates to:
  /// **'You have been updated to the latest version.'**
  String get appUpdated;

  /// No description provided for @updateHistoryIntro.
  ///
  /// In en, this message translates to:
  /// **'Here’s what’s new, followed by improvements from earlier versions.'**
  String get updateHistoryIntro;

  /// No description provided for @releaseHistoryIntro.
  ///
  /// In en, this message translates to:
  /// **'See what was added in each version.'**
  String get releaseHistoryIntro;

  /// No description provided for @latestRelease.
  ///
  /// In en, this message translates to:
  /// **'LATEST'**
  String get latestRelease;

  /// No description provided for @release450Feature0.
  ///
  /// In en, this message translates to:
  /// **'Correct 6/8 timing across musical styles and improve number-screen spacing, dark menus, and page turns.'**
  String get release450Feature0;

  /// No description provided for @release450Feature1.
  ///
  /// In en, this message translates to:
  /// **'Enable Autoplay under Sound to continue music or videos through your current hymn list after pressing Play.'**
  String get release450Feature1;

  /// No description provided for @release450Feature2.
  ///
  /// In en, this message translates to:
  /// **'Play hymns in Jazz style with piano chords, walking acoustic bass, and swung drums.'**
  String get release450Feature2;

  /// No description provided for @release450Feature3.
  ///
  /// In en, this message translates to:
  /// **'Enjoy Jamaican Gospel accompaniment with its original synchronized rhythm and a 15% faster default tempo.'**
  String get release450Feature3;

  /// No description provided for @release450Feature4.
  ///
  /// In en, this message translates to:
  /// **'Change musical style and toggle Choir Practice directly from the hymn menu.'**
  String get release450Feature4;

  /// No description provided for @release450Feature5.
  ///
  /// In en, this message translates to:
  /// **'Reach every musical style in the scrolling picker, with Caribbean choices grouped together.'**
  String get release450Feature5;

  /// No description provided for @release450Feature6.
  ///
  /// In en, this message translates to:
  /// **'Adjust drum-kit volume or solo the drums in all five backing styles; soloing another part now silences the kit.'**
  String get release450Feature6;

  /// No description provided for @release450Feature7.
  ///
  /// In en, this message translates to:
  /// **'Find musical-style instrument controls below Sound in Settings and preview your ensemble with Amazing Grace.'**
  String get release450Feature7;

  /// No description provided for @release450Feature8.
  ///
  /// In en, this message translates to:
  /// **'Find hymns more easily with search that prioritizes titles and opening lyric lines.'**
  String get release450Feature8;

  /// No description provided for @release450Feature9.
  ///
  /// In en, this message translates to:
  /// **'Save favorites with refreshed heart feedback and a gentle reminder at the end of a hymn.'**
  String get release450Feature9;

  /// No description provided for @release440Feature0.
  ///
  /// In en, this message translates to:
  /// **'Enable Choir Practice in Settings to hear available vocal parts separately, rename tracks, and mute or solo them.'**
  String get release440Feature0;

  /// No description provided for @release440Feature1.
  ///
  /// In en, this message translates to:
  /// **'Choose an instrument and adjust the volume for each choir track using compact controls.'**
  String get release440Feature1;

  /// No description provided for @release440Feature2.
  ///
  /// In en, this message translates to:
  /// **'Customize ensemble instruments in Settings, adjust their levels, solo individual roles, and preview your mix.'**
  String get release440Feature2;

  /// No description provided for @release440Feature3.
  ///
  /// In en, this message translates to:
  /// **'Choose from 111 instruments organized into 11 categories. Find Steelpan under Percussion, with automatic rolls on sustained notes.'**
  String get release440Feature3;

  /// No description provided for @release440Feature4.
  ///
  /// In en, this message translates to:
  /// **'Choir Practice uses the original parts and overrides the selected ensemble style. These optional controls stay hidden until enabled.'**
  String get release440Feature4;

  /// No description provided for @release430Feature0.
  ///
  /// In en, this message translates to:
  /// **'Read all 225 additional readings from the New Hymnal, numbered 696–920, with their categories and Scripture references.'**
  String get release430Feature0;

  /// No description provided for @release430Feature1.
  ///
  /// In en, this message translates to:
  /// **'Find a reading from the number keypad or browse and search the complete reading collection, then swipe between readings and use a comfortable reading-speed auto-scroll.'**
  String get release430Feature1;

  /// No description provided for @release430Feature2.
  ///
  /// In en, this message translates to:
  /// **'Browse hymns and Scripture readings by topic or occasion, including the New Hymnal\'s topical index.'**
  String get release430Feature2;

  /// No description provided for @release430Feature3.
  ///
  /// In en, this message translates to:
  /// **'Read restored hymn stories with quotations and passages that were missing from the earlier import.'**
  String get release430Feature3;

  /// No description provided for @release430Feature4.
  ///
  /// In en, this message translates to:
  /// **'Explore community statistics in Settings, including popular hymns, repeat visits, favorite additions, and times of worship, with saved reports available offline.'**
  String get release430Feature4;

  /// No description provided for @release430Feature5.
  ///
  /// In en, this message translates to:
  /// **'Help improve the app with weekly usage summaries. Sharing is enabled by default and can be turned off at any time in Settings under Privacy & Statistics.'**
  String get release430Feature5;

  /// No description provided for @release420Feature0.
  ///
  /// In en, this message translates to:
  /// **'Read the background story of a hymn and see its writer and composer.'**
  String get release420Feature0;

  /// No description provided for @release420Feature1.
  ///
  /// In en, this message translates to:
  /// **'Watch a matching hymn video while following the words in the app.'**
  String get release420Feature1;

  /// No description provided for @release420Feature2.
  ///
  /// In en, this message translates to:
  /// **'Play music for all 703 Old Hymnal songs, with the correct number of verses and choruses.'**
  String get release420Feature2;

  /// No description provided for @release420Feature3.
  ///
  /// In en, this message translates to:
  /// **'Hear and read each chorus after every verse in both hymnals.'**
  String get release420Feature3;

  /// No description provided for @release420Feature4.
  ///
  /// In en, this message translates to:
  /// **'Enjoy continuous reggae and steelpan rhythms in songs written in 3/4 time.'**
  String get release420Feature4;

  /// No description provided for @release420Feature5.
  ///
  /// In en, this message translates to:
  /// **'Use auto-scroll while reading, adjust its speed with a slider, and reposition the words without stopping it.'**
  String get release420Feature5;

  /// No description provided for @release420Feature6.
  ///
  /// In en, this message translates to:
  /// **'Keep the music player hidden across songs and app launches when you prefer more reading space.'**
  String get release420Feature6;

  /// No description provided for @release420Feature7.
  ///
  /// In en, this message translates to:
  /// **'Keep favorite hymns close at hand with the restored heart button in the hymn header.'**
  String get release420Feature7;

  /// No description provided for @release420Feature8.
  ///
  /// In en, this message translates to:
  /// **'Review what changed in this and earlier versions from the What’s New screen.'**
  String get release420Feature8;

  /// No description provided for @release411Feature0.
  ///
  /// In en, this message translates to:
  /// **'Choose the Modern or Classic app design, with a matching home-screen icon.'**
  String get release411Feature0;

  /// No description provided for @release411Feature1.
  ///
  /// In en, this message translates to:
  /// **'Read corrected lyrics for Old Hymnal 533 and 534.'**
  String get release411Feature1;

  /// No description provided for @release411Feature2.
  ///
  /// In en, this message translates to:
  /// **'Enjoy more reliable music playback.'**
  String get release411Feature2;

  /// No description provided for @release410Feature0.
  ///
  /// In en, this message translates to:
  /// **'Added verse numbers and clear chorus labels throughout the Old Hymnal.'**
  String get release410Feature0;

  /// No description provided for @release410Feature1.
  ///
  /// In en, this message translates to:
  /// **'Improved the Island Reggae accompaniment and its sound on iPhone.'**
  String get release410Feature1;

  /// No description provided for @release410Feature2.
  ///
  /// In en, this message translates to:
  /// **'Added an option to keep the screen awake while a hymn is open.'**
  String get release410Feature2;

  /// No description provided for @release401Feature0.
  ///
  /// In en, this message translates to:
  /// **'Added a privacy policy written specifically for the hymnal app.'**
  String get release401Feature0;

  /// No description provided for @release400Feature0.
  ///
  /// In en, this message translates to:
  /// **'Introduced the rebuilt app with a cleaner reading experience.'**
  String get release400Feature0;

  /// No description provided for @release400Feature1.
  ///
  /// In en, this message translates to:
  /// **'Added music playback, chords, Gospel, Island Reggae, and Steel Pan Calypso accompaniment.'**
  String get release400Feature1;

  /// No description provided for @release400Feature2.
  ///
  /// In en, this message translates to:
  /// **'Corrected dozens of reported lyric problems and restored New Hymnal 314.'**
  String get release400Feature2;

  /// No description provided for @alphabeticalBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse alphabetically'**
  String get alphabeticalBrowse;

  /// No description provided for @jumpToLetter.
  ///
  /// In en, this message translates to:
  /// **'Jump to letter'**
  String get jumpToLetter;

  /// No description provided for @previewPresentation.
  ///
  /// In en, this message translates to:
  /// **'Preview slides'**
  String get previewPresentation;

  /// No description provided for @sharePresentation.
  ///
  /// In en, this message translates to:
  /// **'Share HTML slides'**
  String get sharePresentation;

  /// No description provided for @presentationExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to export slides. Check that every service item is available.'**
  String get presentationExportFailed;

  /// No description provided for @languageSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the app language. Please try again.'**
  String get languageSaveFailed;

  /// No description provided for @readingLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get readingLeader;

  /// No description provided for @readingCongregation.
  ///
  /// In en, this message translates to:
  /// **'Congregation'**
  String get readingCongregation;

  /// No description provided for @languagePacks.
  ///
  /// In en, this message translates to:
  /// **'Hymnal downloads'**
  String get languagePacks;

  /// No description provided for @languagePacksHelp.
  ///
  /// In en, this message translates to:
  /// **'Add hymn text for offline reading. Music downloads separately when played.'**
  String get languagePacksHelp;

  /// No description provided for @packBundled.
  ///
  /// In en, this message translates to:
  /// **'Included in the app'**
  String get packBundled;

  /// No description provided for @packInstalled.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get packInstalled;

  /// No description provided for @packDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get packDownload;

  /// No description provided for @packDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change this download. Your saved books are unchanged. Try again.'**
  String get packDownloadFailed;

  /// No description provided for @packNoMusic.
  ///
  /// In en, this message translates to:
  /// **'Hymn text only; music is not included.'**
  String get packNoMusic;

  /// No description provided for @packDetails.
  ///
  /// In en, this message translates to:
  /// **'{count} hymns · {size} MB'**
  String packDetails(int count, String size);

  /// No description provided for @packReviewPending.
  ///
  /// In en, this message translates to:
  /// **'Independent lyric review pending'**
  String get packReviewPending;

  /// No description provided for @packUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get packUpdate;
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
