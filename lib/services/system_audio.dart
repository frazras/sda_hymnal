import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'audio_queue.dart';

/// System controls observe and command the existing player; no second engine.
class HymnalAudioHandler extends BaseAudioHandler {
  HymnalAudioHandler(this.player, {AudioQueue? queue})
      : audioQueue = queue ?? AudioQueue.instance {
    audioQueue.addListener(_publish);
    for (final notifier in [
      player.current,
      player.loading,
      player.duration,
      player.speed
    ]) {
      notifier.addListener(_publish);
    }
    player.position.addListener(_positionChanged);
    _publish();
  }

  final MidiPlayer player;
  final AudioQueue audioQueue;
  DateTime _lastPositionUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  void _positionChanged() {
    final now = DateTime.now();
    if (now.difference(_lastPositionUpdate) < const Duration(seconds: 1)) {
      return;
    }
    _lastPositionUpdate = now;
    _publish();
  }

  void _publish() {
    final current = player.current.value;
    final hymn = player.loadedHymn;
    final visible = current != null && !player.isPreview;
    final playing = visible && !current.paused && !player.loading.value;
    final selected = audioQueue.value;
    final previous =
        selected?.queue.adjacent(selected.index, -1, MidiPlayer.hasMusic);
    final next =
        selected?.queue.adjacent(selected.index, 1, MidiPlayer.hasMusic);
    mediaItem.add(visible && hymn != null
        ? MediaItem(
            id: '${current.version}:${current.n}',
            title: hymn.title,
            album: hymn.bookLabel,
            duration: player.duration.value > Duration.zero
                ? player.duration.value
                : null,
          )
        : null);
    playbackState.add(PlaybackState(
      controls: visible
          ? [
              if (previous != null) MediaControl.skipToPrevious,
              playing ? MediaControl.pause : MediaControl.play,
              if (next != null) MediaControl.skipToNext,
              MediaControl.stop
            ]
          : [],
      systemActions: visible
          ? const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward
            }
          : {},
      androidCompactActionIndices: visible
          ? [
              if (previous != null) 0,
              previous != null ? 1 : 0,
              if (next != null) previous != null ? 2 : 1
            ]
          : [],
      processingState: !visible
          ? AudioProcessingState.idle
          : player.loading.value
              ? AudioProcessingState.loading
              : AudioProcessingState.ready,
      playing: playing,
      updatePosition: player.position.value,
      speed: player.speed.value,
    ));
  }

  @override
  Future<void> play() async {
    audioQueue.arm();
    await player.resume();
  }

  @override
  Future<void> pause() async {
    audioQueue.cancelPending();
    await player.pause();
  }

  @override
  Future<void> stop() async {
    audioQueue.clear();
    await player.stop();
  }

  @override
  Future<void> skipToNext() => audioQueue.advance(1);
  @override
  Future<void> skipToPrevious() => audioQueue.advance(-1);
  @override
  Future<void> seek(Duration position) async {
    await player.seekBy(position - player.position.value);
    _publish();
  }

  @override
  Future<void> fastForward() =>
      seek(player.position.value + const Duration(seconds: 10));
  @override
  Future<void> rewind() =>
      seek(player.position.value - const Duration(seconds: 10));

  @visibleForTesting
  void detach() {
    audioQueue.removeListener(_publish);
    for (final notifier in [
      player.current,
      player.loading,
      player.duration,
      player.speed
    ]) {
      notifier.removeListener(_publish);
    }
    player.position.removeListener(_positionChanged);
  }
}

class SystemAudio {
  static AudioHandler? handler;
  static final List<StreamSubscription<dynamic>> _subscriptions = [];

  static Future<void> initialize() async {
    handler = await AudioService.init(
      builder: () => HymnalAudioHandler(MidiPlayer.instance),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sda.hymnal.audio',
        androidNotificationChannelName: 'Hymnal playback',
        androidNotificationOngoing: true,
      ),
    );
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Never resume automatically after a call or route change. The user decides.
    _subscriptions.add(session.interruptionEventStream.listen((event) {
      if (event.begin) {
        AudioQueue.instance.cancelPending();
        unawaited(MidiPlayer.instance.pause().catchError((Object _) {}));
      }
    }));
    _subscriptions.add(session.becomingNoisyEventStream.listen((_) {
      AudioQueue.instance.cancelPending();
      unawaited(MidiPlayer.instance.pause().catchError((Object _) {}));
    }));
  }
}
