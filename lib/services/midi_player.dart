import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:sdahymnal/models/hymn.dart';

/// Plays the bundled New-Hymnal MIDI files (assets/midi/001.mid … 695.mid)
/// through the platform media player. One hymn at a time; play/pause toggles.
/// Old-Hymnal hymns have no MIDI, so [hasMidi] gates the UI.
class MidiPlayer {
  MidiPlayer._() {
    _player.onPlayerComplete.listen((_) => current.value = null);
  }

  static final MidiPlayer instance = MidiPlayer._();

  final AudioPlayer _player = AudioPlayer();

  /// Hymn number currently loaded (+ paused flag); null when stopped.
  final ValueNotifier<({int n, bool paused})?> current = ValueNotifier(null);

  static bool hasMidi(Hymn hymn) => hymn.version == 'new';

  static String _asset(int n) => 'midi/${n.toString().padLeft(3, '0')}.mid';

  /// Play the hymn; if it is already the current one, toggle pause/resume.
  Future<void> toggle(Hymn hymn) async {
    if (!hasMidi(hymn)) return;
    final cur = current.value;
    if (cur != null && cur.n == hymn.number) {
      if (cur.paused) {
        await _player.resume();
        current.value = (n: hymn.number, paused: false);
      } else {
        await _player.pause();
        current.value = (n: hymn.number, paused: true);
      }
      return;
    }
    await _player.stop();
    current.value = (n: hymn.number, paused: false);
    try {
      await _player.play(AssetSource(_asset(hymn.number)));
    } catch (_) {
      current.value = null;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    current.value = null;
  }

  /// Stop only if [number] is the hymn currently loaded — lets a disposed
  /// hymn page clean up without cutting off a newer page's playback.
  Future<void> stopIfCurrent(int number) async {
    if (current.value?.n == number) await stop();
  }
}
