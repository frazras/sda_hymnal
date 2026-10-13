import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/hymn_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Hymn hymn(String language) => Hymn(
      number: 1,
      title: 'ترنيمة الرجاء',
      body: '<p>يا رب أعطني السلام</p>',
      version: 'sda-ar-example',
      languageTag: language,
      bookTitle: 'ترانيم',
      credits: 'كلمات الترنيمة');
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await KeepScreenOn.instance.set(false);
    MusicPlayerVisible.instance.value = false;
  });

  test('book direction respects language and explicit script', () {
    for (final tag in ['ar', 'ar-EG', 'he', 'fa', 'ur', 'az-Arab']) {
      expect(hymn(tag).isRightToLeft, isTrue, reason: tag);
    }
    for (final tag in ['en', 'es', 'ru', 'ar-Latn', 'az-Latn']) {
      expect(hymn(tag).isRightToLeft, isFalse, reason: tag);
    }
  });

  for (final classic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          'RTL lyrics render independently of English controls classic=$classic dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = hymn('ar');
        await tester.pumpWidget(MaterialApp(
          theme: buildHymnalTheme(dark ? HymnalTokens.dark : HymnalTokens.light,
              classic: classic),
          home: HymnPage(hymn: item, hymns: [item]),
        ));
        await tester.pumpAndSettle();
        final content = find.byKey(const ValueKey('hymn-content-direction'));
        expect(tester.widget<Directionality>(content).textDirection,
            TextDirection.rtl);
        final paragraphs = find
            .descendant(of: content, matching: find.byType(RichText))
            .evaluate()
            .map((e) => e.renderObject)
            .whereType<RenderParagraph>()
            .where((p) => p.text.toPlainText().contains('يا رب'))
            .toList();
        expect(paragraphs, isNotEmpty);
        expect(paragraphs.every((p) => p.textDirection == TextDirection.rtl),
            isTrue);
        expect(
            Directionality.of(tester
                .element(find.byKey(const ValueKey('hymn-reader-options')))),
            TextDirection.ltr);
        expect(find.byKey(const ValueKey('reader-next')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('share preview uses book direction without changing interface',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: HymnSharePage(hymn: hymn('ar'))));
    await tester.pumpAndSettle();
    final text = tester.widget<SelectableText>(
        find.byKey(const ValueKey('share-lyric-preview')));
    expect(text.textDirection, TextDirection.rtl);
    expect(Directionality.of(tester.element(find.text('Copy'))),
        TextDirection.ltr);
    expect(tester.takeException(), isNull);
  });
}
