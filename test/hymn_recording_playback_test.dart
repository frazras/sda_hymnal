import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('iOS switches engines, pauses, seeks and ignores inactive completions',
      () async {
    final dir = await Directory.systemTemp.createTemp('recording-playback-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final native = <String>[];
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
    final completions = <MidiPlayback>[];
    final sub = player.completions.listen(completions.add);
    expect(player.current.value, isNull);
    await player.toggle(midi);
    expect(native, contains('play'));
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
    await player.seekBy(const Duration(seconds: 10));
    expect(media, contains('seek'));
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
    await sub.cancel();
    await dir.delete(recursive: true);
  });
}
