import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:sdahymnal/services/midi_player.dart';

/// System controls observe and command the existing player; no second engine.
class HymnalAudioHandler extends BaseAudioHandler {
  HymnalAudioHandler(this.player) {
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
              playing ? MediaControl.pause : MediaControl.play,
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
      androidCompactActionIndices: visible ? const [0] : [],
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
  Future<void> play() => player.resume();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> stop() => player.stop();
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
        unawaited(MidiPlayer.instance.pause().catchError((Object _) {}));
      }
    }));
    _subscriptions.add(session.becomingNoisyEventStream.listen((_) {
      unawaited(MidiPlayer.instance.pause().catchError((Object _) {}));
    }));
  }
}
