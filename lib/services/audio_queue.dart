import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/hymn.dart';
import '../models/playback_queue.dart';
import 'midi_player.dart';
import 'prefs.dart';

class AudioQueuePosition {
  const AudioQueuePosition(this.queue, this.index);
  final HymnPlaybackQueue queue;
  final int index;
  Hymn get hymn => queue.entries[index]!;
}

/// Audio advances independently of route rendering; readers only follow selection.
class AudioQueue extends ValueNotifier<AudioQueuePosition?> {
  AudioQueue(
      {required this.play,
      required this.playable,
      required this.autoplay,
      this.guardedPlay})
      : super(null);
  final Future<void> Function(Hymn) play;
  final bool Function(Hymn) playable;
  final bool Function() autoplay;
  final Future<bool> Function(Hymn, bool Function())? guardedPlay;
  bool _armed = false;
  Future<void> _operations = Future.value();
  int _generation = 0;

  static final AudioQueue instance = AudioQueue(
    play: (hymn) => MidiPlayer.instance.toggle(hymn),
    guardedPlay: (hymn, valid) async {
      if (!valid()) return false;
      await MidiPlayer.instance.stop();
      if (!valid()) return false;
      await MidiPlayer.instance.prepareKey(hymn);
      if (!valid()) return false;
      await MidiPlayer.instance.toggle(hymn, canStart: valid);
      return MidiPlayer.isCurrent(MidiPlayer.instance.current.value, hymn);
    },
    playable: MidiPlayer.hasMusic,
    autoplay: () => Autoplay.instance.value,
  ).._observePlayer();

  void _observePlayer() {
    MidiPlayer.instance.completions.listen((finished) {
      final selected = value;
      if (selected != null &&
          selected.hymn.number == finished.n &&
          selected.hymn.version == finished.version &&
          !MidiPlayer.instance.isPreview &&
          _armed &&
          autoplay()) {
        unawaited(advance(1, automatic: true).catchError((Object _) {}));
      }
    });
  }

  void select(HymnPlaybackQueue queue, int index) {
    if (index < 0 ||
        index >= queue.entries.length ||
        queue.entries[index] == null) {
      throw ArgumentError('Invalid audio queue selection');
    }
    _generation++;
    _armed = true;
    value = AudioQueuePosition(queue, index);
  }

  void clear() {
    _generation++;
    _armed = false;
    value = null;
  }

  void cancelPending() {
    _generation++;
    _armed = false;
  }

  void arm() => _armed = value != null;

  Future<void> advance(int direction, {bool automatic = false}) {
    final generation = _generation;
    final operation = _operations.then((_) async {
      final selected = value;
      if (selected == null ||
          generation != _generation ||
          (automatic && (!_armed || !autoplay()))) {
        return;
      }
      final next = selected.queue.adjacent(selected.index, direction, playable);
      if (next == null) return;
      final target = selected.queue.entries[next]!;
      if (!automatic) _armed = true;
      if (guardedPlay != null) {
        final started = await guardedPlay!(
            target,
            () =>
                generation == _generation &&
                (!automatic || (_armed && autoplay())));
        if (!started) return;
      } else {
        await play(target);
      }
      if (generation == _generation) {
        value = AudioQueuePosition(selected.queue, next);
      }
    });
    _operations = operation.catchError((Object _) {});
    return operation;
  }
}
