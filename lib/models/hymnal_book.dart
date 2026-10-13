import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';

/// Native names for the languages a hymnal may be published in. Book text
/// keeps its source language regardless of the interface language.
const nativeLanguageNames = <String, String>{
  'en': 'English',
  'es': 'Español',
  'pt': 'Português',
  'ru': 'Русский',
  'fr': 'Français',
  'sw': 'Kiswahili',
  'ny': 'Chichewa',
  'luo': 'Dholuo',
  'guz': 'Ekegusii',
  'bem': 'Icibemba',
  'zu': 'isiZulu',
  'nd': 'isiNdebele',
  'kln': 'Kalenjin',
  'ki': 'Gĩkũyũ',
  'rw': 'Ikinyarwanda',
  'nso': 'Sepedi',
  'sn': 'chiShona',
  'st': 'Sesotho',
  'toi': 'Chitonga',
  'tn': 'Setswana',
  'tum': 'Chitumbuka',
  'tw': 'Twi',
  've': 'Tshivenḓa',
  'xh': 'isiXhosa',
  'ts': 'Xitsonga',
  'kam': 'Kikamba',
  'mas': 'Maa',
  'tl': 'Tagalog',
  'ceb': 'Cebuano',
};

/// English names and common spellings, used only to find a language by
/// search ("Zulu" finds isiZulu, "Kikuyu" finds Gĩkũyũ). Never displayed.
const languageSearchAliases = <String, String>{
  'en': 'English',
  'es': 'Spanish',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'fr': 'French',
  'sw': 'Swahili',
  'ny': 'Chewa Nyanja',
  'luo': 'Luo',
  'guz': 'Gusii Kisii',
  'bem': 'Bemba',
  'zu': 'Zulu',
  'nd': 'Ndebele',
  'kln': 'Kalenjin',
  'ki': 'Kikuyu',
  'rw': 'Kinyarwanda Rwanda',
  'nso': 'Northern Sotho Pedi',
  'sn': 'Shona',
  'st': 'Sotho Southern Sotho',
  'toi': 'Tonga',
  'tn': 'Tswana',
  'tum': 'Tumbuka',
  'tw': 'Akan',
  've': 'Venda',
  'xh': 'Xhosa',
  'ts': 'Tsonga Shangaan',
  'kam': 'Kamba',
  'mas': 'Maasai Masai',
  'tl': 'Filipino',
  'ceb': 'Bisaya Visayan',
};

String _languageOf(String tag) => tag.split('-').first.toLowerCase();

/// The language half of a "Language · Title" display name, or a known name.
String languageNameFor(String languageTag, [String displayName = '']) {
  final known = nativeLanguageNames[_languageOf(languageTag)];
  if (known != null) return known;
  final parts = displayName.split(' · ');
  return parts.length > 1 ? parts.first : languageTag;
}

/// A short, recognizable book name: "New Hymnal", "Himnario Nuevo",
/// "Hymnes et Louanges". Used for reader crumbs, badges and sharing.
String editionShortLabel(String editionId, String displayName) =>
    switch (editionId) {
      'new' || 'sda-en-1985' => 'New Hymnal',
      'old' || 'sda-en-1941' => 'Old Hymnal',
      'sda-es-2009' => 'Himnario Nuevo',
      'sda-es-1962' => 'Himnario Antiguo',
      'sda-pt-1996' => 'Hinário Adventista',
      'sda-ru-1997' => 'Гимны Надежды',
      _ => () {
          final parts = displayName.split(' · ');
          final title = parts.length > 1 ? parts.sublist(1).join(' · ') : '';
          // "Español · 2009" style names carry only a year after the dot.
          return title.isEmpty || RegExp(r'^\d{4}$').hasMatch(title)
              ? displayName
              : title;
        }(),
    };

/// Two-line edition badge for paired books ("NEW / HYMNAL").
String? pairedBadgeLabel(String editionId) => switch (editionId) {
      'new' || 'sda-en-1985' => 'NEW\nHYMNAL',
      'old' || 'sda-en-1941' => 'OLD\nHYMNAL',
      'sda-es-2009' => 'NUEVO\nHIMNARIO',
      'sda-es-1962' => 'ANTIGUO\nHIMNARIO',
      _ => null,
    };

