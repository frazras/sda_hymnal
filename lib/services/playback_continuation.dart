import '../models/hymn.dart';

/// Follow displayed order, including mixed-edition favorites, and wrap. A
/// missing video/MIDI is skipped without leaving this list. One-item lists loop.
Hymn? nextPlayableHymn(
    List<Hymn> hymns, Hymn current, bool Function(Hymn) playable) {
  final index = hymns.indexWhere(
      (h) => h.number == current.number && h.version == current.version);
  if (index < 0) return null;
  for (var offset = 1; offset <= hymns.length; offset++) {
    final next = hymns[(index + offset) % hymns.length];
    if (playable(next)) return next;
  }
  return null;
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
