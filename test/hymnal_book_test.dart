import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_book.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';

import 'hymnal_pack_test.dart' show FilePackBundle;

String plain(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>'), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\n+'), '\n')
    .trim();

void main() {
  const escape = HtmlEscape();
  String escaped(String value) => escape.convert(value).replaceAll('\n', '<br>');

  group('imported reading copy', () {
    test('styles numbered verses and labelled refrains like the English books',
        () {
      final html = lyricReadingHtml([
        (refrain: false, label: '1.', text: 'Uno'),
        (refrain: true, label: 'Coro:', text: 'Gloria'),
      ], escaped);
      expect(html, contains('<font color="#0B6138"><b>1</b></font>'));
      expect(html,
          contains('<i><b><font color="#CD9B1D">Coro:</font></b><br>Gloria</i>'));
    });

    test('repeats a single refrain after every verse and ends on it', () {
      final html = lyricReadingHtml([
        (refrain: false, label: '1.', text: 'Uno'),
        (refrain: true, label: 'Coro', text: 'Gloria'),
        (refrain: false, label: '2.', text: 'Dos'),
        (refrain: false, label: '3.', text: 'Tres'),
      ], escaped);
      expect(plain(html).split('\n'),
          ['1', 'Uno', 'Coro:', 'Gloria', '2', 'Dos', 'Coro:', 'Gloria', '3', 'Tres', 'Coro:', 'Gloria']);
    });

    test('keeps source order when refrains are not a single early block', () {
      final twice = lyricReadingHtml([
        (refrain: false, label: '1.', text: 'Uno'),
        (refrain: true, label: 'Coro', text: 'A'),
        (refrain: false, label: '2.', text: 'Dos'),
        (refrain: true, label: 'Coro', text: 'B'),
      ], escaped);
      expect(plain(twice).split('\n'),
          ['1', 'Uno', 'Coro:', 'A', '2', 'Dos', 'Coro:', 'B']);
      final last = lyricReadingHtml([
        (refrain: false, label: '', text: 'Uno'),
        (refrain: false, label: '', text: 'Dos'),
        (refrain: true, label: 'Припев:', text: 'Слава'),
      ], escaped);
      expect(plain(last).split('\n'), ['Uno', 'Dos', 'Припев:', 'Слава']);
    });

    test('never invents verse numbers and escapes source text', () {
      final html = lyricReadingHtml([
        (refrain: false, label: '', text: '<b>x</b> & y'),
      ], escaped);
      expect(html, '&lt;b&gt;x&lt;&#47;b&gt; &amp; y');
    });

    test('bundled books keep every lyric word in the reading copy', () async {
      final packs = await loadHymnalPacks(FilePackBundle());
      for (final pack in packs) {
        for (final hymn in pack.hymns) {
          final reading = plain(hymn.readingBody).replaceAll(RegExp(r'[.:]'), '');
          for (final line in plain(hymn.body).split('\n')) {
            expect(reading, contains(line.replaceAll(RegExp(r'[.:]'), '')),
                reason: '${hymn.version} ${hymn.number}');
          }
        }
      }
    });
  });

  group('hymnal choices', () {
    Hymn hymn(String version, int n, String tag) =>
        Hymn(number: n, title: 'T$n', body: 'b', version: version, languageTag: tag);

    test('pair English and Spanish and list other books once', () async {
      final packs = await loadHymnalPacks(FilePackBundle());
      final books = buildHymnalBooks(
          englishNew: [hymn('new', 1, 'en')],
          englishOld: [hymn('old', 1, 'en')],
          packs: packs);
      expect(books.map((b) => b.id), [
        'english',
        'spanish',
        'sda-pt-1996',
        'sda-ru-1997',
        'sda-fr-hymnes-et-louanges',
        'sda-sw-nyimbo-za-kristo',
      ]);
      final spanish = books[1];
      expect(spanish.paired, isTrue);
      expect(spanish.primary.first.version, 'sda-es-2009');
      expect(spanish.secondary.first.version, 'sda-es-1962');
      expect(books.map((b) => b.code), ['EN', 'ES', 'PT', 'RU', 'FR', 'SW']);
      expect(books.map((b) => b.languageName),
          ['English', 'Español', 'Português', 'Русский', 'Français', 'Kiswahili']);
      expect(books.where((b) => b.paired).map((b) => b.id), ['english', 'spanish']);
      expect(books[4].hasTopics, isFalse);
      expect(books[2].hasTopics, isTrue);
    });

    test('short labels name books without inventing years', () {
      expect(editionShortLabel('sda-es-2009', 'Español · 2009'), 'Himnario Nuevo');
      expect(editionShortLabel('sda-fr-hymnes-et-louanges',
          'Français · Hymnes et Louanges'), 'Hymnes et Louanges');
      expect(editionShortLabel('sda-xx-2001', 'Lang · 2001'), 'Lang · 2001');
      expect(pairedBadgeLabel('sda-es-1962'), 'ANTIGUO\nHIMNARIO');
      expect(pairedBadgeLabel('sda-pt-1996'), isNull);
      expect(crossLanguageBadge(hymn('old', 3, 'en')), 'EN · OLD');
      expect(crossLanguageBadge(hymn('sda-pt-1996', 3, 'pt')), 'PT');
    });
  });
}
