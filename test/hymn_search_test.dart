import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/api.dart';
import 'package:sdahymnal/services/hymn_search.dart';

void main() {
  final hymns =
      HymnApi.allHymnsFromJson(File('assets/hymns.json').readAsStringSync());

  test('New 327 matches with straight, curly, or omitted apostrophes', () {
    final newHymns = hymns.where((h) => h.version == 'new').toList();
    for (final query in [
      'Id rather have',
      "I'd rather have",
      'I’d rather have',
      '  I’D   RATHER HAVE  '
    ]) {
      expect(searchHymns(newHymns, query).first.number, 327);
    }
  });

  test('titles and verse/chorus openings rank ahead of later lyrics', () {
    Hymn hymn(int n, String title, String body) =>
        Hymn(number: n, title: title, body: body, version: 'new');
    final later = hymn(1, 'Later', '<b>1</b><br>Opening<br>Precious promise');
    final chorus = hymn(2, 'Chorus',
        '<b>1</b><br>Opening<br><i><b>CHORUS:</b><br>Precious promise</i>');
    final verse = hymn(3, 'Verse', '<b>1</b><br>Precious promise<br>More');
    final title = hymn(4, 'Precious promise', 'Other words');
    expect(searchHymns([later, chorus, verse, title], 'precious promise'),
        [title, verse, chorus, later]);
    expect(searchHymns([later, verse], 'opening'), [later]);
  });

  test('Jesus love puts New 190 before interior title matches', () {
    for (final list in [
      hymns,
      hymns.where((h) => h.version == 'new').toList(),
    ]) {
      final results = searchHymns(list, 'Jesus love');
      expect((results.first.version, results.first.number), ('new', 190));
      expect(results.any((h) => h.version == 'new' && h.number == 183), isTrue);
    }
    final results = searchHymns(hymns, 'Jesus love');
    final interior =
        results.indexWhere((h) => h.version == 'new' && h.number == 183);
    for (final number in [401, 402]) {
      expect(
          results.indexWhere((h) => h.version == 'old' && h.number == number),
          allOf(greaterThan(0), lessThan(interior)));
    }
  });

  test('all title matches outrank lyric openings', () {
    Hymn hymn(int n, String title, String body) =>
        Hymn(number: n, title: title, body: body, version: 'new');
    final inside = hymn(1, 'Sing of Jesus love', 'Sing of Jesus love');
    final later = hymn(2, 'Later', '<b>1</b><br>Opening<br>Jesus loves me');
    final chorus = hymn(
        3, 'Chorus', '<b>1</b><br>Opening<br><b>CHORUS:</b><br>Jesus loves me');
    final verse = hymn(4, 'Verse', '<b>1</b><br>Jesus loves me');
    final title = hymn(5, 'Jesus loves me', 'Other words');
    expect(searchHymns([inside, later, chorus, verse, title], 'Jesus love'),
        [title, inside, verse, chorus, later]);
    final tiedTitle = hymn(6, 'Jesus loves us', 'Other words');
    expect(searchHymns([tiedTitle, title], 'Jesus love'), [tiedTitle, title]);
  });

  test('decodes entities and ignores markup and punctuation', () {
    final hymn = Hymn(
        number: 1,
        title: 'Example',
        version: 'old',
        body:
            r'<font color="#0B6138"><b>1</b></font><br>\nI&#39;d trust&nbsp;Him!<br>Always');
    expect(searchHymns([hymn], 'I’d trust Him'), [hymn]);
    expect(searchHymns([hymn], 'font'), isEmpty);
    expect(searchHymns([hymn], '0B6138'), isEmpty);
    expect(searchHymns([hymn], 'Him always'), [hymn]);
  });

  test('empty queries preserve order and exact numbers precede substrings', () {
    expect(searchHymns(hymns, '  '), hymns);
    final found = searchHymns(hymns, '327');
    expect(found.take(2).every((h) => h.number == 327), isTrue);
    expect(searchHymns(hymns, 'unfindablexyz'), isEmpty);
  });
}
