import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/ui/favorite_burst.dart';

void main() {
  testWidgets('Reduced motion leaves the heart unchanged', (tester) async {
    final key = GlobalKey<FavoriteBurstState>();
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: FavoriteBurst(key: key, favorite: false, color: Colors.green),
      ),
    ));
    key.currentState!.play(Colors.red);
    await tester.pump(const Duration(milliseconds: 100));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.favorite_border);
    expect(icon.color, Colors.green);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Rapid bursts restart safely and dispose mid-animation',
      (tester) async {
    final key = GlobalKey<FavoriteBurstState>();
    await tester.pumpWidget(MaterialApp(
      home: FavoriteBurst(key: key, favorite: false, color: Colors.black),
    ));
    key.currentState!.play(Colors.red);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    key.currentState!.play(Colors.green);
    await tester.pump();
    expect(tester.widget<Icon>(find.byType(Icon)).color!.toARGB32(),
        Colors.green.toARGB32());
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
