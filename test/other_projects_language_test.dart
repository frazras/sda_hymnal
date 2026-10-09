import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/sp.dart';

class _ProjectAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => File(key).existsSync()
      ? SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()))
      : rootBundle.load(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'other projects translation fits compact screens and keeps destination',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final urls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      if (call.method == 'launch') {
        urls.add((call.arguments as Map)['url'] as String);
        return true;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), null));
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: buildHymnalTheme(
                  dark ? HymnalTokens.dark : HymnalTokens.light,
                  classic: classic),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(1.3)),
                  child: child!),
              home: DefaultAssetBundle(
                  bundle: _ProjectAssets(), child: const Sp())));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          final text = tester.element(find.byType(Sp)).appText;
          expect(find.text(text.otherProjects), findsOneWidget);
          expect(find.text(text.sabbathProgramsDescription), findsOneWidget);
          expect(find.text('SabbathPrograms.com'), findsOneWidget);
          expect(
              tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
          await tester.scrollUntilVisible(find.text(text.visitWebsite), 200,
              scrollable: find.byType(Scrollable), maxScrolls: 100);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.visitWebsite));
          await tester.pumpAndSettle();
          expect(urls.last, 'https://sabbathprograms.com/weekly');
          expect(find.text('sabbathprograms.com/weekly'), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
    expect(urls, hasLength(16));
  });
}
