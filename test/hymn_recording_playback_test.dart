import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/playback_queue.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/system_audio.dart';
import 'package:sdahymnal/services/audio_queue.dart';
import 'package:audio_service/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('iOS switches engines, pauses, seeks and ignores inactive completions',
      () async {
    final dir = await Directory.systemTemp.createTemp('recording-playback-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final native = <String>[];
    var failNativePause = false;
    final media = <String>[];
    String? id;
    Future<void> audioEvent(String event) async {
      await messenger.handlePlatformMessage(
          'xyz.luan/audioplayers/events/$id',
          const StandardMethodCodec()
              .encodeSuccessEnvelope({'event': event, 'value': true}),
          (_) {});
      await Future<void>.delayed(Duration.zero);
    }

    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ]) {
      messenger.setMockMethodCallHandler(
          MethodChannel(channel), (_) async => null);
    }
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => dir.path);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      id = (call.arguments as Map)['playerId'] as String;
      media.add(call.method);
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      if (call.method == 'seek') await audioEvent('audio.onSeekComplete');
      if (call.method == 'setSourceUrl') await audioEvent('audio.onPrepared');
      if (call.method == 'getDuration') return 120000;
      if (call.method == 'getCurrentPosition') return 0;
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('sdahymnal/midi'),
        (call) async {
      native.add(call.method);
      if (call.method == 'pause' && failNativePause) {
        throw PlatformException(code: 'PAUSE_FAILED');
      }
      if (call.method == 'load') return 120.0;
      if (call.method == 'getPosition') return 0.0;
      return null;
    });
    var fetched = 0;
    Completer<File>? pendingDownload;
    final player = MidiPlayer.forTesting(
        useNative: true,
        recordingFile: (book, n) async {
          fetched++;
          if (pendingDownload != null) return pendingDownload.future;
          return File('${dir.path}/$book-$n.m4a');
        });
    final hymn = Hymn(
        number: 1, version: 'sda-es-1962', title: 'Cantad', body: 'Lyrics');
    final midi = Hymn(
        number: 303,
        version: 'sda-es-2009',
        title: 'Sublime gracia',
        body: 'Lyrics');
    final handler = HymnalAudioHandler(player,
        queue: AudioQueue(
            play: player.toggle,
            playable: MidiPlayer.hasMusic,
            autoplay: () => false));
    expect(handler.mediaItem.value, isNull);
    await handler.play();
    expect(player.current.value, isNull);
    final completions = <MidiPlayback>[];
    final sub = player.completions.listen(completions.add);
    expect(player.current.value, isNull);
    await player.toggle(midi);
    expect(native, contains('play'));
    expect(handler.mediaItem.value?.id, 'sda-es-2009:303');
    expect(handler.mediaItem.value?.title, 'Sublime gracia');
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.controls, contains(MediaControl.pause));
    failNativePause = true;
    await expectLater(handler.pause(), throwsA(isA<PlatformException>()));
    expect(player.current.value?.paused, isFalse);
    failNativePause = false;
    await handler.pause();
    final nativePauses = native.where((m) => m == 'pause').length;
    await handler.pause();
    expect(player.current.value?.paused, isTrue);
    expect(native.where((m) => m == 'pause').length, nativePauses);
    await handler.play();
    final nativePlays = native.where((m) => m == 'play').length;
    await handler.play();
    expect(player.current.value?.paused, isFalse);
    expect(native.where((m) => m == 'play').length, nativePlays);
    await player.toggle(hymn);
    expect(native.last, 'stop');
    expect(fetched, 1);
    expect(media, contains('setSourceUrl'));
    expect(player.current.value?.version, 'sda-es-1962');
    await messenger.handlePlatformMessage(
        'sdahymnal/midi',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('onComplete')),
        (_) {});
    expect(player.current.value?.version, 'sda-es-1962');
    await player.toggle(hymn);
    expect(player.current.value?.paused, isTrue);
    await player.toggle(hymn);
    expect(player.current.value?.paused, isFalse);
    await handler.pause();
    final mediaPauses = media.where((m) => m == 'pause').length;
    await handler.pause();
    expect(player.current.value?.paused, isTrue);
    expect(media.where((m) => m == 'pause').length, mediaPauses);
    final sources = media.where((m) => m == 'setSourceUrl').length;
    await handler.play();
    final mediaResumes = media.where((m) => m == 'resume').length;
    await handler.play();
    expect(player.current.value?.paused, isFalse);
    expect(media.where((m) => m == 'resume').length, mediaResumes);
    expect(media.where((m) => m == 'setSourceUrl').length, sources);
    expect(fetched, 1);
    await player.seekBy(const Duration(seconds: 10));
    expect(media, contains('seek'));
    expect(handler.mediaItem.value?.title, 'Cantad');
    expect(handler.mediaItem.value?.id, 'sda-es-1962:1');
    await handler.seek(const Duration(seconds: 30));
    expect(player.position.value, const Duration(seconds: 30));
    await handler.rewind();
    expect(player.position.value, const Duration(seconds: 20));
    await handler.fastForward();
    expect(player.position.value, const Duration(seconds: 30));
    await player.setSpeed(1.25);
    expect(media.last, 'setPlaybackRate');
    InstrumentTheme.instance.value = 'jazz';
    await Future<void>.delayed(Duration.zero);
    expect(fetched, 1,
        reason: 'Changing MIDI styles must not reload a recording');
    InstrumentTheme.instance.value = 'classic';
    await audioEvent('audio.onComplete');
    expect(completions.single.version, 'sda-es-1962');
    expect(player.current.value, isNull);
    await player.toggle(midi);
    await audioEvent('audio.onComplete');
    expect(player.current.value?.n, 303);
    expect(completions.length, 1);
    await player.stop();
    pendingDownload = Completer<File>();
    final pending = player.toggle(hymn);
    while (!player.loading.value) {
      await Future<void>.delayed(Duration.zero);
    }
    final stop = player.stop();
    final resumes = media.where((m) => m == 'resume').length;
    pendingDownload.complete(File('${dir.path}/delayed.m4a'));
    await Future.wait([pending, stop]);
    expect(media.where((m) => m == 'resume').length, resumes);
    expect(player.current.value, isNull);
    expect(player.loading.value, isFalse);
    await handler.pause();
    await handler.play();
    expect(player.current.value, isNull);
    expect(handler.mediaItem.value, isNull);
    expect(
        handler.playbackState.value.processingState, AudioProcessingState.idle);
    handler.audioQueue.select(
        HymnPlaybackQueue(
            entries: [hymn, midi], wrap: true, skipUnavailable: true),
        0);
    await player.toggle(hymn);
    expect(handler.playbackState.value.controls,
        contains(MediaControl.skipToNext));
    await handler.skipToNext();
    expect(handler.mediaItem.value?.id, 'sda-es-2009:303');
    expect(handler.audioQueue.value!.index, 1);
    await handler.skipToPrevious();
    expect(handler.mediaItem.value?.id, 'sda-es-1962:1');
    expect(handler.audioQueue.value!.index, 0);
    await handler.stop();
    expect(handler.audioQueue.value, isNull);
    expect(handler.mediaItem.value, isNull);
    handler.detach();
    await sub.cancel();
    await dir.delete(recursive: true);
  });
}
