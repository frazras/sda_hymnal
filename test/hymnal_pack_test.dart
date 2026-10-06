import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/services/midi_player.dart';

class FilePackBundle extends CachingAssetBundle {
  final Map<String, Uint8List> replacements;
  FilePackBundle([this.replacements = const {}]);
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (!replacements.containsKey(key) && !File(key).existsSync()) {
      return rootBundle.loadString(key, cache: cache);
    }
    return utf8.decode(replacements[key] ?? File(key).readAsBytesSync());
  }

  @override
  Future<ByteData> load(String key) async {
    if (!replacements.containsKey(key) && !File(key).existsSync()) {
      return rootBundle.load(key);
    }
    final bytes = replacements[key] ?? File(key).readAsBytesSync();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  test('all six offline books and topics resolve to their own lyrics',
      () async {
    final packs = await loadHymnalPacks(FilePackBundle());
    expect(packs.map((p) => p.hymns.length), [614, 527, 610, 385, 520, 220]);
    expect(packs.fold(0, (int n, p) => n + p.topics.length), 200);
    for (final pack in packs) {
      final source = jsonDecode(
              File('assets/hymnals/${pack.edition.id}.json').readAsStringSync())
          as Map<String, dynamic>;
      for (var i = 0; i < pack.hymns.length; i++) {
        final hymn = pack.hymns[i];
        expect(hymn.ref.bookId, pack.edition.id);
        expect(hymn.number, i + 1);
        expect(hymn.title, source['items'][i]['title']);
        expect(hymn.body, isNotEmpty);
        expect(hymn.readingBody, hymn.body);
        expect(MidiPlayer.hasMidi(hymn),
            hymn.version == 'sda-es-2009' && hymn.number == 303);
        expect(hymn.video, isNull);
        expect(hymn.metadata, isNull);
      }
      for (final topic in pack.topics) {
        expect(topic.hymns, isNotEmpty);
        expect(topic.hymns.every((h) => h.version == pack.edition.id), isTrue);
      }
    }
    expect(packs[4].edition.year, isNull);
    expect(packs[5].edition.year, isNull);
    expect(packs[4].hymns.first.title, 'Je veux chanter');
    expect(packs[4].topics, isEmpty);
    expect(packs[5].topics, isEmpty);
    expect(packs[2].hymns.first.title, 'Ó Deus de Amor');
    expect(packs[3].hymns.first.title, 'Коль славен');
    expect(packs[0].hymns[387].ref, isNot(packs[1].hymns[387].ref));
  });

  test('changed bundle bytes fail checksum verification', () async {
    final bundle = FilePackBundle({
      'assets/hymnals/sda-es-2009.json': Uint8List.fromList(utf8.encode('{}')),
    });
    await expectLater(loadHymnalPacks(bundle), throwsFormatException);
  });

  test('plain source text cannot inject markup or execute a link', () {
    final pack = {
      'schemaVersion': 1,
      'book': {
        'id': 'sda-es-2009',
        'languageTag': 'es',
        'displayName': 'Español',
        'year': 2009
      },
      'items': [
        {
          'id': '1',
          'number': 1,
          'title': 'Title',
          'blocks': [
            {
              'kind': 'verse',
              'label': '<b>1.</b>',
              'text': '<script>alert(1)</script>\nGloria & paz'
            },
          ]
        }
      ],
      'topics': [],
    };
    final hymn = HymnalPack.fromJson(jsonEncode(pack)).hymns.single;
    expect(hymn.body, contains('&lt;script&gt;'));
    expect(hymn.body, contains('&amp;'));
    expect(hymn.body, isNot(contains('<script>')));
    expect(hymn.body, contains('<br>'));
  });

  test('invalid schema, duplicate numbers, and broken topics fail closed', () {
    final original = File('assets/hymnals/sda-ru-1997.json').readAsStringSync();
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (data) => data['schemaVersion'] = 8,
      (data) => data['items'].add(data['items'][0]),
      (data) => data['topics'][0]['itemIds'] = ['999'],
      (data) => data['book']['id'] = 'new',
    ]) {
      final data = jsonDecode(original) as Map<String, dynamic>;
      mutate(data);
      expect(
          () => HymnalPack.fromJson(jsonEncode(data)), throwsFormatException);
    }
  });
}
