import 'package:html/parser.dart' show parseFragment;
import 'package:sdahymnal/models/hymn.dart';

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp("['’‘ʼ`\\\\]"), '')
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final _index = Expando<_SearchText>();

class _SearchText {
  final String title;
  final String firstVerse;
  final String chorus;
  final String lyrics;
  final List<String> lyricLines;

  _SearchText(Hymn hymn) : this._(hymn, _lines(hymn.body));

  _SearchText._(Hymn hymn, List<String> lines)
      : title = _normalize(hymn.title),
        firstVerse = lines.firstWhere(_isLyric, orElse: () => ''),
        chorus = _chorusOpening(lines),
        lyricLines = lines.where(_isLyric).toList(),
        lyrics = lines.where(_isLyric).join(' ');

  static bool _isLyric(String line) =>
      line.isNotEmpty &&
      !RegExp(r'^\d+$').hasMatch(line) &&
      line != 'chorus' &&
      line != 'refrain';

  static List<String> _lines(String body) {
    // The inherited asset includes literal backslash-n separators as well
    // as HTML breaks. Decode entities and remove tags before indexing.
    final html = body.replaceAll(r'\n', '\n').replaceAll(
        RegExp(r'<br\s*/?>|</?p\b[^>]*>', caseSensitive: false), '\n');
    return (parseFragment(html).text ?? '')
        .split('\n')
        .map(_normalize)
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static String _chorusOpening(List<String> lines) {
    final at =
        lines.indexWhere((line) => line == 'chorus' || line == 'refrain');
    if (at < 0 || at + 1 >= lines.length) return '';
    return _isLyric(lines[at + 1]) ? lines[at + 1] : '';
  }

  int? rank(String query, String number) {
    if (number == query) return 0;
    // Placement comes before field priority: a line opening is more
    // recognizable than the same phrase buried inside another title.
    if (title.startsWith(query)) return 1;
    if (firstVerse.startsWith(query)) return 2;
    if (chorus.startsWith(query)) return 3;
    if (lyricLines.any((line) => line.startsWith(query))) return 4;
    if (title.contains(query)) return 5;
    if (firstVerse.contains(query)) return 6;
    if (chorus.contains(query)) return 7;
    if (number.contains(query)) return 8;
    if (lyrics.contains(query)) return 9;
    return null;
  }
}

/// Prefer the start of a title or lyric line, then matches within a line.
/// Within each group, prioritize title, first verse, and chorus openings.
/// Equal ranks retain the hymnal's original number/edition order.
List<Hymn> searchHymns(List<Hymn> hymns, String query) {
  final normalized = _normalize(query);
  if (normalized.isEmpty) return hymns;
  final matches = <({Hymn hymn, int rank, int order})>[];
  for (var i = 0; i < hymns.length; i++) {
    final hymn = hymns[i];
    final indexed = _index[hymn] ??= _SearchText(hymn);
    final rank = indexed.rank(normalized, hymn.number.toString());
    if (rank != null) matches.add((hymn: hymn, rank: rank, order: i));
  }
  matches.sort((a, b) {
    final rank = a.rank.compareTo(b.rank);
    return rank == 0 ? a.order.compareTo(b.order) : rank;
  });
  return matches.map((match) => match.hymn).toList();
}
