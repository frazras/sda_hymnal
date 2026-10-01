import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/ui/hymn_page_turn.dart';

void main() {
  test('touch regions use the requested 35/30/35 split', () {
    expect(pageTurnRegion(0, 1000), PageTurnRegion.top);
    expect(pageTurnRegion(349, 1000), PageTurnRegion.top);
    expect(pageTurnRegion(350, 1000), PageTurnRegion.middle);
    expect(pageTurnRegion(649, 1000), PageTurnRegion.middle);
    expect(pageTurnRegion(650, 1000), PageTurnRegion.bottom);
    expect(pageTurnRegion(999, 1000), PageTurnRegion.bottom);
  });

  for (final region in PageTurnRegion.values) {
    testWidgets('gesture stays in its initial $region region', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: HymnPageTurn(
        onTurn: (_) {},
        previewBuilder: (_) => const ColoredBox(color: Colors.blue),
        child: const ColoredBox(color: Colors.white),
      )));
      final y = switch (region) {
        PageTurnRegion.top => 100.0,
        PageTurnRegion.middle => 300.0,
        PageTurnRegion.bottom => 500.0
      };
      final gesture = await tester.startGesture(Offset(600, y));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
      final clipper = tester
          .widget<ClipPath>(find.byKey(const ValueKey('hymn-page-fold')))
          .clipper! as PageCurlClipper;
      expect(clipper.region, region);
      final clip = clipper.getClip(const Size(800, 600));
      if (region == PageTurnRegion.top) {
        expect(clip.contains(const Offset(799, 1)), isFalse);
        expect(clip.contains(const Offset(799, 599)), isTrue);
      } else if (region == PageTurnRegion.bottom) {
        expect(clip.contains(const Offset(799, 599)), isFalse);
        expect(clip.contains(const Offset(799, 1)), isTrue);
      }
      await gesture.moveBy(const Offset(-20, 200));
      await tester.pump();
      expect(
          (tester
                  .widget<ClipPath>(
                      find.byKey(const ValueKey('hymn-page-fold')))
                  .clipper! as PageCurlClipper)
              .region,
          region);
      await gesture.cancel();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('rightward drag folds right and commits previous only on release',
      (tester) async {
    final turns = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: HymnPageTurn(
      onTurn: turns.add,
      previewBuilder: (dir) =>
          ColoredBox(color: Colors.blue, child: Text('Preview $dir')),
      child: const ColoredBox(
          color: Colors.white, child: Center(child: Text('Current'))),
    )));
    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(find.text('Preview -1'), findsOneWidget);
    expect(turns, isEmpty);
    final fold =
        tester.widget<ClipPath>(find.byKey(const ValueKey('hymn-page-fold')));
    final clip = fold.clipper!.getClip(const Size(800, 600));
    expect(clip.contains(const Offset(1, 599)), isFalse);
    expect(clip.contains(const Offset(799, 1)), isTrue);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(turns, [-1]);
  });

  testWidgets(
      'missing adjacent hymn cannot turn and pointer cancellation restores page',
      (tester) async {
    final turns = <int>[];
    await tester.pumpWidget(MaterialApp(
        home: HymnPageTurn(
      onTurn: turns.add,
      previewBuilder: (dir) =>
          dir < 0 ? null : const ColoredBox(color: Colors.blue),
      child: const ColoredBox(color: Colors.white),
    )));
    await tester.drag(find.byType(HymnPageTurn), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(turns, isEmpty);
    final gesture = await tester.startGesture(const Offset(500, 300));
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(turns, isEmpty);
    expect(
        tester
            .widget<ClipPath>(find.byKey(const ValueKey('hymn-page-fold')))
            .clipper!
            .getClip(const Size(800, 600))
            .getBounds(),
        const Rect.fromLTWH(0, 0, 800, 600));
  });

  testWidgets('moving the curl does not rebuild either painted page',
      (tester) async {
    var currentBuilds = 0;
    var previewBuilds = 0;
    await tester.pumpWidget(MaterialApp(
        home: HymnPageTurn(
      onTurn: (_) {},
      previewBuilder: (_) => Builder(builder: (_) {
        previewBuilds++;
        return const ColoredBox(color: Colors.blue);
      }),
      child: Builder(builder: (_) {
        currentBuilds++;
        return const ColoredBox(color: Colors.white);
      }),
    )));
    final gesture = await tester.startGesture(const Offset(500, 300));
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    final beforeCurrent = currentBuilds;
    final beforePreview = previewBuilds;
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset(i < 4 ? -15 : 15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(currentBuilds, beforeCurrent);
    expect(previewBuilds, beforePreview);
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('Reduce Motion uses a plain reveal without curled shading',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: HymnPageTurn(
          onTurn: (_) {},
          previewBuilder: (_) => const ColoredBox(color: Colors.blue),
          child: const ColoredBox(color: Colors.white)),
    )));
    final gesture = await tester.startGesture(const Offset(500, 300));
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump();
    final clipper = tester
        .widget<ClipPath>(find.byKey(const ValueKey('hymn-page-fold')))
        .clipper! as PageCurlClipper;
    expect(clipper.reduced, isTrue);
    final bounds = clipper.getClip(const Size(800, 600)).getBounds();
    expect(bounds.width, lessThan(800));
    expect(bounds.height, 600);
    await gesture.cancel();
    await tester.pumpAndSettle();
  });
}
