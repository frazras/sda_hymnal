import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_ref.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/hymnal_repository.dart';
import 'package:sdahymnal/services/midi_player.dart';

void main() {
  test('English catalog preserves every shipped song and reading', () {
    final hymns =
        HymnApi.allHymnsFromJson(File('assets/hymns.json').readAsStringSync());
    final readings = AdditionalReadingCatalog.fromJson(
        jsonDecode(File('assets/additional_readings.json').readAsStringSync())
            as Map<String, dynamic>);
    final repository =
        HymnalRepository.english(hymns, readings: readings.readings);
    expect(repository.hymnsFor('new'), hasLength(695));
    expect(repository.hymnsFor('sda-en-1941'), hasLength(703));
    expect(repository.edition('new')!.languageTag, 'en');
    for (final hymn in hymns) {
      expect(repository.hymn(hymn.ref), same(hymn));
      expect(MidiPlayer.hasMidi(hymn), isTrue);
    }
    expect(readings.readings, hasLength(225));
    for (final reading in readings.readings) {
      expect(repository.reading(reading.ref), same(reading));
      expect(repository.hymn(reading.ref), isNull);
    }
    expect(repository.hymnsFor('sda-es-2009'), isEmpty);
  });

  test('same number and title in three books remain separate', () {
    final songs = [
      for (final version in ['new', 'old', 'sda-es-2009'])
        Hymn(number: 388, title: 'Same title', body: version, version: version)
    ];
    final repository = HymnalRepository(editions: const [
      HymnalEdition.englishNew,
      HymnalEdition.englishOld,
      HymnalEdition(
          id: 'sda-es-2009',
          languageTag: 'es',
          displayName: 'Himnario Adventista',
          year: 2009),
    ], hymns: songs);
    expect(songs.map((h) => h.ref).toSet(), hasLength(3));
    for (final song in songs) {
      expect(repository.hymn(song.ref), same(song));
    }
    expect(MidiPlayer.hasMidi(songs.last), isFalse);
    expect(repository.hymn(HymnRef(bookId: 'other', itemId: '388')), isNull);
  });

  test('reading identity cannot collide with a hymn', () {
    final hymn = HymnRef(bookId: 'new', itemId: '696');
    final reading =
        HymnRef(bookId: 'new', itemId: '696', kind: HymnalItemKind.reading);
    expect(hymn, isNot(reading));
    expect(HymnRef.fromJson(reading.toJson()), reading);
    expect(HymnRef(bookId: 'sda-en-1985', itemId: '696'), hymn);
  });

  test('rejects duplicate items, unregistered books and duplicate editions',
      () {
    final song = Hymn(number: 1, title: 'Song', body: 'Verse', version: 'new');
    expect(() => HymnalRepository.english([song, song]), throwsFormatException);
    expect(() => HymnalRepository(editions: const [], hymns: [song]),
        throwsFormatException);
    expect(
        () => HymnalRepository(editions: const [
              HymnalEdition.englishNew,
              HymnalEdition.englishNew,
            ], hymns: []),
        throwsFormatException);
  });

  test('sparse numbers stay ordered and catalog lists cannot be mutated', () {
    final repository = HymnalRepository.english([
      for (final n in [10, 1, 4])
        Hymn(number: n, title: 'Song', body: 'Verse', version: 'old')
    ]);
    expect(repository.hymnsFor('old').map((h) => h.number), [1, 4, 10]);
    expect(repository.hymn(HymnRef(bookId: 'old', itemId: '2')), isNull);
    expect(() => repository.hymnsFor('old').clear(), throwsUnsupportedError);
  });
}
