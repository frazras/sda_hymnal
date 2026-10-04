import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/hymn_search.dart';
import 'package:sdahymnal/services/search_normalization.dart';

void main() {
  final packs = [
    for (final id in [
      'sda-es-2009',
      'sda-es-1962',
      'sda-pt-1996',
      'sda-ru-1997'
    ])
      HymnalPack.fromJson(File('assets/hymnals/$id.json').readAsStringSync())
  ];
  final all = [
    ...HymnApi.allHymnsFromJson(File('assets/hymns.json').readAsStringSync()),
    ...packs.expand((p) => p.hymns),
  ];

  test('accented and decomposed Latin queries match without altering lyrics',
      () {
    for (final (source, query) in [
      ('SEÑOR', 'senor'),
      ('Glória', 'glo\u0301ria'),
      ('Ó Deus de Amor', 'o deus de amor'),
      ('Salvação', 'salvacao'),
    ]) {
      expect(normalizeHymnSearch(source), normalizeHymnSearch(query));
    }
    final hymn = packs[2].hymns.first;
    final original = hymn.body;
    expect(searchHymns(packs[2].hymns, 'o deus de amor').first, hymn);
    expect(hymn.title, 'Ó Deus de Amor');
    expect(hymn.body, original);
    expect(normalizeHymnSearch('Glória', foldLatinAccents: false), 'glória');
    expect(
        normalizeHymnSearch('glo\u0301ria', foldLatinAccents: false), 'glória');
  });

  test('Cyrillic canonical equivalence preserves distinct letters', () {
    expect(normalizeHymnSearch('СВЯТОЙ'), normalizeHymnSearch('святои\u0306'));
    expect(normalizeHymnSearch('всё'), normalizeHymnSearch('все\u0308'));
    expect(normalizeHymnSearch('всё'), isNot(normalizeHymnSearch('все')));
    expect(normalizeHymnSearch('святой'), isNot(normalizeHymnSearch('святои')));
    expect(searchHymns(packs[3].hymns, 'КОЛЬ СЛАВЕН').first.number, 1);
  });

  for (final (language, label, phrase) in [
    ('es', 'Coro:', 'Bendición'),
    ('pt', 'Refrão:', 'Salvação'),
    ('ru', 'Припев:', 'Славьте Бога'),
  ]) {
    test('localized $label ranks as refrain and is not searchable metadata',
        () {
      Hymn song(int n, String title, String body) => Hymn(
          number: n,
          title: title,
          body: body,
          version: 'test-$language',
          languageTag: language);
      final later = song(1, 'Other', 'Opening<br>Later<br>$phrase');
      final refrain = song(2, 'Other', 'Opening<br><b>$label</b><br>$phrase');
      final opening = song(3, 'Other', phrase);
      final title = song(4, phrase, 'Other');
      expect(searchHymns([later, refrain, opening, title], phrase),
          [title, opening, refrain, later]);
      expect(searchHymns([refrain], label), isEmpty);
    });
  }

  test('all installed books preserve exact-number priority and identities', () {
    expect(all, hasLength(3534));
    final results = searchHymns(all, '388');
    final exact = results.where((h) => h.number == 388).toList();
    expect(exact, hasLength(5));
    expect(exact.map((h) => h.ref).toSet(), hasLength(5));
    expect(results.take(5), exact);
    expect(searchHymns(packs[0].hymns, 'senor'), isNotEmpty);
    expect(searchHymns(all, '∞☃').length, all.length);
  });

  test('benchmark cold and cached search of installed and expanded catalogs',
      () {
    for (final copies in [1, 3]) {
      final catalog = [
        for (var i = 0; i < copies; i++)
          for (final h in all)
            Hymn(
                number: h.number,
                title: h.title,
                body: h.body,
                version: '${h.version}-$i',
                languageTag: h.languageTag)
      ];
      final cold = Stopwatch()..start();
      expect(searchHymns(catalog, 'senor'), isNotEmpty);
      cold.stop();
      final timings = <int>[];
      for (var i = 0; i < 20; i++) {
        final watch = Stopwatch()..start();
        searchHymns(catalog, ['gloria', 'славен', '327', 'love'][i % 4]);
        timings.add(watch.elapsedMicroseconds);
      }
      timings.sort();
      // Report timings instead of making CI speed a correctness requirement.
      // ignore: avoid_print
      print('Search ${catalog.length}: cold=${cold.elapsedMilliseconds}ms, '
          'cached median=${(timings[10] / 1000).toStringAsFixed(2)}ms, '
          'max=${(timings.last / 1000).toStringAsFixed(2)}ms');
    }
  });
}
