import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/l10n/app_localizations.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/l10n/instrument_text.dart';
import 'package:sdahymnal/services/instrument_catalog.dart';
import 'package:sdahymnal/services/music_options.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/instrument_picker.dart';
import 'package:sdahymnal/ui/music_options.dart';
import 'package:sdahymnal/services/midi_player.dart';
import 'package:sdahymnal/services/midi_transform.dart';
import 'package:sdahymnal/models/hymn.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all offered instruments families and roles have translated labels',
      () async {
    expect(instrumentNames, hasLength(111));
    for (final locale in AppLocalizations.supportedLocales) {
      final text = await AppLocalizations.delegate.load(locale);
      for (final entry in instrumentNames.entries) {
        expect(text.instrumentName(entry.key), isNotEmpty);
        expect(text.instrumentName(entry.key),
            isNot(text.instrumentNumber(entry.key + 1)));
        if (locale.languageCode == 'en') {
          expect(text.instrumentName(entry.key), entry.value);
        }
      }
      for (final family in instrumentCategories.keys) {
        expect(text.instrumentFamily(family), isNotEmpty);
        if (locale.languageCode == 'en') {
          expect(text.instrumentFamily(family), family);
        } else {
          expect(text.instrumentFamily(family), isNot(family));
        }
      }
      for (final style in [
        'jazz',
        'gospel',
        'jamaican_gospel',
        'reggae',
        'calypso',
        'classic'
      ]) {
        for (final role in instrumentRoles(style).values) {
          expect(text.instrumentRole(role), isNotEmpty);
          if (locale.languageCode == 'en') {
            expect(text.instrumentRole(role), role);
          } else {
            expect(text.instrumentRole(role), isNot(role));
          }
        }
      }
      expect(text.instrumentName(127), text.instrumentNumber(128));
    }
  });

  testWidgets('translated choices retain MIDI IDs and Jazz melody volume',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        for (final dark in [false, true]) {
          await tester.pumpWidget(const SizedBox.shrink());
          SharedPreferences.setMockInitialValues({});
          final options = MusicOptions.instance;
          await options.load();
          await options.setCustomInstruments(true);
          int? program;
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
            home: Scaffold(
                body: StatefulBuilder(
                    builder: (context, update) => InstrumentPicker(
                          program: program,
                          defaultLabel: context.appText.styleDefault,
                          onChanged: (value) async {
                            await options.setProgram('jazz', 0, value);
                            update(() => program = value);
                          },
                        ))),
          ));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(InstrumentPicker));
          final text = context.appText;
          await tester.tap(find.byType(InstrumentPicker));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
              find.text(text.instrumentFamily('Strings')), 100);
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.instrumentFamily('Strings')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.instrumentName(42)));
          await tester.pumpAndSettle();
          expect(program, 42);
          await options.load();
          expect(options.programs('jazz')[0], 42);
          expect(options.styleVolumes('jazz')[0], 50);
          await tester.tap(find.byType(InstrumentPicker));
          await tester.pumpAndSettle();
          await tester.tap(find.text(text.styleDefault));
          await tester.pumpAndSettle();
          expect(program, isNull);
          await options.load();
          expect(options.programs('jazz'), isEmpty);
          expect(options.styleVolumes('jazz')[0], 50);
          expect(tester.takeException(), isNull,
              reason: '${locale.languageCode} classic=$classic dark=$dark');
        }
      }
    }
  });
  testWidgets(
      'translated choir controls preserve custom part names and mix IDs',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hymn =
        Hymn(number: 1, title: 'Source song', body: '', version: 'old');
    final player = MidiPlayer.instance;
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        SharedPreferences.setMockInitialValues({});
        final options = MusicOptions.instance;
        await options.load();
        player.parts.value =
            midiParts(File('assets/midi/C001.mid').readAsBytesSync());
        player.mutedParts.value = {};
        player.soloParts.value = {};
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildHymnalTheme(HymnalTokens.dark, classic: classic),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!),
          home: Scaffold(body: ChoirPartsPanel(hymn: hymn)),
        ));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(ChoirPartsPanel));
        final text = context.appText;
        await tester.scrollUntilVisible(find.text('Soprano'), 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Soprano'));
        await tester.pumpAndSettle();
        expect(find.text(text.namePart), findsOneWidget);
        await tester.enterText(
            find.byType(TextFormField), 'Mi soprano — сердце');
        await tester.tap(find.text(text.save));
        await tester.pumpAndSettle();
        expect(find.text('Mi soprano — сердце'), findsOneWidget);
        await tester.tap(find.text(text.mute).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(text.solo).first);
        await tester.pumpAndSettle();
        expect(player.mutedParts.value, {1});
        expect(player.soloParts.value, {1});
        await options.load();
        expect(options.partName('old:1', 1, 'Soprano'), 'Mi soprano — сердце');
        await tester.scrollUntilVisible(find.text(text.resetChoirMix), 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(text.resetChoirMix));
        await tester.pumpAndSettle();
        expect(player.mutedParts.value, isEmpty);
        expect(player.soloParts.value, isEmpty);
        expect(tester.takeException(), isNull,
            reason: '${locale.languageCode} classic=$classic');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    player.parts.value = [];
  });
  testWidgets('localized ensemble edits retain style IDs and 50 percent melody',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in AppLocalizations.supportedLocales) {
      for (final classic in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        SharedPreferences.setMockInitialValues({});
        final options = MusicOptions.instance;
        await options.load();
        await options.setCustomInstruments(true);
        await InstrumentTheme.instance.set('jazz');
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildHymnalTheme(HymnalTokens.dark, classic: classic),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.3)),
              child: child!),
          home: const EnsembleInstrumentsPage(),
        ));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(EnsembleInstrumentsPage));
        final text = context.appText;
        expect(find.text(text.musicalStyleInstruments), findsOneWidget);
        await tester.scrollUntilVisible(
            find.byKey(const ValueKey('style-solo-0')), 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('style-solo-0')));
        await tester.pumpAndSettle();
        await options.load();
        expect(options.styleSolo('jazz'), {0});
        expect(options.styleVolumes('jazz')[0], 50);
        expect(InstrumentTheme.instance.value, 'jazz');
        await tester.scrollUntilVisible(
            find.text(text.previewHymn('Amazing Grace')), 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${locale.languageCode} classic=$classic');
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
