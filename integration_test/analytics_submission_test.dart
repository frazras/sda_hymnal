import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sdahymnal/main.dart' as app;
import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/ui/statistics.dart';
import 'package:sdahymnal/ui/common.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const token = String.fromEnvironment('ANALYTICS_TEST_TOKEN');
  const version = String.fromEnvironment('ANALYTICS_TEST_VERSION');
  testWidgets('native app settings -> hymn open -> live analytics collector',
      (tester) async {
    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0;
          attempt < 250 && finder.evaluate().isEmpty;
          attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(finder, findsWidgets);
    }

    expect(token.isNotEmpty && version.isNotEmpty, isTrue,
        reason: 'Pass the ignored build/analytics/e2e-defines.json file');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
        ReleaseNotesService.seenVersionsKey, [appReleaseVersion]);
    await AppAnalytics.instance
        .initialize(testToken: token, testVersion: version);
    expect(AppAnalytics.instance.available, isTrue,
        reason: 'Native no-backup storage and SQLite must initialize');
    expect(AppAnalytics.instance.enabled, isTrue,
        reason: 'A fresh installation enables statistics by default');
    await AppAnalytics.instance.setEnabled(false);
    await app.main();
    // The home keypad intentionally blinks forever; do not wait for all
    // animations to settle. Wait for the specific controls instead.
    await waitFor(find.text('Settings'));
    await tester.tap(find.text('Settings').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('Community statistics'), 350,
        scrollable: find
            .descendant(
                of: find.byType(app.Hymnal), matching: find.byType(Scrollable))
            .last);
    await tester.tap(find.text('Community statistics'));
    await waitFor(find.text('Most-opened hymns'));
    expect(AppAnalytics.instance.enabled, isFalse,
        reason: 'The public report must work while sharing is off');
    await tester.tap(find.text('Last week'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StatisticsPage), findsOneWidget);
    await tester.tap(find
        .descendant(
            of: find.byType(SubPageHeader), matching: find.byType(Pressable))
        .first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('analytics-toggle')), 400,
        scrollable: find
            .descendant(
                of: find.byType(app.Hymnal), matching: find.byType(Scrollable))
            .last);
    await tester.tap(find.byKey(const ValueKey('analytics-toggle')));
    for (var attempt = 0;
        attempt < 100 && !AppAnalytics.instance.enabled;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(AppAnalytics.instance.enabled, isTrue);
    await tester.tap(find.text('Numbers').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('1').last);
    await waitFor(find.text('Praise to the Lord'));
    await tester.tap(find.text('Praise to the Lord').first);
    await tester.pump(const Duration(milliseconds: 500));
    // Real network availability is not deterministic. Force bounded retries
    // of the durable outbox; AWS verification still requires exactly one open.
    for (var attempt = 0; attempt < 3; attempt++) {
      await AppAnalytics.instance.submitForTesting();
      if (AppAnalytics.instance.status == 'Weekly statistics sent') break;
      await tester.pump(const Duration(seconds: 2));
    }
    expect(AppAnalytics.instance.status, 'Weekly statistics sent');
    await AppAnalytics.instance.setEnabled(false);
    expect(AppAnalytics.instance.enabled, isFalse);
    final directory = await const MethodChannel('sdahymnal/analytics_storage')
        .invokeMethod<String>('directory');
    // Reuse the plugin's existing connection; its owner is AppAnalytics.
    final database = await openDatabase('$directory/analytics.sqlite');
    for (final table in [
      'periods',
      'counters',
      'history',
      'outbox',
      'hymns_seen'
    ]) {
      expect(await database.query(table), isEmpty);
    }
    expect(await database.query('meta'), [
      {'key': 'enabled', 'value': '0'}
    ]);
  });
}
