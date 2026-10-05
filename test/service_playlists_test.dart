import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/models/hymn_ref.dart';
import 'package:sdahymnal/models/service_playlist.dart';
import 'package:sdahymnal/services/service_playlists.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ServiceEntry entry(String id, String book, String item,
          {HymnalItemKind kind = HymnalItemKind.hymn}) =>
      ServiceEntry(
          id: id, ref: HymnRef(bookId: book, itemId: item, kind: kind));
  ServicePlaylist service() =>
      ServicePlaylist(id: 'sabbath', name: 'Sabbath', entries: [
        entry('opening', 'new', '388'),
        entry('reading', 'new', 'reading-701', kind: HymnalItemKind.reading),
        entry('spanish', 'sda-es-2009', '388'),
        entry('closing', 'new', '388'),
        entry('uninstalled', 'custom-future-book', 'non-numeric-id'),
      ]);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'occurrence navigation preserves repeated hymns, readings and exact order',
      () {
    final list = service();
    expect(list.adjacent('opening', -1), isNull);
    expect(list.adjacent('opening', 1)!.ref.kind, HymnalItemKind.reading);
    expect(list.adjacent('closing', -1)!.ref.bookId, 'sda-es-2009');
    expect(list.adjacent('closing', 1)!.id, 'uninstalled');
    expect(list.adjacent('uninstalled', 1), isNull);
    expect(list.adjacent('absent', 1), isNull);
    expect(list.entries[0].ref, list.entries[3].ref);
    final moved = list.reordered(3, 0);
    expect(moved.entries.map((e) => e.id),
        ['closing', 'opening', 'reading', 'spanish', 'uninstalled']);
    expect(moved.without('closing').entries.first.id, 'opening');
    expect(list.entries.first.id, 'opening');
    expect(() => list.entries.clear(), throwsUnsupportedError);
  });

  test('save and reload retains mixed books, repeats and unavailable entries',
      () async {
    SharedPreferences.setMockInitialValues(
        {'favorites': 'keep', 'melodyVolume': 0.5});
    final store = ServicePlaylists();
    await store.load();
    await store.create(service());
    final reloaded = ServicePlaylists();
    await reloaded.load();
    expect(reloaded.playlists.single.toJson(), service().toJson());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('favorites'), 'keep');
    expect(prefs.getDouble('melodyVolume'), 0.5);
    await reloaded.delete('sabbath');
    await store.load();
    expect(store.playlists, isEmpty);
  });

  test('rapid edits compose against latest saved sequence', () async {
    final store = ServicePlaylists();
    await store.load();
    await store.create(service());
    await Future.wait([
      store.update('sabbath', (s) => s.renamed('Evening worship')),
      store.update('sabbath', (s) => s.reordered(3, 0)),
      store.update('sabbath', (s) => s.appended(entry('last', 'old', '653'))),
    ]);
    await store.load();
    expect(store.playlists.single.name, 'Evening worship');
    expect(store.playlists.single.entries.first.id, 'closing');
    expect(store.playlists.single.entries.last.ref.bookId, 'sda-en-1941');
  });

  test('invalid or future data is retained and editing fails closed', () async {
    for (final raw in [
      '{broken',
      jsonEncode({'schemaVersion': 2, 'playlists': []}),
      jsonEncode({
        'schemaVersion': 1,
        'playlists': [service().toJson(), service().toJson()]
      })
    ]) {
      SharedPreferences.setMockInitialValues(
          {ServicePlaylists.storageKey: raw});
      final store = ServicePlaylists();
      await store.load();
      expect(store.storageError, isTrue);
      await expectLater(store.create(service()), throwsStateError);
      expect(
          (await SharedPreferences.getInstance())
              .getString(ServicePlaylists.storageKey),
          raw);
    }
  });

  test('editing before load and duplicate IDs cannot replace saved data',
      () async {
    final store = ServicePlaylists();
    await expectLater(store.create(service()), throwsStateError);
    await store.load();
    await store.create(service());
    await expectLater(store.create(service()), throwsFormatException);
    await store.update('sabbath', (s) => s.renamed('Still editable'));
    expect(store.playlists.single.name, 'Still editable');
    expect(() => service().appended(service().entries.first),
        throwsFormatException);
  });
}
