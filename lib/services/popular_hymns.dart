import 'dart:math';

import '../models/hymn.dart';
import '../models/hymn_occasion.dart';
import 'trends.dart';

/// Sample without replacement from the community's four-week top 20.
/// Use bundled rankings when a community report is unavailable or empty.
List<Hymn> popularHymns(List<Hymn> hymns,
    {TrendsSnapshot? snapshot, Random? random}) {
  final catalog = {for (final h in hymns) '${h.version}:${h.number}': h};
  final songs = [...?snapshot?.periods['4']?.songs]
    ..sort((a, b) => b.count.compareTo(a.count));
  final keys = songs
      .map((s) => '${s.edition}:${s.hymn}')
      .where(catalog.containsKey)
      .toSet()
      .toList();
  if (keys.isEmpty) {
    final fallback = researchedPopularity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    keys.addAll(fallback.map((e) => e.key).where(catalog.containsKey));
  }
  final pool = keys.take(20).map((key) => catalog[key]!).toList()
    ..shuffle(random);
  return pool.take(5).toList();
}
