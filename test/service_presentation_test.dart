import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sdahymnal/ui/service_presentation.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/service_playlist.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/services/service_presentation.dart';

void main() {
  final hymn = Hymn(
      number: 1,
      title: 'Corazón <script>',
      body: '<b>1</b><br>Ábreme<br>Señor<br><br><b>Coro</b><br>Gloria',
      version: 'sda-es-2009',
      languageTag: 'es');
  const reading = AdditionalReading(
      id: 'reading',
      edition: 'sda-es-2009',
      order: 1,
      number: 2,
      title: 'Lectura',
      category: '',
      segments: [
        ReadingSegment(role: 'leader', text: 'Primera\nSegunda'),
        ReadingSegment(role: 'congregation', text: 'Amén')
      ]);
  final repository = HymnalRepository(editions: const [
    HymnalEdition(
        id: 'sda-es-2009',
        languageTag: 'es',
        displayName: 'Español',
        year: 2009)
  ], hymns: [
    hymn
  ], readings: [
    reading
  ]);
  final service =
      ServicePlaylist(id: 'service', name: 'Sábado & domingo', entries: [
    ServiceEntry(id: 'opening', ref: hymn.ref),
    ServiceEntry(id: 'reading', ref: reading.ref),
    ServiceEntry(id: 'closing', ref: hymn.ref),
  ]);
  test('keeps occurrence order, source refrain once and reading roles', () {
    final deck =
        ServicePresentation.build(service, repository, linesPerSlide: 2);
    expect(deck.slides.map((s) => s.occurrenceId).toSet().toList(),
        ['opening', 'reading', 'closing']);
    expect(
        deck.slides
            .where((s) => s.occurrenceId == 'opening')
            .map((s) => s.text)
            .join('\n'),
        '1\nÁbreme\nSeñor\nCoro\nGloria');
    expect(
        deck.slides
            .where((s) => s.occurrenceId == 'reading')
            .map((s) => s.role),
        ['leader', 'congregation']);
    expect(deck.slides.first.ref, hymn.ref);
    expect(() => deck.slides.clear(), throwsUnsupportedError);
  });
  test('VideoPsalm songbook preserves occurrences, Unicode and reading roles',
      () {
    final deck =
        ServicePresentation.build(service, repository, linesPerSlide: 2);
    final encoded = deck.videoPsalmSongbook(
        roleLabel: (role) => role == 'leader' ? 'Dirigente' : 'Congregación');
    final book = jsonDecode(encoded) as Map<String, dynamic>;
    final songs = book['Songs'] as List<dynamic>;
    expect(book['Text'], service.name);
    expect(songs.map((song) => song['ID']), [1, 2, 3]);
    expect(songs.map((song) => song['Text']),
        ['1 · Corazón <script>', '2 · Lectura', '1 · Corazón <script>']);
    expect(songs.map((song) => song['Guid']).toSet().length, 3);
    expect(base64.decode('${book['Guid']}==').length, 16);
    expect((songs[0]['Verses'] as List).map((v) => v['Text']).join('\n'),
        '1\nÁbreme\nSeñor\nCoro\nGloria');
    expect((songs[1]['Verses'] as List).map((v) => v['Text']),
        ['Dirigente\nPrimera\nSegunda', 'Congregación\nAmén']);
    expect(deck.slides.where((s) => s.role != null).map((s) => s.role),
        ['leader', 'congregation']);
    expect(deck.videoPsalmSongbook(), deck.videoPsalmSongbook());
  });
  test('HTML translates reading roles without mutating source roles or text',
      () {
    final presentation = ServicePresentation.build(service, repository);
    final html = presentation.html(
        previousLabel: 'Anterior',
        nextLabel: 'Siguiente',
        roleLabel: (role) => role == 'leader' ? 'Dirigente' : 'Congregación');
    expect(html, contains('Español · Dirigente'));
    expect(html, contains('Español · Congregación'));
    expect(html, contains('Amén'));
    expect(presentation.slides.where((s) => s.role != null).map((s) => s.role),
        ['leader', 'congregation']);
  });
  test('HTML escapes source and controls and remains self contained', () {
    final html = ServicePresentation.build(service, repository)
        .html(previousLabel: '<Back>', nextLabel: 'Next & more');
    expect(html, contains('Corazón &lt;script&gt;'));
    expect(html, contains('Sábado &amp; domingo'));
    expect(html, contains('&lt;Back&gt;'));
    expect(html, isNot(contains('<script>Corazón')));
    expect(html, isNot(contains('src=')));
    expect(html, contains('Ábreme'));
  });
  test(
      'missing entries and empty services fail instead of silently omitting content',
      () {
    expect(
        () => ServicePresentation.build(
            ServicePlaylist(id: 'empty', name: 'Empty'), repository),
        throwsFormatException);
    final missing =
        Hymn(number: 99, title: 'Missing', body: '', version: 'sda-es-2009');
    expect(
        () => ServicePresentation.build(
            ServicePlaylist(
                id: 'missing',
                name: 'Missing',
                entries: [ServiceEntry(id: 'x', ref: missing.ref)]),
            repository),
        throwsFormatException);
    expect(
        () => ServicePresentation.build(service, repository, linesPerSlide: 0),
        throwsArgumentError);
  });
  testWidgets(
      'Spanish preview uses translated role labels and unchanged reading text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: ServicePresentationPage(
            presentation: ServicePresentation.build(service, repository))));
    await tester.pumpAndSettle();
    final text = tester.element(find.byType(ServicePresentationPage)).appText;
    await tester.tap(find.byTooltip(text.nextItem));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(text.nextItem));
    await tester.pumpAndSettle();
    expect(find.text('Español · Dirigente'), findsOneWidget);
    expect(find.text('Primera\nSegunda'), findsOneWidget);
    await tester.tap(find.byTooltip(text.nextItem));
    await tester.pumpAndSettle();
    expect(find.text('Español · Congregación'), findsOneWidget);
    expect(find.text('Amén'), findsOneWidget);
  });
  testWidgets(
      'share sends a real UTF-8 HTML file with its filename and popover origin',
      (tester) async {
    final directory =
        Directory.systemTemp.createTempSync('presentation-share-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    messenger.setMockMethodCallHandler(
        pathChannel, (_) async => directory.path);
    final shared = Completer<void>();
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      expect(call.method, 'share');
      final args = call.arguments as Map;
      final path = (args['paths'] as List).single as String;
      expect(path, endsWith('/service-slides.html'));
      expect(args['mimeTypes'], ['text/html']);
      expect(args['originWidth'], greaterThan(0));
      expect(File(path).readAsStringSync(), contains('Corazón &lt;script&gt;'));
      shared.complete();
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
    });
    await tester.pumpWidget(MaterialApp(
        home: ServicePresentationPage(
            presentation: ServicePresentation.build(service, repository))));
    await tester.tap(find.byTooltip('Share HTML slides'));
    for (var i = 0; i < 30 && !shared.isCompleted; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(shared.isCompleted, isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test('an empty reading segment fails instead of dropping part of a reading',
      () {
    const incomplete = AdditionalReading(
        id: 'incomplete',
        edition: 'sda-es-2009',
        order: 2,
        number: 3,
        title: 'Incomplete',
        category: '',
        segments: [
          ReadingSegment(role: 'leader', text: 'Present'),
          ReadingSegment(role: 'congregation', text: '  ')
        ]);
    final repo = HymnalRepository(
        editions: repository.editions, hymns: [hymn], readings: [incomplete]);
    final list = ServicePlaylist(
        id: 'incomplete',
        name: 'Incomplete',
        entries: [ServiceEntry(id: 'reading', ref: incomplete.ref)]);
    expect(() => ServicePresentation.build(list, repo), throwsFormatException);
  });
  for (final classic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          'long slide remains scrollable with large text classic=$classic dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final longHymn = Hymn(
            number: 4,
            title: 'Una canción con un título muy largo',
            body: List.filled(6,
                    'Esta línea tiene muchas palabras para probar cómo se presenta el texto sin perder ninguna palabra.')
                .join('<br>'),
            version: 'sda-es-2009',
            languageTag: 'es');
        final repo =
            HymnalRepository(editions: repository.editions, hymns: [longHymn]);
        final list = ServicePlaylist(
            id: 'long',
            name: 'Servicio de adoración',
            entries: [ServiceEntry(id: 'long', ref: longHymn.ref)]);
        await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(dark ? HymnalTokens.dark : HymnalTokens.light,
              classic: classic),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(4)),
              child: child!),
          home: ServicePresentationPage(
              presentation: ServicePresentation.build(list, repo)),
        ));
        await tester.pumpAndSettle();
        final scrollable =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        await tester.drag(
            find.byType(SingleChildScrollView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(scrollable.position.pixels, greaterThan(0));
        expect(find.text('1 / 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
