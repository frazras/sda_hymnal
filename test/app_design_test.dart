import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdahymnal/main.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_metadata.dart';
import 'package:sdahymnal/models/hymn_video.dart';
import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/ui/classic.dart';
import 'package:sdahymnal/ui/settings.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/hymn_auto_scroll.dart';
import 'package:sdahymnal/ui/fontsize.dart';
import 'package:sdahymnal/ui/report_error.dart';
import 'package:sdahymnal/ui/favorite_burst.dart';
import 'package:sdahymnal/theme.dart';

class _HymnAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key == 'assets/hymns.json' ||
        key == 'assets/hymn_metadata.json' ||
        key == 'assets/hymn_videos.json') {
      return SynchronousFuture(File(key).readAsStringSync());
    }
    return super.loadString(key, cache: cache);
  }
}

// Keep the bundled MIDI source real, but avoid copying it through a host
// path-provider plugin. The mocked media engine receives this actual file.
class _TestAudioCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async =>
      File('assets/$fileName').absolute.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hymns =
      HymnApi.allHymnsFromJson(File('assets/hymns.json').readAsStringSync());
  final audioCalls = <MethodCall>[];
  AudioCache.instance = _TestAudioCache();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('sdahymnal/app_icon'), (_) async => null);
    SharedPreferences.setMockInitialValues({
      ReleaseNotesService.seenVersionsKey: <String>[appReleaseVersion],
    });
    await AppDesignController.instance.load();
    await ThemeController.instance.load();
    await FontSizeController.instance.load();
    await Recents.instance.load();
    await Favorites.instance.load();
    await KeepScreenOn.instance.set(false);
    await AutoScroll.instance.load();
    await MusicPlayerVisible.instance.load();
    await InstrumentTheme.instance.load();
    audioCalls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      audioCalls.add(call);
      final id = (call.arguments as Map)['playerId'];
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      if (call.method == 'setSourceUrl' || call.method == 'seek') {
        await messenger.handlePlatformMessage(
          'xyz.luan/audioplayers/events/$id',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'event': call.method == 'seek'
                ? 'audio.onSeekComplete'
                : 'audio.onPrepared',
            'value': true,
          }),
          (_) {},
        );
      }
      if (call.method == 'getDuration') return 10000;
      if (call.method == 'getCurrentPosition') return 0;
      return null;
    });
  });

  Future<void> chooseReaderOption(WidgetTester tester, Key optionKey) async {
    await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final option = find.byKey(optionKey);
    expect(option, findsOneWidget);
    final label = switch (optionKey) {
      const ValueKey('hymn-player-visibility') =>
        find.textContaining('music player'),
      const ValueKey('hymn-youtube-button') =>
        find.textContaining('hymn video'),
      const ValueKey('hymn-scroll-speed-menu-item') =>
        find.text('Scroll speed'),
      const ValueKey('hymn-font-size-button') => find.text('Text size'),
      const ValueKey('hymn-chord-tabs') => find.textContaining('chord tabs'),
      _ => option,
    };
    await tester.tap(label);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> chooseScrollSpeed(WidgetTester tester, Key optionKey) async {
    final control = tester.widget<HymnAutoScrollControl>(
        find.byKey(const ValueKey('hymn-auto-scroll-toggle')));
    final value = switch (optionKey) {
      const ValueKey('hymn-scroll-slower') => control.speed - 0.1,
      const ValueKey('hymn-scroll-faster') => control.speed + 0.1,
      const ValueKey('hymn-scroll-speed-reset') => control.defaultSpeed,
      _ => throw ArgumentError.value(optionKey),
    };
    control.onSpeedChanged(value.clamp(0.5, 2));
    await tester.pump();
  }

  // Keep the native-player lifecycle in one widget test. Its singleton's
  // ready Future belongs to that test's fake clock; later tests observe
  // playback notifiers without invoking that engine across test clocks.
  testWidgets('Both designs and editions share playback and exit cleanup',
      (tester) async {
    for (final classic in [false, true]) {
      for (final version in ['new', 'old']) {
        audioCalls.clear();
        MusicPlayerVisible.instance.value = true;
        final list = hymns.where((h) => h.version == version).toList();
        final hymn = hymnByNumber(list, 533)!;
        await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
          home: HymnPage(hymn: hymn, hymns: list),
        ));
        await tester.pump();
        final play = find.byKey(const ValueKey('hymn-play-pause'));
        await tester.tap(play);
        await tester.pump();
        expect(MidiPlayer.instance.current.value,
            (version: version, n: 533, paused: false),
            reason:
                'Audio calls: ${audioCalls.map((call) => call.method).toList()}');
        expect(
            audioCalls.where((c) => c.method == 'setSourceUrl'), hasLength(1));
        final source = audioCalls.firstWhere((c) => c.method == 'setSourceUrl');
        final prefix = version == 'old' ? 'C' : '';
        expect((source.arguments as Map)['url'],
            endsWith('/assets/midi/${prefix}533.mid'));
        expect(audioCalls.any((c) => c.method == 'resume'), isTrue);
        final callsBeforeHide = audioCalls.length;
        await chooseReaderOption(
            tester, const ValueKey('hymn-player-visibility'));
        expect(find.byKey(const ValueKey('hymn-music-player')), findsNothing);
        expect(MidiPlayer.instance.current.value,
            (version: version, n: 533, paused: false));
        expect(
            audioCalls.skip(callsBeforeHide).where(
                (c) => ['pause', 'stop', 'setSourceUrl'].contains(c.method)),
            isEmpty);
        await chooseReaderOption(
            tester, const ValueKey('hymn-player-visibility'));
        expect(find.byKey(const ValueKey('hymn-music-player')), findsOneWidget);
        await tester.tap(play);
        await tester.pump();
        expect(MidiPlayer.instance.current.value,
            (version: version, n: 533, paused: true));
        expect(audioCalls.any((c) => c.method == 'pause'), isTrue);
        await tester.tap(play);
        await tester.pump();
        expect(MidiPlayer.instance.current.value,
            (version: version, n: 533, paused: false));
        expect(
            audioCalls.where((c) => c.method == 'setSourceUrl'), hasLength(1),
            reason: 'resume must not reload the tune');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(MidiPlayer.instance.current.value, isNull);
        expect(audioCalls.where((c) => !c.method.startsWith('get')).last.method,
            'stop');
        expect(tester.takeException(), isNull);
      }
    }
  });

  final lyricsScroll = find.byKey(const ValueKey('hymn-lyrics-scroll'));
  final scrollToggle = find.byKey(const ValueKey('hymn-auto-scroll-toggle'));
  final musicPlayer = find.byKey(const ValueKey('hymn-music-player'));

  Future<void> toggleAutoScroll(WidgetTester tester) async {
    tester.widget<HymnAutoScrollControl>(scrollToggle).onToggle();
    await tester.pump();
  }

  Future<void> pauseAutoScroll(WidgetTester tester) async {
    await toggleAutoScroll(tester);
    expect(scrollToggle, findsOneWidget);
  }

  ScrollController readerScroll(WidgetTester tester) =>
      tester.widget<SingleChildScrollView>(lyricsScroll).controller!;

  Future<Duration> pumpReader(WidgetTester tester,
      {bool classic = false,
      bool dark = false,
      String version = 'new',
      int number = 534}) async {
    final list = hymns.where((h) => h.version == version).toList();
    final hymn = hymnByNumber(list, number)!;
    final duration =
        await tester.runAsync(() => MidiPlayer.instance.readingDuration(hymn));
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(dark ? HymnalTokens.dark : HymnalTokens.light,
          classic: classic),
      home: HymnPage(hymn: hymn, hymns: list),
    ));
    await tester.pump();
    await tester.pump();
    return duration ?? Duration.zero;
  }

  testWidgets('Report Errors opens from both hymn editions and designs',
      (tester) async {
    for (final classic in [false, true]) {
      for (final version in ['old', 'new']) {
        await pumpReader(tester, classic: classic, version: version);
        await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report Errors'));
        await tester.pumpAndSettle();
        final page =
            tester.widget<ReportErrorPage>(find.byType(ReportErrorPage));
        expect(page.subject.edition, version);
        expect(page.subject.number, 534);
        expect(
            page.subject.title,
            hymnByNumber(
                    hymns.where((h) => h.version == version).toList(), 534)!
                .title);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    }
  });

  test('auto-scroll defaults off and survives a restart', () async {
    expect(AutoScroll.instance.value, isFalse);
    await AutoScroll.instance.set(true);
    AutoScroll.instance.value = false;
    await AutoScroll.instance.load();
    expect(AutoScroll.instance.value, isTrue);
    await AutoScroll.instance.set(false);
    AutoScroll.instance.value = true;
    await AutoScroll.instance.load();
    expect(AutoScroll.instance.value, isFalse);
  });

  testWidgets('music-player visibility persists across hymns and app reloads',
      (tester) async {
    expect(MusicPlayerVisible.instance.value, isTrue);
    await pumpReader(tester);
    expect(musicPlayer, findsOneWidget);
    await chooseReaderOption(tester, const ValueKey('hymn-player-visibility'));
    expect(musicPlayer, findsNothing);
    expect(
        (await SharedPreferences.getInstance()).getBool('musicPlayerVisible'),
        isFalse);

    await tester.drag(lyricsScroll, const Offset(-250, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.number, 535);
    expect(musicPlayer, findsNothing,
        reason: 'The hidden preference applies to the next hymn');

    MusicPlayerVisible.instance.value = true;
    await MusicPlayerVisible.instance.load();
    expect(MusicPlayerVisible.instance.value, isFalse,
        reason: 'The hidden preference reloads for a new app session');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('header favorite remains and menu toggles saved chord tabs',
      (tester) async {
    await ChordTabs.instance.set(false);
    await MusicPlayerVisible.instance.set(false);
    await pumpReader(tester);
    final headerFavorite =
        find.byKey(const ValueKey('hymn-favorite-header-button'));
    expect(headerFavorite, findsOneWidget);
    await tester.tap(headerFavorite);
    await tester.pump();
    expect(Favorites.instance.contains(534, 'new'), isTrue);
    await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hymn-favorite-button')), findsNothing);
    expect(find.text('Show chord tabs'), findsOneWidget);
    await tester.tap(find.text('Show chord tabs'));
    await tester.pumpAndSettle();
    expect(ChordTabs.instance.value, isTrue);
    expect(MusicPlayerVisible.instance.value, isTrue);
    await chooseReaderOption(tester, const ValueKey('hymn-chord-tabs'));
    expect(ChordTabs.instance.value, isFalse);
    expect(MusicPlayerVisible.instance.value, isTrue);
    await ChordTabs.instance.load();
    expect(ChordTabs.instance.value, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('starting auto-scroll dismisses its speed sheet', (tester) async {
    await AutoScroll.instance.set(true);
    await pumpReader(tester);
    await tester.tap(scrollToggle);
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('hymn-scroll-speed-slider')), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('hymn-scroll-toggle-sheet-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        find.byKey(const ValueKey('hymn-scroll-speed-slider')), findsNothing);
    expect(tester.widget<HymnAutoScrollControl>(scrollToggle).running, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('silent timing matches both editions and missing MIDI is safe',
      (tester) async {
    // Initialize native event subscriptions in the widget test zone, not a
    // preceding plain test's zone that is gone before playback tests run.
    final player = MidiPlayer.instance;
    await tester.pump();
    await tester.runAsync(() async {
      final hymn =
          hymnByNumber(hymns.where((h) => h.version == 'new').toList(), 16)!;
      final bytes = File('assets/midi/016.mid').readAsBytesSync();
      for (final theme in ['classic', 'organ', ...arrangedMidiThemes.keys]) {
        await InstrumentTheme.instance.set(theme);
        expect(await player.readingDuration(hymn),
            readMidiDuration(renderHymnMidi(bytes, theme: theme)));
      }
      await InstrumentTheme.instance.set('classic');
      final old =
          hymnByNumber(hymns.where((h) => h.version == 'old').toList(), 16)!;
      expect(await player.readingDuration(old),
          readMidiDuration(File('assets/midi/C016.mid').readAsBytesSync()));
      expect(
          await MidiPlayer.instance.readingDuration(
              Hymn(number: 999, title: 'Missing', body: '', version: 'new')),
          isNull);
    });
  });

  for (final classic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          '${classic ? 'Classic' : 'Modern'} compact reader controls on '
          'narrow ${dark ? 'dark' : 'light'} screens', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await AutoScroll.instance.set(true);
        final duration = await pumpReader(tester, classic: classic, dark: dark);
        expect(musicPlayer, findsOneWidget);
        expect(find.byKey(const ValueKey('hymn-favorite-header-button')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('hymn-scroll-speed-slider')),
            findsNothing,
            reason: 'The slider stays hidden until requested');
        await tester.tap(scrollToggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('hymn-scroll-speed-slider')),
            findsOneWidget);
        expect(find.text('1.0×'), findsOneWidget);
        expect(find.text('Slower  0.5×'), findsOneWidget);
        expect(find.text('2.0×  Faster'), findsOneWidget);
        final slider = tester.widget<Slider>(
            find.byKey(const ValueKey('hymn-scroll-speed-slider')));
        expect(slider.min, 0.5);
        expect(slider.max, 2.0);
        expect(slider.divisions, 15);
        Navigator.of(tester.element(
                find.byKey(const ValueKey('hymn-scroll-speed-slider'))))
            .pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final viewportHeight = tester.getSize(lyricsScroll).height;
        expect(tester.getSize(scrollToggle).height, lessThanOrEqualTo(28));
        await toggleAutoScroll(tester);
        expect(scrollToggle, findsOneWidget);
        expect(tester.getSize(lyricsScroll).height, viewportHeight,
            reason: 'Starting auto-scroll must not add or remove a row');
        await tester.pump(duration ~/ 4);
        await chooseReaderOption(
            tester, const ValueKey('hymn-scroll-speed-menu-item'));
        expect(find.byKey(const ValueKey('hymn-scroll-speed-slider')),
            findsOneWidget,
            reason: 'Scroll speed stays accessible after its pill scrolls');
        Navigator.of(tester.element(
                find.byKey(const ValueKey('hymn-scroll-speed-slider'))))
            .pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final controller = readerScroll(tester);
        final beforePlayerToggle =
            controller.offset / controller.position.maxScrollExtent;
        final extentWithPlayer = controller.position.maxScrollExtent;
        await chooseReaderOption(
            tester, const ValueKey('hymn-player-visibility'));
        expect(musicPlayer, findsNothing);
        expect(scrollToggle, findsOneWidget);
        expect(controller.position.maxScrollExtent, lessThan(extentWithPlayer),
            reason: 'Hiding the player reclaims the reserved reading space');
        final afterPlayerToggle =
            controller.offset / controller.position.maxScrollExtent;
        expect(afterPlayerToggle, greaterThan(beforePlayerToggle),
            reason: 'Reader menu must not pause an active scroll');
        await tester.pump(duration ~/ 4);
        expect(controller.offset / controller.position.maxScrollExtent,
            closeTo(afterPlayerToggle + 0.25, 0.002),
            reason: 'Toggling player visibility must not pause the scroll');
        await pauseAutoScroll(tester);
        final paused = controller.offset;
        await tester.pump(duration ~/ 4);
        expect(controller.offset, paused);
        await chooseReaderOption(
            tester, const ValueKey('hymn-player-visibility'));
        expect(musicPlayer, findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final classic in [false, true]) {
    testWidgets(
        '${classic ? 'Classic' : 'Modern'} video action fits the narrow reader header',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = hymnByNumber(
          hymns.where((hymn) => hymn.version == 'new').toList(), 536)!;
      final withVideo = Hymn(
        number: source.number,
        title: source.title,
        body: source.body,
        version: source.version,
        video: const HymnVideo(
          youtubeVideoId: 'eqg3Sv4Nicg',
          title: 'Rejoice, Ye Pure in Heart',
          channel: 'Amazing Worship TV',
          channelId: 'UCx4IY_thLXSbl7dCcr0veug',
          priority: 1,
        ),
      );
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
        home: HymnPage(hymn: withVideo, hymns: [withVideo]),
      ));
      await tester.pump();
      expect(find.byKey(const ValueKey('hymn-reader-options')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hymn-reader-options')));
      await tester.pump();
      expect(find.byKey(const ValueKey('hymn-youtube-button')), findsOneWidget);
      final title = tester.widget<Text>(classic
          ? find.text('${source.number} ${source.title}')
          : find.text(source.title));
      expect(title.maxLines, isNull);
      expect(title.overflow, isNot(TextOverflow.ellipsis));
      await tester.tapAt(Offset.zero);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('credits and story are compact content above the lyrics',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final metadata = HymnMetadataCatalog.fromJson(
        File('assets/hymn_metadata.json').readAsStringSync());
    final enriched = HymnApi.allHymnsFromJson(
      File('assets/hymns.json').readAsStringSync(),
      metadata: metadata,
    ).where((hymn) => hymn.version == 'old').toList();
    final hymn = hymnByNumber(enriched, 50)!;
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: HymnPage(hymn: hymn, hymns: enriched),
    ));
    await tester.pump();
    final words = find.textContaining('Words:');
    final story = find.byKey(const ValueKey('hymn-story-link'));
    expect(words, findsOneWidget);
    expect(story, findsOneWidget);
    expect(tester.getTopLeft(words).dy,
        lessThan(tester.getTopLeft(find.byType(Html)).dy));
    expect(tester.getTopLeft(story).dy,
        lessThan(tester.getTopLeft(find.byType(Html)).dy));
    expect(find.widgetWithText(TextButton, 'Read the story'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final classic in [false, true]) {
    testWidgets(
        '${classic ? 'Classic' : 'Modern'} repeats choruses and scrolls '
        'silently for the full MIDI duration, including speed changes',
        (tester) async {
      await AutoScroll.instance.set(true);
      await MidiPlayer.instance.setSpeed(1);
      final duration = await pumpReader(tester, classic: classic);
      expect(duration, greaterThan(Duration.zero));
      final body = tester.widget<Html>(find.byType(Html)).data!;
      expect('CHORUS</span>'.allMatches(body), hasLength(5));
      final controller = readerScroll(tester);
      expect(controller.position.maxScrollExtent, greaterThan(0));
      await toggleAutoScroll(tester);
      await tester.pump(duration ~/ 4);
      expect(controller.offset / controller.position.maxScrollExtent,
          closeTo(0.25, 0.005));
      expect(MidiPlayer.instance.current.value, isNull,
          reason: 'silent reading must not start audio');

      expect(scrollToggle, findsOneWidget);
      await pauseAutoScroll(tester);
      final paused = controller.offset;
      await tester.pump(duration ~/ 4);
      expect(controller.offset, paused);
      await toggleAutoScroll(tester);
      await MidiPlayer.instance.setSpeed(2);
      await tester.pump();
      await tester.pump(duration ~/ 4);
      expect(controller.offset / controller.position.maxScrollExtent,
          closeTo(0.75, 0.005));
      await tester.pump(duration);
      expect(controller.offset,
          closeTo(controller.position.maxScrollExtent, 0.01));
      expect(find.byIcon(Icons.play_arrow), findsWidgets);
      await toggleAutoScroll(tester);
      expect(controller.offset, 0, reason: 'Start at the end replays from top');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await MidiPlayer.instance.setSpeed(1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final classic in [false, true]) {
    testWidgets(
        '${classic ? 'Classic' : 'Modern'} incremental scroll speed '
        'preserves position, has bounds, and does not change audio',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await AutoScroll.instance.set(true);
      final duration = await pumpReader(tester, classic: classic);
      final controller = readerScroll(tester);
      await toggleAutoScroll(tester);
      await tester.pump(duration ~/ 4);
      await pauseAutoScroll(tester);
      final before = controller.offset;
      await chooseScrollSpeed(tester, const ValueKey('hymn-scroll-faster'));
      expect(find.byTooltip('Auto-scroll: 1.1×'), findsOneWidget);
      expect(controller.offset, before);
      await toggleAutoScroll(tester);
      await tester.pump(duration ~/ 4);
      expect(controller.offset / controller.position.maxScrollExtent,
          closeTo(0.525, 0.001));
      await pauseAutoScroll(tester);
      await chooseScrollSpeed(tester, const ValueKey('hymn-scroll-slower'));
      await chooseScrollSpeed(tester, const ValueKey('hymn-scroll-slower'));
      expect(find.byTooltip('Auto-scroll: 0.9×'), findsOneWidget);
      await toggleAutoScroll(tester);
      await tester.pump(duration ~/ 4);
      expect(controller.offset / controller.position.maxScrollExtent,
          closeTo(0.75, 0.001));
      await pauseAutoScroll(tester);
      final paused = controller.offset;
      for (var i = 0; i < 4; i++) {
        await chooseScrollSpeed(tester, const ValueKey('hymn-scroll-slower'));
      }
      expect(find.byTooltip('Auto-scroll: 0.5×'), findsOneWidget);
      expect(tester.widget<HymnAutoScrollControl>(scrollToggle).speed, 0.5);
      for (var i = 0; i < 15; i++) {
        await chooseScrollSpeed(tester, const ValueKey('hymn-scroll-faster'));
      }
      expect(find.byTooltip('Auto-scroll: 2.0×'), findsOneWidget);
      expect(tester.widget<HymnAutoScrollControl>(scrollToggle).speed, 2.0);
      await chooseScrollSpeed(
          tester, const ValueKey('hymn-scroll-speed-reset'));
      expect(find.byTooltip('Auto-scroll: 1.0×'), findsOneWidget);
      expect(controller.offset, paused);
      expect(MidiPlayer.instance.speed.value, 1);
      expect(MidiPlayer.instance.current.value, isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'scroll-speed changes during music anchor at the reading '
      'position and slower reading finishes after the music', (tester) async {
    await AutoScroll.instance.set(true);
    final duration = await pumpReader(tester);
    final player = MidiPlayer.instance;
    final controller = readerScroll(tester);
    player.current.value = (version: 'new', n: 534, paused: false);
    player.duration.value = duration;
    player.position.value = duration ~/ 4;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await pauseAutoScroll(tester);
    final atQuarter = controller.offset;
    await chooseScrollSpeed(tester, const ValueKey('hymn-scroll-slower'));
    expect(controller.offset, atQuarter);
    expect(player.speed.value, 1);
    expect(player.position.value, duration ~/ 4);
    await toggleAutoScroll(tester);
    player.position.value = duration ~/ 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.475, 0.001));
    player.current.value = (version: 'new', n: 534, paused: true);
    await tester.pump();
    await tester.pump(duration ~/ 4);
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.475, 0.001));
    player.current.value = (version: 'new', n: 534, paused: false);
    player.position.value = duration;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.925, 0.001));
    player.current.value = null;
    player.position.value = Duration.zero;
    player.duration.value = Duration.zero;
    await tester.pump();
    await tester.pump(duration ~/ 4);
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    expect(player.current.value, isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual dragging re-anchors and auto-scroll continues',
      (tester) async {
    await AutoScroll.instance.set(true);
    final duration = await pumpReader(tester);
    await toggleAutoScroll(tester);
    await tester.pump(duration ~/ 4);
    final controller = readerScroll(tester);
    final beforeTouches =
        controller.offset / controller.position.maxScrollExtent;
    for (var i = 0; i < 4; i++) {
      await tester.tap(lyricsScroll);
      await tester.pump();
    }
    await tester.pump(duration ~/ 10);
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(beforeTouches + 0.1, 0.001),
        reason: 'Repeated touches on the lyrics must never pause auto-scroll');
    final beforeDrag = controller.offset / controller.position.maxScrollExtent;
    await tester.drag(lyricsScroll, const Offset(0, -150));
    await tester.pump();
    final fraction = controller.offset / controller.position.maxScrollExtent;
    expect(fraction, greaterThan(beforeDrag));
    await tester.pump(duration ~/ 4);
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(fraction + 0.25, 0.001));

    final beforeSecondDrag =
        controller.offset / controller.position.maxScrollExtent;
    await tester.drag(lyricsScroll, const Offset(0, 100));
    await tester.pump();
    final adjusted = controller.offset / controller.position.maxScrollExtent;
    expect(adjusted, lessThan(beforeSecondDrag));
    await tester.pump(duration ~/ 10);
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(adjusted + 0.1, 0.001),
        reason: 'Auto-scroll continues from either manual adjustment');

    // Repeated adjustments can momentarily land at the end. That must not
    // clear the user's active auto-scroll intent if they then move upward.
    await tester.drag(lyricsScroll, const Offset(0, -10000));
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);
    await tester.drag(lyricsScroll, const Offset(0, 180));
    await tester.pump();
    final afterLeavingEnd =
        controller.offset / controller.position.maxScrollExtent;
    expect(afterLeavingEnd, lessThan(1));
    await tester.pump(duration ~/ 10);
    final afterResume = controller.offset / controller.position.maxScrollExtent;
    expect(afterResume, greaterThan(afterLeavingEnd));
    expect(afterResume, closeTo((afterLeavingEnd + 0.1).clamp(0, 1), 0.001),
        reason: 'Touching the bottom must not disable later adjustments');
    await AutoScroll.instance.set(false);
    await tester.pump();
    expect(scrollToggle, findsNothing);
    final stopped = controller.offset;
    await tester.pump(duration);
    expect(controller.offset, stopped);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('music timeline drives scrolling, pause, seeking and completion',
      (tester) async {
    await AutoScroll.instance.set(true);
    await pumpReader(tester);
    final player = MidiPlayer.instance;
    player.current.value = (version: 'new', n: 534, paused: false);
    player.duration.value = const Duration(seconds: 100);
    player.position.value = const Duration(seconds: 25);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final controller = readerScroll(tester);
    expect(scrollToggle, findsOneWidget,
        reason: 'The compact speed pill does not add a separate control row');
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.25, 0.001));
    player.current.value = (version: 'new', n: 534, paused: true);
    await tester.pump(const Duration(seconds: 10));
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.25, 0.001));
    // Native seek/poll notifications update this same player timeline.
    player.position.value = const Duration(seconds: 35);
    await tester.pump();
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.35, 0.001));
    player.current.value = (version: 'new', n: 534, paused: false);
    player.position.value = const Duration(seconds: 10);
    await tester.pump();
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.1, 0.001));
    player.position.value = player.duration.value;
    player.current.value = null;
    player.position.value = Duration.zero;
    player.duration.value = Duration.zero;
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);
    await tester.pump(const Duration(seconds: 20));
    expect(controller.offset, controller.position.maxScrollExtent);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout changes preserve progress and backgrounding pauses it',
      (tester) async {
    await AutoScroll.instance.set(true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final duration = await pumpReader(tester);
    await toggleAutoScroll(tester);
    await tester.pump(duration ~/ 4);
    final controller = readerScroll(tester);
    final before = controller.position.maxScrollExtent;
    await FontSizeController.instance.set(28);
    await tester.pump();
    await tester.pump();
    expect(controller.position.maxScrollExtent, greaterThan(before));
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.25, 0.001));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final paused = controller.offset;
    await tester.pump(duration);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.offset, paused);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Old Hymnal keeps repeated choruses and can auto-scroll',
      (tester) async {
    await AutoScroll.instance.set(true);
    final duration = await pumpReader(tester, version: 'old', number: 533);
    final body = tester.widget<Html>(find.byType(Html)).data!;
    expect('CHORUS</span>'.allMatches(body), hasLength(4));
    expect(duration, greaterThan(Duration.zero));
    expect(scrollToggle, findsOneWidget);
    await toggleAutoScroll(tester);
    await tester.pump(duration ~/ 4);
    final controller = readerScroll(tester);
    expect(controller.offset / controller.position.maxScrollExtent,
        closeTo(0.325, 0.001),
        reason: 'Old Hymnal defaults to the faster 1.3× reading pace');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hymn that fits cannot start an unnecessary scroll timer',
      (tester) async {
    await AutoScroll.instance.set(true);
    await pumpReader(tester, number: 694);
    expect(readerScroll(tester).position.maxScrollExtent, 0);
    expect(
        tester.widget<HymnAutoScrollControl>(scrollToggle).canToggle, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opening another page pauses; the next hymn starts at the top',
      (tester) async {
    await AutoScroll.instance.set(true);
    final duration = await pumpReader(tester);
    await toggleAutoScroll(tester);
    await tester.pump(duration ~/ 4);
    final controller = readerScroll(tester);
    await chooseReaderOption(tester, const ValueKey('hymn-font-size-button'));
    await tester.pumpAndSettle();
    final offset = controller.offset;
    await tester.pump(duration);
    expect(controller.offset, offset);
    Navigator.of(tester.element(find.byType(FontSizer))).pop();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
    await tester.drag(lyricsScroll, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.number, 535);
    expect(readerScroll(tester).offset, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('Modern is the default and invalid values fall back safely', () async {
    expect(AppDesignController.instance.value, AppDesign.modern);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appDesign', 'obsolete');
    await AppDesignController.instance.load();
    expect(AppDesignController.instance.value, AppDesign.modern);
  });

  test('design persists without changing brightness, music or saved hymns',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await ThemeController.instance.setPref('dark');
    await prefs.setString('midiTheme', 'reggae');
    await Favorites.instance.toggle(hymns.first);
    await FontSizeController.instance.set(25);
    await AppDesignController.instance.set(AppDesign.classic);
    AppDesignController.instance.value = AppDesign.modern;
    await AppDesignController.instance.load();
    expect(AppDesignController.instance.value, AppDesign.classic);
    expect(prefs.getString('theme'), 'dark');
    expect(prefs.getString('midiTheme'), 'reggae');
    expect(prefs.getDouble('fontSize'), 25);
    expect(Favorites.instance.contains(hymns.first.number, hymns.first.version),
        isTrue);
    await AppDesignController.instance.set(AppDesign.modern);
    expect(prefs.getString('appDesign'), 'modern');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
        DefaultAssetBundle(bundle: _HymnAssets(), child: const Hymnal()));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final size in [const Size(375, 812), const Size(568, 320)]) {
    testWidgets('all musical styles remain reachable on $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: const Scaffold(body: Settings()),
      ));
      await tester.scrollUntilVisible(find.text('Musical style'), 150,
          scrollable: find.byType(Scrollable));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Musical style'));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('musical-style-list'));
      final scrollable =
          find.descendant(of: list, matching: find.byType(Scrollable));
      for (final theme in InstrumentTheme.themes) {
        final row = find.descendant(of: list, matching: find.text(theme.$2));
        await tester.scrollUntilVisible(row, 100, scrollable: scrollable);
        expect(row.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester
          .tap(find.descendant(of: list, matching: find.text('Music Box')));
      await tester.pumpAndSettle();
      expect(InstrumentTheme.instance.value, 'musicbox');
      expect(list, findsNothing);
      final ids = InstrumentTheme.themes.map((e) => e.$1).toList();
      expect(ids.indexOf('jamaican_gospel'), ids.indexOf('reggae') + 1);
    });
  }

  testWidgets('song menu changes musical style and toggles choir practice',
      (tester) async {
    await MusicOptions.instance.load();
    final list = hymns.where((h) => h.version == 'new').toList();
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light),
      home: HymnPage(hymn: hymnByNumber(list, 108)!, hymns: list),
    ));
    await chooseReaderOption(tester, const ValueKey('hymn-musical-style'));
    final listFinder = find.byKey(const ValueKey('musical-style-list'));
    expect(listFinder, findsOneWidget);
    await tester.tap(find.descendant(
        of: listFinder, matching: find.text('Jamaican Gospel')));
    await tester.pumpAndSettle();
    expect(InstrumentTheme.instance.value, 'jamaican_gospel');
    for (final enabled in [true, false]) {
      await chooseReaderOption(tester, const ValueKey('hymn-choir-practice'));
      expect(MusicOptions.instance.choirPractice, enabled);
      expect((await SharedPreferences.getInstance()).getBool('choirPractice'),
          enabled);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Reading settings toggle auto-scroll in both app designs',
      (tester) async {
    for (final design in AppDesign.values) {
      AppDesignController.instance.value = design;
      await pumpApp(tester);
      await tester.tap(find.text('Settings'));
      await tester.pump();
      await tester.ensureVisible(find.text('Auto-scroll'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Auto-scroll'));
      await tester.pump();
      expect(AutoScroll.instance.value, isTrue);
      expect((await SharedPreferences.getInstance()).getBool('autoScroll'),
          isTrue);
      await tester.tap(find.text('Auto-scroll'));
      await tester.pump();
      expect(AutoScroll.instance.value, isFalse);
      await tester.pumpWidget(const SizedBox());
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switches both ways, keeps number input and search',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('5'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.text('533'), findsOneWidget);
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'cross');
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('design-classic')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('settings-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('design-classic'))),
        alignment: .5);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('design-classic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClassicHeader), findsOneWidget);
    await tester.scrollUntilVisible(find.text('App design'), -100,
        scrollable: find.descendant(
            of: find.byKey(const ValueKey('settings-list')),
            matching: find.byType(Scrollable)));
    expect(find.text('App design'), findsOneWidget);
    await tester.tap(find.text('Numbers'));
    await tester.pump();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('classic-number-display')))
            .data,
        '533');
    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'cross');
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('design-modern'))),
        alignment: .5);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('design-modern')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClassicHeader), findsNothing);
    await tester.scrollUntilVisible(find.text('App design'), -100,
        scrollable: find.descendant(
            of: find.byKey(const ValueKey('settings-list')),
            matching: find.byType(Scrollable)));
    expect(find.text('App design'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon failure shows retry without discarding the Classic layout',
      (tester) async {
    await pumpApp(tester);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('sdahymnal/app_icon'),
        (_) async => throw PlatformException(code: 'ICON_CHANGE_FAILED'));
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('design-classic')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('settings-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('design-classic'))),
        alignment: .5);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('design-classic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ClassicHeader), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-app-icon')), findsOneWidget);
    messenger.setMockMethodCallHandler(
        const MethodChannel('sdahymnal/app_icon'), (_) async => null);
    await tester.tap(find.byKey(const ValueKey('retry-app-icon')));
    await tester.pump();
    expect(find.byKey(const ValueKey('retry-app-icon')), findsNothing);
    expect(AppDesignController.instance.value, AppDesign.classic);
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup and resume reconcile an existing Classic preference',
      (tester) async {
    SharedPreferences.setMockInitialValues({'appDesign': 'classic'});
    await AppDesignController.instance.load();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('sdahymnal/app_icon'),
            (call) async {
      calls.add(call.arguments as String);
      return null;
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpApp(tester);
    expect(calls, ['classic']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, ['classic', 'classic']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Classic keypad validates bounds and opens the right edition',
      (tester) async {
    await AppDesignController.instance.set(AppDesign.classic);
    await pumpApp(tester);
    OutlinedButton newButton() => tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'NEW»'));
    expect(newButton().onPressed, isNull);
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(newButton().onPressed, isNull);
    for (final digit in ['7', '0', '3']) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();
    expect(newButton().onPressed, isNull);
    await tester.tap(find.text('OLD»'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.number, 703);
    expect(tester.widget<HymnPage>(find.byType(HymnPage)).hymn.version, 'old');
    expect(find.byKey(const ValueKey('hymn-reader-options')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Classic filter cycles and retains the typed query',
      (tester) async {
    await AppDesignController.instance.set(AppDesign.classic);
    await pumpApp(tester);
    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '533');
    await tester.pump();
    expect(find.byType(ClassicSearchRow), findsNWidgets(2));
    await tester.tap(find.text('ALL\nHymns'));
    await tester.pump();
    expect(find.text('533. On a Hill Far Away'), findsOneWidget);
    await tester.tap(find.text('OLD\nHymns'));
    await tester.pump();
    expect(find.text('533. O for a Faith'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '533');
  });

  testWidgets('Classic swipes through corrected Old 533 534 and 535 in order',
      (tester) async {
    final list = hymns.where((h) => h.version == 'old').toList();
    await tester.pumpWidget(MaterialApp(
      theme: buildHymnalTheme(HymnalTokens.light, classic: true),
      home: HymnPage(hymn: hymnByNumber(list, 533)!, hymns: list),
    ));
    await tester.pump();
    for (final number in [534, 535]) {
      await tester.drag(find.byType(HymnPage), const Offset(-250, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final page = tester.widget<HymnPage>(find.byType(HymnPage));
      expect(page.hymn.number, number);
      expect(page.hymn.version, 'old');
      expect(find.byKey(const ValueKey('hymn-play-pause')), findsOneWidget);
    }
    expect(Recents.instance.value.first, (n: 535, v: 'old'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final classic in [false, true]) {
    testWidgets(
        'End-of-hymn nudge and favorite splash in ${classic ? 'Classic' : 'Modern'}',
        (tester) async {
      final list = hymns.where((h) => h.version == 'new').toList();
      final hymn = hymnByNumber(list, 533)!;
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
        home: HymnPage(hymn: hymn, hymns: list),
      ));
      await tester.pump();
      final burst = find.byType(FavoriteBurst);
      Icon heart() => tester.widget<Icon>(
          find.descendant(of: burst, matching: find.byType(Icon)));
      final normal = heart().color!;
      final scroll = readerScroll(tester);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(heart().color!.r, greaterThan(heart().color!.g));
      expect(Favorites.instance.contains(hymn.number, hymn.version), isFalse);
      await tester.pump(const Duration(milliseconds: 800));
      expect(heart().color, normal);
      expect(heart().icon, Icons.favorite_border);

      // Reaching the bottom again must not repeatedly nag the reader.
      scroll.jumpTo(0);
      await tester.pump();
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(heart().color, normal);

      await tester
          .tap(find.byKey(const ValueKey('hymn-favorite-header-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(heart().color!.g, greaterThan(heart().color!.r));
      expect(Favorites.instance.contains(hymn.number, hymn.version), isTrue);
      await tester.pump(const Duration(milliseconds: 800));
      expect(heart().icon, Icons.favorite);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Saved hymns do not show the red reminder in ${classic ? 'Classic' : 'Modern'}',
        (tester) async {
      final list = hymns.where((h) => h.version == 'new').toList();
      final hymn = hymnByNumber(list, 533)!;
      await Favorites.instance.toggle(hymn);
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light, classic: classic),
        home: HymnPage(hymn: hymn, hymns: list),
      ));
      await tester.pump();
      final scroll = readerScroll(tester);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final heart = tester.widget<Icon>(find.descendant(
          of: find.byType(FavoriteBurst), matching: find.byType(Icon)));
      expect(heart.color!.g, greaterThan(heart.color!.r));
      expect(heart.icon, Icons.favorite);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
        'Classic reader and music controls fit narrow ${dark ? 'dark' : 'light'} screens',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final list = hymns.where((h) => h.version == 'new').toList();
      final hymn = hymnByNumber(list, 533)!;
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(dark ? HymnalTokens.dark : HymnalTokens.light,
            classic: true),
        home: HymnPage(hymn: hymn, hymns: list),
      ));
      await tester.pump();
      expect(
          find.byKey(const ValueKey('classic-reader-header')), findsOneWidget);
      expect(find.byKey(const ValueKey('hymn-reader-options')), findsOneWidget);
      expect(musicPlayer, findsOneWidget);
      expect(MidiPlayer.hasMidi(hymn), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
