import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymn_share.dart';

void main() {
  final hymn = Hymn(
      number: 388,
      title: 'Señor',
      version: 'sda-es-2009',
      languageTag: 'es',
      bookTitle: 'Español 2009',
      body:
          '1<br>Primera línea<br><br>Coro:<br>Gloria<br><br>2<br>Segunda línea');
  for (final locale in AppLocalizations.supportedLocales) {
    for (final classic in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
            'copy selected verse and share sheet anchor locale=${locale.languageCode} classic=$classic dark=$dark',
            (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          String? copied;
          MethodCall? shared;
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform,
              (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = call.arguments['text'] as String;
            }
            return null;
          });
          messenger.setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/share'),
              (call) async {
            shared = call;
            return 'dev.fluttercommunity.plus/share/dismissed';
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(SystemChannels.platform, null);
            messenger.setMockMethodCallHandler(
                const MethodChannel('dev.fluttercommunity.plus/share'), null);
          });
          await tester.pumpWidget(MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildHymnalTheme(
                dark ? HymnalTokens.dark : HymnalTokens.light,
                classic: classic),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!),
            home: HymnSharePage(hymn: hymn),
          ));
          await tester.pumpAndSettle();
          final text = tester.element(find.byType(HymnSharePage)).appText;
          expect(find.text(text.copyOrShareLyrics), findsOneWidget);
          await tester.tap(find.text(text.copyControl));
          await tester.pump();
          expect(copied, contains('388 · Señor\nEspañol 2009'));
          expect(copied, contains('Primera línea'));
          expect(copied, contains('Segunda línea'));
          await tester.tap(find.byKey(const ValueKey('share-lyric-section')));
          await tester.pumpAndSettle();
          expect(find.text('Coro:'), findsOneWidget);
          await tester.tap(find.text(text.lyricVerse('2')).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.copyControl));
          await tester.pump();
          expect(copied, endsWith('2\nSegunda línea'));
          expect(copied, isNot(contains('Primera línea')));
          await tester.tap(find.text(text.shareControl));
          await tester.pumpAndSettle();
          expect(shared?.method, 'share');
          expect(shared?.arguments['text'], copied);
          expect(shared?.arguments['subject'], '388 · Señor');
          expect(shared?.arguments['originWidth'], greaterThan(0));
          expect(shared?.arguments['originHeight'], greaterThan(0));
          messenger.setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/share'),
              (_) async => throw PlatformException(code: 'unavailable'));
          await tester.tap(find.text(text.shareControl));
          await tester.pumpAndSettle();
          expect(find.text(text.shareLyricsFailed), findsOneWidget);
          await tester.tap(find.text(text.copyControl));
          await tester.pump();
          expect(copied, endsWith('2\nSegunda línea'));
          messenger.setMockMethodCallHandler(SystemChannels.platform,
              (call) async {
            if (call.method == 'Clipboard.setData') {
              throw PlatformException(code: 'unavailable');
            }
            return null;
          });
          await tester.tap(find.text(text.copyControl));
          await tester.pumpAndSettle();
          expect(find.text(text.copyLyricsFailed), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
      'generated section labels translate without changing source preview',
      (tester) async {
    final unnumbered = Hymn(
        number: 1,
        version: 'sda-es-2009',
        languageTag: 'es',
        bookTitle: 'Español 2009',
        title: 'Sin números',
        body: 'Primera línea<br>Otra línea<br><br>Última línea');
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: HymnSharePage(hymn: unnumbered)));
      await tester.pumpAndSettle();
      final text = tester.element(find.byType(HymnSharePage)).appText;
      expect(find.text(text.fullHymn), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-lyric-section')));
      await tester.pumpAndSettle();
      expect(find.text(text.lyricSection(1)), findsOneWidget);
      await tester.tap(find.text(text.lyricSection(2)).last);
      await tester.pumpAndSettle();
      final preview = tester
          .widget<SelectableText>(
              find.byKey(const ValueKey('share-lyric-preview')))
          .data!;
      expect(preview, '1 · Sin números\nEspañol 2009\n\nÚltima línea');
      expect(tester.takeException(), isNull);
    }
  });
}
