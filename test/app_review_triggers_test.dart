import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/app_review.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/tabs.dart';
import 'package:sdahymnal/models/release_notes.dart';
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
  var reviewRequests = 0;
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
    reviewRequests = 0;
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.britannio.in_app_review'), (call) async {
      if (call.method == 'isAvailable') return true;
      if (call.method == 'requestReview') reviewRequests++;
      return null;
    });
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
    await AutoScroll.instance.set(false);
    await KeepScreenOn.instance.set(false);
    MusicPlayerVisible.instance.value = false;
    await Favorites.instance.load();
  });

  testWidgets('routine endings request reviews without interrupting playlists',
      (tester) async {
    for (final category in [true, false]) {
      MusicPlayerVisible.instance.value = true;
      await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light),
          home: HymnPage(
              hymn: first,
              hymns: list,
              categoryTitle: category ? 'Favorites' : null)));
      await tester.pump();
      MidiPlayer.instance.current.value =
          (n: first.number, version: first.version, paused: false);
      await tester.pump();
      await audioEvent('audio.onComplete');
      await tester.pump();
      expect(MidiPlayer.instance.current.value, isNull);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(reviewRequests, category ? 0 : 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppReviewService.lastRequestKey);
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: HymnPage(hymn: first, hymns: list)));
    await tester.pump();
    final heart = find.byKey(const ValueKey('hymn-favorite-header-button'));
    await tester.tap(heart);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(reviewRequests, 2);
    await prefs.remove(AppReviewService.lastRequestKey);
    await tester.tap(heart);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(reviewRequests, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await prefs.setStringList('seenReleaseVersions', [appReleaseVersion]);
    await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light), home: const Tabs()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Settings').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.text('Rate this app'), 300,
        scrollable: find.descendant(
            of: find.byKey(const ValueKey('settings-list')),
            matching: find.byType(Scrollable)));
    expect(find.text('Rate this app'), findsOneWidget);
    await tester.tap(find.text('Numbers').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(reviewRequests, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
