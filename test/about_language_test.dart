import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/services/analytics_endpoint.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/about.dart';

class _AboutAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => File(key).existsSync()
      ? SynchronousFuture(ByteData.sublistView(File(key).readAsBytesSync()))
      : rootBundle.load(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'translated about page keeps contact links and fits compact layouts',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final launches = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      if (call.method == 'launch') {
        launches.add((call.arguments as Map)['url'] as String);
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
                bundle: _AboutAssets(), child: const About()),
          ));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(About));
          final text = context.appText;
          expect(find.text(text.aboutUs), findsOneWidget);
          expect(find.text('Rohan A. Smith'), findsOneWidget);
          expect(find.text(text.developerBio), findsOneWidget);
          for (final (label, url) in [
            ('@frazras', 'https://twitter.com/frazras'),
            ('rohan@exterbox.com', 'mailto:rohan@exterbox.com'),
            (text.privacyPolicy, '$analyticsEndpoint/privacy-policy'),
          ]) {
            await tester.scrollUntilVisible(find.text(label), 150,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
            expect(launches.last, url);
          }
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
  });
}
