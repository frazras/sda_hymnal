import 'package:sdahymnal/models/hymn_metadata.dart';
import 'package:sdahymnal/models/hymn_video.dart';
import 'package:sdahymnal/models/hymn_ref.dart';

class Hymn {
  final int number;
  final String title;
  final String body;
  final String version;
  final HymnMetadata? metadata;
  final HymnVideo? video;
  final String? bookTitle;
  final String languageTag;
  final String? credits;

  bool get isEnglishEdition => version == 'new' || version == 'old';
  String get bookLabel =>
      bookTitle ??
      switch (version) {
        'new' => 'New Hymnal',
        'old' => 'Old Hymnal',
        _ => version,
      };

  HymnRef get ref => HymnRef(bookId: version, itemId: '$number');

  /// Reading order only; the source lyrics stay unchanged for search/export.
  late final String readingBody =
      isEnglishEdition ? repeatChoruses(body) : body;

  Hymn({
    required this.number,
    required this.title,
    required this.body,
    required this.version,
    this.metadata,
    this.video,
    this.bookTitle,
    this.languageTag = 'en',
    this.credits,
  });

  @override
  String toString() {
    return "Hymn #$number $title $version";
  }
}

/// Expand the hymnal's numbered stanzas into verse/chorus pairs. An explicit
/// chorus belongs to its verse and becomes the refrain for following verses;
/// this preserves special endings such as Old 103's different final chorus.
/// Already-expanded bodies remain unchanged in content (no doubled choruses).
String repeatChoruses(String body) {
  final chorus = RegExp(
    // Old 517 has inline italic echo words inside the italic chorus.
    r'<i>\s*<b><font[^>]*>CHORUS:</font></b><br\s*/?>(?:<i>.*?</i>|(?!</?i>).)*</i>',
    caseSensitive: false,
    dotAll: true,
  );
  final verseMarker =
      RegExp(r'<font[^>]*><b>\d+</b></font>', caseSensitive: false);
  if (!chorus.hasMatch(body) || !verseMarker.hasMatch(body)) return body;

  // The bundled markup uses trailing line breaks and empty paragraphs as
  // stanza separators. Normalize only these, never the lyric text itself.
  String trimBreaks(String html) => html.replaceFirst(
      RegExp(r'(?:\s|<br\s*/?>|<p>\s*</p>)+$', caseSensitive: false), '');

  // Some inherited records close the chorus italic at the END of the hymn.
  // A numbered verse always ends a refrain, even with a misplaced closing
  // tag. Repair the reading copy before splitting, leaving the asset intact.
  body = body.replaceAllMapped(chorus, (match) {
    final block = match.group(0)!;
    final nextVerse = verseMarker.firstMatch(block);
    if (nextVerse == null) return block;
    return '${trimBreaks(block.substring(0, nextVerse.start))}</i><br>\n<br>\n'
        '${block.substring(nextVerse.start, block.length - 4)}';
  });
  final first = chorus.firstMatch(body)!;
  final verses = verseMarker.allMatches(body).toList();

  var refrain = first.group(0)!;
  final output = StringBuffer(body.substring(0, verses.first.start));
  for (var i = 0; i < verses.length; i++) {
    final end = i + 1 < verses.length ? verses[i + 1].start : body.length;
    final stanza = body.substring(verses[i].start, end);
    final explicit = chorus.allMatches(stanza).toList();
    if (explicit.isNotEmpty) refrain = explicit.last.group(0)!;
    // Keep a verse's explicitly supplied refrain(s), otherwise append the
    // current one. This also makes expansion idempotent.
    final lyrics = trimBreaks(stanza.replaceAll(chorus, ''));
    final choruses = explicit.isEmpty
        ? refrain
        : explicit.map((m) => m.group(0)!).join('<br>\n<br>\n');
    if (i > 0) output.write('<br>\n<br>\n');
    output.write('$lyrics<br>\n<br>\n$choruses');
  }
  return output.toString();
}

/// The hymn numbered [n] in [list], or null when the hymnal has no such
/// number.
///
/// Lookups go by NUMBER, never by list position. The hymnal data is not
/// guaranteed to be a gapless 1..N run — New-Hymnal 314 ("Just as I Am,
/// Thine Own to Be") is absent from the source data the app inherited from
/// the original 2016 Ionic app, whose `threeonefour` record holds a
/// mislabeled, truncated copy of 313. Positional `list[n - 1]` indexing
/// silently served the wrong hymn for that number and trapped the reader on
/// it, since paging forward resolved to the same row again.
Hymn? hymnByNumber(List<Hymn> list, int n) {
  for (final hymn in list) {
    if (hymn.number == n) return hymn;
  }
  return null;
}

/// The next hymn after [from] in direction [dir] (-1 previous, 1 next),
/// skipping over numbers the hymnal does not contain, or null at the ends.
Hymn? adjacentHymn(List<Hymn> list, int from, int dir, int max) {
  for (var n = from + dir; n >= 1 && n <= max; n += dir) {
    final hymn = hymnByNumber(list, n);
    if (hymn != null) return hymn;
  }
  return null;
}
