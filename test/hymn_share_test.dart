import 'package:flutter/material.dart';
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
  for (final classic in [false, true]) {
    testWidgets('copy selected verse and share sheet anchor classic=$classic',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      MethodCall? shared;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'), (call) async {
        shared = call;
        return 'dev.fluttercommunity.plus/share/dismissed';
      });
      await tester.pumpWidget(MaterialApp(
        theme: buildHymnalTheme(
            classic ? HymnalTokens.classic(true) : HymnalTokens.dark,
            classic: classic),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!),
        home: HymnSharePage(hymn: hymn),
      ));
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, contains('388 · Señor\nEspañol 2009'));
      expect(copied, contains('Primera línea'));
      expect(copied, contains('Segunda línea'));
      await tester.tap(find.byKey(const ValueKey('share-lyric-section')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verse 2').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, endsWith('2\nSegunda línea'));
      expect(copied, isNot(contains('Primera línea')));
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(shared?.method, 'share');
      expect(shared?.arguments['text'], copied);
      expect(shared?.arguments['originWidth'], greaterThan(0));
      expect(shared?.arguments['originHeight'], greaterThan(0));
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (_) async => throw PlatformException(code: 'unavailable'));
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(
          find.text('Could not open sharing. You can copy the lyrics instead.'),
          findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, endsWith('2\nSegunda línea'));
      expect(tester.takeException(), isNull);
    });
  }
}
