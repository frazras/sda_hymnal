import '../models/hymn.dart';
import '../models/playback_queue.dart';

/// Follow displayed order, including mixed-edition favorites, and wrap. A
/// missing video/MIDI is skipped without leaving this list. One-item lists loop.
Hymn? nextPlayableHymn(
    List<Hymn> hymns, Hymn current, bool Function(Hymn) playable) {
  final index = hymns.indexWhere(
      (h) => h.number == current.number && h.version == current.version);
  final queue =
      HymnPlaybackQueue(entries: hymns, wrap: true, skipUnavailable: true);
  final next = queue.adjacent(index, 1, playable);
  return next == null ? null : queue.entries[next];
}

/// Ignore duplicate end notifications and an end arriving after pause/error.
class PlaybackEndGate {
  bool _playing = false;
  void playing() => _playing = true;
  void stop() => _playing = false;
  bool ended() {
    final advance = _playing;
    _playing = false;
    return advance;
  }
}
