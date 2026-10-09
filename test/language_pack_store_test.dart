import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/language_pack_store.dart';

void main() {
  late Directory directory;
  setUp(() async =>
      directory = await Directory.systemTemp.createTemp('text-packs-'));
  tearDown(() async => directory.delete(recursive: true));
  Uint8List data(String title, [String book = 'sda-es-2009']) =>
      Uint8List.fromList(utf8.encode(jsonEncode({
        'schemaVersion': 1,
        'book': {
          'id': book,
          'displayName': 'Español',
          'languageTag': 'es',
          'year': 2009
        },
        'items': [
          {
            'id': '1',
            'number': 1,
            'title': title,
            'blocks': [
              {'kind': 'verse', 'text': 'Corazón\nSeñor'}
            ]
          }
        ],
        'topics': [],
      })));
  LanguagePackDownload descriptor(Uint8List bytes,
          [String book = 'sda-es-2009']) =>
      LanguagePackDownload(
          bookId: book,
          url: Uri.parse('https://example.com/pack.json'),
          bytes: bytes.length,
          checksum: sha256.convert(bytes).toString(),
          hymnCount: 1,
          topicCount: 0);

  test('verified text reopens offline and removes without touching other books',
      () async {
    final first = data('Primero'), second = data('Segundo', 'sda-es-1962');
    final store = LanguagePackStore(directory,
        download: (d) async => d.bookId == 'sda-es-2009' ? first : second);
    await store.install(descriptor(first));
    await store.install(descriptor(second, 'sda-es-1962'));
    final reopened = LanguagePackStore(directory,
        download: (_) async => throw StateError('offline'));
    expect((await reopened.load('sda-es-2009'))!.hymns.single.title, 'Primero');
    await reopened.remove('sda-es-2009');
    expect(await reopened.load('sda-es-2009'), isNull);
    expect((await reopened.load('sda-es-1962'))!.hymns.single.title, 'Segundo');
  });

  test('failed checksum or catalog update preserves working version', () async {
    final first = data('Primero'), second = data('Segundo');
    await LanguagePackStore(directory, download: (_) async => first)
        .install(descriptor(first));
    final pointer =
        await File('${directory.path}/sda-es-2009.json').readAsString();
    final store = LanguagePackStore(directory, download: (_) async => first);
    await expectLater(store.install(descriptor(second)), throwsFormatException);
    expect(await File('${directory.path}/sda-es-2009.json').readAsString(),
        pointer);
    expect((await store.load('sda-es-2009'))!.hymns.single.title, 'Primero');
    final mismatch = descriptor(first, 'sda-es-1962');
    await expectLater(store.install(mismatch), throwsFormatException);
    expect(await store.load('sda-es-1962'), isNull);
  });

  test('successful update cleans old text without accumulating revisions',
      () async {
    for (final title in ['Uno', 'Dos', 'Tres']) {
      final bytes = data(title);
      await LanguagePackStore(directory, download: (_) async => bytes)
          .install(descriptor(bytes));
    }
    final folders =
        await directory.list().where((e) => e is Directory).toList();
    expect(folders.length, 1);
    expect(
        (await LanguagePackStore(directory, download: (_) async => data(''))
                .load('sda-es-2009'))!
            .hymns
            .single
            .title,
        'Tres');
  });

  test('cancelled download keeps active text and leaves no staged files',
      () async {
    final bytes = data('Uno');
    await LanguagePackStore(directory, download: (_) async => bytes)
        .install(descriptor(bytes));
    final pending = Completer<Uint8List>();
    final cancellation = LanguagePackCancellation();
    final started = Completer<void>();
    final store = LanguagePackStore(directory, download: (_) {
      started.complete();
      return pending.future;
    });
    final installation =
        store.install(descriptor(bytes), cancellation: cancellation);
    await started.future;
    cancellation.cancel();
    pending.complete(bytes);
    await expectLater(installation, throwsA(isA<LanguagePackCancelled>()));
    expect((await store.load('sda-es-2009'))!.hymns.single.title, 'Uno');
    expect(
        (await directory.list().where((e) => e is Directory).toList()).length,
        1);
  });

  test('queued operations serialize and recover after a failed download',
      () async {
    final bytes = data('Uno');
    final pending = Completer<Uint8List>();
    var calls = 0;
    final store = LanguagePackStore(directory, download: (_) async {
      calls++;
      if (calls == 1) return pending.future;
      if (calls == 2) throw StateError('offline');
      return bytes;
    });
    final first = store.install(descriptor(bytes));
    final remove = store.remove('sda-es-2009');
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    pending.complete(bytes);
    await first;
    await remove;
    expect(await store.load('sda-es-2009'), isNull);
    await expectLater(store.install(descriptor(bytes)), throwsStateError);
    await store.install(descriptor(bytes));
    expect((await store.load('sda-es-2009'))!.hymns.single.title, 'Uno');
  });

  test('linked content and pointers never load external files', () async {
    final bytes = data('Uno');
    final store = LanguagePackStore(directory, download: (_) async => bytes);
    await store.install(descriptor(bytes));
    final pointer = File('${directory.path}/sda-es-2009.json');
    final metadata =
        jsonDecode(await pointer.readAsString()) as Map<String, dynamic>;
    final file = File('${directory.path}/${metadata['folder']}/pack.json');
    final external = File('${directory.path}/outside.json');
    await external.writeAsBytes(bytes);
    await file.delete();
    await Link(file.path).create(external.path);
    expect(await store.load('sda-es-2009'), isNull);
    await pointer.delete();
    await Link(pointer.path).create(external.path);
    expect(await store.load('sda-es-2009'), isNull);
    expect(await external.readAsBytes(), bytes);
  });

  test('corrupt pointers and changed local files fall back safely', () async {
    final bytes = data('Uno');
    final store = LanguagePackStore(directory, download: (_) async => bytes);
    await store.install(descriptor(bytes));
    final pointer = File('${directory.path}/sda-es-2009.json');
    final metadata =
        jsonDecode(await pointer.readAsString()) as Map<String, dynamic>;
    final file = File('${directory.path}/${metadata['folder']}/pack.json');
    await file.writeAsString('{}');
    expect(await store.load('sda-es-2009'), isNull);
    for (final value in ['{}', '[]', '{"folder":"../escape"}', 'broken']) {
      await pointer.writeAsString(value);
      expect(await store.load('sda-es-2009'), isNull);
    }
    expect(await store.load('../outside'), isNull);
  });
}
