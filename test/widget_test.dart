// Basic smoke test: the app builds and shows its three tabs.

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/main.dart';

void main() {
  testWidgets('App builds and shows tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const Hymnal());
    await tester.pump();

    expect(find.text(" Numbers"), findsOneWidget);
    expect(find.text("Search"), findsOneWidget);
    expect(find.text("Settings"), findsOneWidget);
  });
}
