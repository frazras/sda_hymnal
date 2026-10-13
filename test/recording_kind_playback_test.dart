import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late List<String> media, native;
  late List<(String, int, RecordingKind)> loads;
  late ValueNotifier<RecordingKind> voice;
  late MidiPlayer player;
  RecordingKind? failing;

  Hymn hymn(String book, int n) =>
      Hymn(number: n, version: book, title: '$book $n', body: 'Lyrics');
  int count(List<String> calls, String method) =>
      calls.where((m) => m == method).length;
  // Queued after any swap the preference listener has started.
  Future<void> settle() => player.stopPreview();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recording-kind-');
    media = [];
    native = [];
    loads = [];
    failing = null;
    voice = ValueNotifier(RecordingKind.instrumental);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
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
      final id = (call.arguments as Map)['playerId'] as String;
      media.add(call.method);
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      if (call.method == 'setSourceUrl') {
        await messenger.handlePlatformMessage(
            'xyz.luan/audioplayers/events/$id',
            const StandardMethodCodec().encodeSuccessEnvelope(
                {'event': 'audio.onPrepared', 'value': true}),
            (_) {});
      }
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
    player = MidiPlayer.forTesting(
        useNative: true,
        recordingVoice: voice,
        recordingFile: (book, n, kind) async {
          loads.add((book, n, kind));
          if (kind == failing) throw const SocketException('offline');
          return File('${dir.path}/$book-$n-${kind.name}.m4a');
        });
  });

  tearDown(() async {
    await player.stop();
    await dir.delete(recursive: true);
  });

  test('playback uses the preferred kind or the hymn\'s other recorded kind',
      () async {
    final spanish = hymn('sda-es-2009', 1);
    expect(MidiPlayer.recordingKinds(spanish),
        [RecordingKind.instrumental, RecordingKind.sung]);
    expect(player.recordingKindFor(spanish), RecordingKind.instrumental);
    await player.toggle(spanish);
    expect(loads.last, ('sda-es-2009', 1, RecordingKind.instrumental));
    expect(player.recordingKind.value, RecordingKind.instrumental);
    await player.stop();
    expect(player.recordingKind.value, isNull);

    voice.value = RecordingKind.sung;
    await settle();
    expect(loads, hasLength(1), reason: 'a stopped player loads nothing');
    await player.toggle(spanish);
    expect(loads.last, ('sda-es-2009', 1, RecordingKind.sung));
    expect(player.recordingKind.value, RecordingKind.sung);

    // Portuguese has only sung recordings; Russian only instrumental ones.
    await player.stop();
    voice.value = RecordingKind.instrumental;
    await settle();
    final portuguese = hymn('sda-pt-1996', 12);
    expect(MidiPlayer.recordingKinds(portuguese), [RecordingKind.sung]);
    await player.toggle(portuguese);
    expect(loads.last, ('sda-pt-1996', 12, RecordingKind.sung));
    expect(player.recordingKind.value, RecordingKind.sung);
    voice.value = RecordingKind.sung;
    final before = loads.length;
    await settle();
    expect(loads, hasLength(before), reason: 'the resolved kind is unchanged');
    final russian = hymn('sda-ru-1997', 385);
    await player.toggle(russian);
    expect(loads.last, ('sda-ru-1997', 385, RecordingKind.instrumental));
    expect(player.current.value?.version, 'sda-ru-1997');
    expect(player.current.value?.paused, isFalse);
  });

  test('verified MIDI keeps precedence over every recording kind', () async {
    voice.value = RecordingKind.sung;
    for (final n in [303, 230]) {
      final midi = hymn('sda-es-2009', n);
      expect(MidiPlayer.hasMidi(midi), isTrue);
      expect(MidiPlayer.recordingKinds(midi), isEmpty);
      expect(player.recordingKindFor(midi), isNull);
      await player.toggle(midi);
      expect(native, contains('play'));
      expect(player.current.value?.n, n);
      expect(player.recordingKind.value, isNull);
      voice.value = RecordingKind.instrumental;
      await settle();
      voice.value = RecordingKind.sung;
      await settle();
      expect(player.current.value?.paused, isFalse);
      await player.stop();
    }
    expect(loads, isEmpty);
    final english = hymn('new', 108);
    expect(MidiPlayer.recordingKinds(english), isEmpty);
    expect(player.recordingKindFor(english), isNull);
  });

  test('changing the preference swaps a loaded recording without autoplay',
      () async {
    final spanish = hymn('sda-es-2009', 100);
    await player.toggle(spanish);
    final sources = count(media, 'setSourceUrl');
    final resumes = count(media, 'resume');
    voice.value = RecordingKind.sung;
    await settle();
    expect(loads.last, ('sda-es-2009', 100, RecordingKind.sung));
    expect(player.recordingKind.value, RecordingKind.sung);
    expect(player.current.value?.paused, isFalse);
    expect(count(media, 'setSourceUrl'), sources + 1);
    expect(count(media, 'resume'), resumes + 1, reason: 'playing continues');
    expect(player.position.value, Duration.zero);

    await player.toggle(spanish);
    expect(player.current.value?.paused, isTrue);
    final pausedResumes = count(media, 'resume');
    voice.value = RecordingKind.instrumental;
    await settle();
    expect(loads.last, ('sda-es-2009', 100, RecordingKind.instrumental));
    expect(player.recordingKind.value, RecordingKind.instrumental);
    expect(player.current.value?.paused, isTrue);
    expect(count(media, 'setSourceUrl'), sources + 2);
    expect(count(media, 'resume'), pausedResumes,
        reason: 'a paused recording never starts by itself');
    await player.toggle(spanish);
    expect(player.current.value?.paused, isFalse);
    expect(count(media, 'resume'), pausedResumes + 1);
    expect(loads, hasLength(3), reason: 'resuming reuses the swapped source');
  });

  test('recording voice preference persists and defaults to instrumental',
      () async {
    const instrumental = RecordingKind.instrumental, sung = RecordingKind.sung;
    SharedPreferences.setMockInitialValues({});
    final saved = RecordingVoice.instance;
    await saved.load();
    expect(saved.value, instrumental);
    await saved.set(sung);
    expect(saved.value, sung);
    expect((await SharedPreferences.getInstance()).getString('recordingVoice'),
        'sung');
    saved.value = instrumental;
    await saved.load();
    expect(saved.value, sung);
    SharedPreferences.setMockInitialValues({'recordingVoice': 'choir'});
    await saved.load();
    expect(saved.value, instrumental);
    await saved.set(instrumental);
    expect((await SharedPreferences.getInstance()).getString('recordingVoice'),
        'instrumental');
  });

  test('a failed swap stops cleanly and the next start retries', () async {
    final spanish = hymn('sda-es-2009', 7);
    await player.toggle(spanish);
    failing = RecordingKind.sung;
    voice.value = RecordingKind.sung;
    await settle();
    expect(player.current.value, isNull);
    expect(player.recordingKind.value, isNull);
    expect(player.loading.value, isFalse);
    await expectLater(player.toggle(spanish), throwsA(isA<SocketException>()));
    expect(player.current.value, isNull);
    failing = null;
    await player.toggle(spanish);
    expect(player.recordingKind.value, RecordingKind.sung);
    expect(player.current.value?.paused, isFalse);
  });
}
