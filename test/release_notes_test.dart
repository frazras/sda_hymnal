import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sdahymnal/models/release_notes.dart';
import 'package:sdahymnal/services/release_notes.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('release history matches the app version and has useful entries', () {
    final catalog = ReleaseNotesCatalog.fromJson(
      File('assets/release_notes.json').readAsStringSync(),
    );
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(catalog.currentVersion, appReleaseVersion);
    expect(catalog.releases.first.version, appReleaseVersion);
    expect(
      RegExp(r'^version:\s+([^+\s]+)', multiLine: true)
          .firstMatch(pubspec)!
          .group(1),
      appReleaseVersion,
    );
    expect(
      catalog.releases.map((release) => release.version).toSet().length,
      catalog.releases.length,
    );
    for (final release in catalog.releases) {
      expect(
        release.date,
        matches(RegExp(r'^[A-Z][a-z]+ \d{1,2}, 20\d{2}$')),
        reason: '${release.version} must include the day of the month',
      );
      expect(release.features, isNotEmpty);
      expect(release.features.every((feature) => feature.trim().isNotEmpty),
          isTrue);
    }
  });

  test('Play Store notes keep 4.1.1 and 4.2.0 changes separate', () {
    final notes411 = File(
      'android/fastlane/metadata/android/en-US/changelogs/40101.txt',
    ).readAsStringSync();
    final notes420 = File(
      'android/fastlane/metadata/android/en-US/changelogs/40200.txt',
    ).readAsStringSync();

    expect(notes411, contains('Classic design'));
    expect(notes411, contains('Old Hymnal 533 and 534'));
    expect(notes420, contains('Choruses now repeat after each verse'));
    for (final alreadyPublished in [
      'Classic design',
      'Old Hymnal 533',
      'Old Hymnal 534',
      'matching app icon',
      'caching and playback reliability',
    ]) {
      expect(notes420, isNot(contains(alreadyPublished)));
    }
    expect(notes420.length, lessThanOrEqualTo(500));
  });

  testWidgets(
      'update history appears once per version and includes older notes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => ReleaseNotesService.instance.showIfNeeded(context),
            child: const Text('Check for updates'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(
      find.text('You have been updated to the latest version.'),
      findsOneWidget,
    );
    expect(find.text('Version $appReleaseVersion'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Version 4.0.0'),
      250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('release-notes-history')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Version 4.0.0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('release-notes-done')));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getStringList(ReleaseNotesService.seenVersionsKey),
      contains(appReleaseVersion),
    );

    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('release-notes-title')), findsNothing);
  });

  testWidgets('Appearance is immediately before More and Donate is absent',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildHymnalTheme(HymnalTokens.light),
        home: const Scaffold(body: Settings()),
      ),
    );
    await tester.pumpAndSettle();

    final readingY = tester.getTopLeft(find.text('READING')).dy;
    final soundY = tester.getTopLeft(find.text('SOUND')).dy;
    final appearanceY = tester.getTopLeft(find.text('APPEARANCE')).dy;
    final moreY = tester.getTopLeft(find.text('MORE')).dy;
    expect(readingY, lessThan(soundY));
    expect(soundY, lessThan(appearanceY));
    expect(appearanceY, lessThan(moreY));
    expect(find.text('What’s new'), findsOneWidget);
    expect(find.text('Donate'), findsNothing);
  });
}
