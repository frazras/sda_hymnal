import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/services/service_playlists.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/service_playlists.dart';

void main() {
  final repo = HymnalRepository(editions: const [
    HymnalEdition.englishNew,
    HymnalEdition(
        id: 'sda-es-1962',
        languageTag: 'es',
        displayName: 'Español · Antiguo',
        year: 1962)
  ], hymns: [
    Hymn(number: 1, version: 'new', title: 'English hymn', body: 'Lyrics'),
    Hymn(
        number: 1,
        version: 'sda-es-1962',
        title: 'Canción de esperanza',
        body: 'Letra')
  ], readings: [
    const AdditionalReading(
        id: 'reading1',
        edition: 'new',
        order: 0,
        number: 701,
        title: 'Responsive reading',
        category: 'Worship',
        segments: [])
  ]);

  for (final classic in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets(
          'create mixed service with repeat and reload on compact screen classic=$classic dark=$dark',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = ServicePlaylists();
        await tester.pumpWidget(MaterialApp(
            theme: buildHymnalTheme(
                dark ? HymnalTokens.dark : HymnalTokens.light,
                classic: classic),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!),
            home: ServicePlaylistsPage(repository: repo, store: store)));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New service'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Sabbath worship');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add hymn or reading'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'cancion');
        await tester.pumpAndSettle();
        expect(find.text('Español · Antiguo'), findsOneWidget);
        await tester.tap(find.text('1  Canción de esperanza'));
        await tester.pumpAndSettle();
        expect(store.playlists.single.entries.single.ref.bookId, 'sda-es-1962');
        await tester.tap(find.byType(PopupMenuButton<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Repeat at end'));
        await tester.pumpAndSettle();
        expect(store.playlists.single.entries, hasLength(2));
        expect(store.playlists.single.entries.map((e) => e.id).toSet(),
            hasLength(2));
        await tester.tap(find.text('Add hymn or reading'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '701');
        await tester.pumpAndSettle();
        await tester.tap(find.text('701  Responsive reading'));
        await tester.pumpAndSettle();
        expect(store.playlists.single.entries.last.ref.kind.name, 'reading');
        final handles = find.byIcon(Icons.drag_handle);
        await tester.ensureVisible(handles.last);
        await tester.pumpAndSettle();
        final start = tester.getCenter(handles.last);
        final finish =
            tester.getTopLeft(find.byType(ReorderableListView)).dy + 5;
        final gesture = await tester.startGesture(start);
        await tester.pump();
        for (var y = start.dy - 20; y >= finish; y -= 20) {
          await gesture.moveTo(Offset(start.dx, y));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await gesture.moveTo(Offset(start.dx, finish));
        await tester.pump(const Duration(milliseconds: 500));
        await gesture.up();
        await tester.pumpAndSettle();
        await store.load();
        final reloaded = ServicePlaylists();
        await reloaded.load();
        expect(reloaded.playlists.single.entries.first.ref.kind.name, 'reading',
            reason: store.playlists.single.entries
                .map((e) => e.ref.itemId)
                .join(','));
        expect(reloaded.playlists.single.entries, hasLength(3));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('unreadable storage disables edits and retains original data',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {ServicePlaylists.storageKey: 'corrupted'});
    final store = ServicePlaylists();
    await tester.pumpWidget(MaterialApp(
        home: ServicePlaylistsPage(repository: repo, store: store)));
    await tester.pumpAndSettle();
    expect(find.text('Editing is paused to protect your saved data.'),
        findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(
        (await SharedPreferences.getInstance())
            .getString(ServicePlaylists.storageKey),
        'corrupted');
  });
}
