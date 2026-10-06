import 'package:sdahymnal/models/service_playlist.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/ui/service_reader.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/playback_continuation.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/ui/favorites.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/hymn_sheet_music.dart';
import 'package:sdahymnal/theme.dart';

class _TestAudioCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async =>
      File('assets/$fileName').absolute.path;
}

void main() {
  AudioCache.instance = _TestAudioCache();
  TestWidgetsFlutterBinding.ensureInitialized();
  Hymn hymn(int n, [String edition = 'new']) => Hymn(
      number: n, version: edition, title: '$edition hymn $n', body: 'Lyrics');
  final first = hymn(7);
  final second = hymn(7, 'old');
  final third = hymn(2);
  final list = [first, second, third];

  String? playerId;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Future<void> audioEvent(String event) async {
    await messenger.handlePlatformMessage(
        'xyz.luan/audioplayers/events/$playerId',
        const StandardMethodCodec()
            .encodeSuccessEnvelope({'event': event, 'value': true}),
        (_) {});
  }

  setUp(() {
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      playerId = (call.arguments as Map)['playerId'] as String;
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$playerId'),
            (_) async => null);
      }
      if (call.method == 'setSourceUrl' || call.method == 'setSourceAsset') {
        await audioEvent('audio.onPrepared');
      }
      if (call.method == 'getDuration') return 10000;
      if (call.method == 'getCurrentPosition') return 0;
      return null;
    });
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Autoplay.instance.load();
    await KeepScreenOn.instance.set(false);
    MusicPlayerVisible.instance.value = false;
    await Favorites.instance.load();
  });

  test('autoplay defaults off and persists without starting playback',
      () async {
    expect(Autoplay.instance.value, isFalse);
    await Autoplay.instance.set(true);
    await Autoplay.instance.load();
    expect(Autoplay.instance.value, isTrue);
    await Autoplay.instance.set(false);
    await Autoplay.instance.load();
    expect(Autoplay.instance.value, isFalse);
  });

  test('list order, mixed editions, wrapping and unsupported media', () {
    expect(nextPlayableHymn(list, first, (_) => true), second);
    expect(nextPlayableHymn(list, second, (_) => true), third);
    expect(nextPlayableHymn(list, third, (_) => true), first);
    expect(nextPlayableHymn(list, first, (h) => h == third), third);
    expect(nextPlayableHymn(list, first, (_) => false), isNull);
    expect(nextPlayableHymn([], first, (_) => true), isNull);
    expect(nextPlayableHymn(list, hymn(99), (_) => true), isNull);
    expect(nextPlayableHymn([first], first, (_) => true), first);
  });

  test('video end requires playing; pause and duplicate ends never advance',
      () {
    final gate = PlaybackEndGate();
    expect(gate.ended(), isFalse);
    gate.playing();
    gate.stop();
    expect(gate.ended(), isFalse);
    gate.playing();
    expect(gate.ended(), isTrue);
    expect(gate.ended(), isFalse);
    gate.playing();
    expect(gate.ended(), isTrue);
  });

  testWidgets(
      'manual playback respects pause, service repeats, and the service end',
      (tester) async {
    await Autoplay.instance.set(true);
    MusicPlayerVisible.instance.value = true;
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: HymnPage(
            hymn: first,
            hymns: list,
            categoryTitle: 'Test list',
            showSheetMusic: true)));
    await tester.pump();
    expect(MidiPlayer.instance.current.value, isNull);
    await tester.tap(find.byKey(const ValueKey('hymn-play-pause')));
    await tester.pump();
    expect(MidiPlayer.instance.current.value?.n, first.number);
    await audioEvent('audio.onComplete');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn, second);
    expect(
        tester.widget<HymnPage>(find.byType(HymnPage)).showSheetMusic, isTrue);
    expect(find.byType(HymnSheetMusic), findsOneWidget);
    expect(MidiPlayer.instance.current.value?.version, 'old');
    await tester.tap(find.byKey(const ValueKey('hymn-play-pause')));
    await tester.pump();
    expect(MidiPlayer.instance.current.value?.paused, isTrue);
    await audioEvent('audio.onComplete');
    await tester.pump();
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn, second);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await Autoplay.instance.set(true);
    MusicPlayerVisible.instance.value = true;
    final session = ServiceReader(
        repository: HymnalRepository.english([first]),
        playlist:
            ServicePlaylist(id: 'service', name: 'Repeated hymn', entries: [
          ServiceEntry(id: 'opening', ref: first.ref),
          ServiceEntry(id: 'closing', ref: first.ref),
        ]));
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light), home: session.page(0)));
    await tester.pumpAndSettle();
    expect(MidiPlayer.instance.current.value, isNull);
    await tester.tap(find.byKey(const ValueKey('hymn-play-pause')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(MidiPlayer.instance.current.value?.paused, isFalse);
    await audioEvent('audio.onComplete');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Service: Repeated hymn · 2 of 2'), findsOneWidget);
    expect(MidiPlayer.instance.current.value?.n, first.number);
    await audioEvent('audio.onComplete');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Service: Repeated hymn · 2 of 2'), findsOneWidget);
    expect(MidiPlayer.instance.current.value, isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('main Favorites carries only its displayed mixed-edition list',
      (tester) async {
    await Favorites.instance.toggle(first);
    await Favorites.instance.toggle(second);
    final order = Favorites.instance.value
        .map((e) => e.v == 'old' ? second : first)
        .toList();
    await Autoplay.instance.set(true);
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: Scaffold(
            body: FavoritesTab(hymnsNew: [first, third], hymnsOld: [second]))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('new hymn 7').first);
    await tester.pumpAndSettle();
    final page = tester.widget<HymnPage>(find.byType(HymnPage));
    expect(page.categoryTitle, 'Favorites');
    expect(page.hymns, order);
    expect(page.continuation, isNull);
    expect(MidiPlayer.instance.current.value, isNull,
        reason: 'Opening a hymn with autoplay enabled must not start music');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