/// Compact cross-language badge, e.g. "EN · NEW", "ES · ANTIGUO", "PT".
String crossLanguageBadge(Hymn hymn) {
  final code = _languageOf(hymn.languageTag).toUpperCase();
  final edition = switch (hymn.version) {
    'new' => 'NEW',
    'old' => 'OLD',
    'sda-es-2009' => 'NUEVO',
    'sda-es-1962' => 'ANTIGUO',
    _ => '',
  };
  return edition.isEmpty ? code : '$code · $edition';
}

/// One entry in the hymnal picker: a language with one or two editions.
/// English and Spanish pair their New and Old books under one choice; every
/// other language offers its single book through the same screens.
class HymnalBook {
  const HymnalBook({
    required this.id,
    required this.languageTag,
    required this.languageName,
    required this.title,
    required this.primary,
    this.secondary = const [],
    required this.primaryLabel,
    this.secondaryLabel = '',
    this.packs = const [],
    this.optional = false,
  });

  /// 'english', 'spanish', or the edition ID of a single-edition book.
  final String id;
  final String languageTag;
  final String languageName;

  /// Book title shown under the language name in the picker.
  final String title;

  /// New (or only) edition, in number order.
  final List<Hymn> primary;

  /// Old edition for paired books; empty otherwise.
  final List<Hymn> secondary;
  final String primaryLabel;
  final String secondaryLabel;

  /// Imported packs backing this book (topics, edition metadata).
  final List<HymnalPack> packs;

  /// Downloaded optional book (not bundled with the app).
  final bool optional;

  bool get english => id == 'english';
  bool get paired => secondary.isNotEmpty;
  String get code => _languageOf(languageTag).toUpperCase();
  List<Hymn> get hymns => [...primary, ...secondary];
  bool get hasTopics => english || packs.any((p) => p.topics.isNotEmpty);

  int get highestNumber => hymns.fold(0, (n, h) => h.number > n ? h.number : n);
}

/// Builds the picker's choices in a stable order: English, Spanish, then the
/// remaining books in catalog order. [optionalIds] marks downloaded books.
List<HymnalBook> buildHymnalBooks({
  required List<Hymn> englishNew,
  required List<Hymn> englishOld,
  required List<HymnalPack> packs,
  Set<String> optionalIds = const {},
}) {
  final books = <HymnalBook>[
    HymnalBook(
      id: 'english',
      languageTag: 'en',
      languageName: 'English',
      title: 'Old & New Hymnal',
      primary: englishNew,
      secondary: englishOld,
      primaryLabel: 'New Hymnal',
      secondaryLabel: 'Old Hymnal',
    ),
  ];
  HymnalPack? pack(String id) {
    for (final p in packs) {
      if (p.edition.id == id) return p;
    }
    return null;
  }

  final spanishNew = pack('sda-es-2009');
  final spanishOld = pack('sda-es-1962');
  if (spanishNew != null) {
    books.add(HymnalBook(
      id: 'spanish',
      languageTag: 'es',
      languageName: 'Español',
      title: 'Himnario Adventista · Nuevo y Antiguo',
      primary: spanishNew.hymns,
      secondary: spanishOld?.hymns ?? const [],
      primaryLabel: 'Nuevo',
      secondaryLabel: 'Antiguo',
      packs: [spanishNew, if (spanishOld != null) spanishOld],
    ));
  }
  for (final p in packs) {
    final id = p.edition.id;
    if (id == 'sda-es-2009' || (id == 'sda-es-1962' && spanishNew != null)) {
      continue;
    }
    books.add(HymnalBook(
      id: id,
      languageTag: p.edition.languageTag,
      languageName:
          languageNameFor(p.edition.languageTag, p.edition.displayName),
      title: editionShortLabel(id, p.edition.displayName),
      primary: p.hymns,
      primaryLabel: editionShortLabel(id, p.edition.displayName),
      packs: [p],
      optional: optionalIds.contains(id),
    ));
  }
  return List.unmodifiable(books);
}
