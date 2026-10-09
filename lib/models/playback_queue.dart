import 'package:sdahymnal/models/hymn.dart';

/// A snapshot of displayed occurrences, not a set of unique hymn identities.
/// Null entries are service readings or unavailable items: automatic playback
/// stops there rather than skipping part of a planned worship service.
class HymnPlaybackQueue {
  HymnPlaybackQueue(
      {required List<Hymn?> entries,
      required this.wrap,
      required this.skipUnavailable})
      : entries = List.unmodifiable(entries);

  final List<Hymn?> entries;
  final bool wrap;
  final bool skipUnavailable;

  /// Return an occurrence index so repeated hymns remain distinct.
  int? adjacent(int index, int direction, bool Function(Hymn) playable) {
    if (index < 0 ||
        index >= entries.length ||
        (direction != 1 && direction != -1)) {
      return null;
    }
    for (var distance = 1; distance <= entries.length; distance++) {
      var candidate = index + distance * direction;
      if (!wrap && (candidate < 0 || candidate >= entries.length)) return null;
      candidate %= entries.length;
      final hymn = entries[candidate];
      if (hymn != null && playable(hymn)) return candidate;
      if (!skipUnavailable) return null;
    }
    return null;
  }
}
