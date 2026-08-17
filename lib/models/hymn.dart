class Hymn {
  final int number;
  final String title;
  final String body;
  final String version;

  Hymn({
    required this.number,
    required this.title,
    required this.body,
    required this.version,
  });

  @override
  String toString() {
    return "Hymn #$number $title $version";
  }
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
