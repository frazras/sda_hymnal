// Basic smoke test: the app builds and shows its three nav tabs.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdahymnal/main.dart';
import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'hymnal_pack_test.dart' show FilePackBundle;

void main() {
  testWidgets('App builds and shows bottom nav tabs',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      ReleaseNotesService.seenVersionsKey: <String>[appReleaseVersion],
    });
    await tester.pumpWidget(
        DefaultAssetBundle(bundle: FilePackBundle(), child: const Hymnal()));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Numbers'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('HYMN OR READING NUMBER'), findsOneWidget);
    expect(find.byKey(const ValueKey('hymnal-selector')), findsOneWidget);
  });
}
