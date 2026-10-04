import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/services/hymn_text_export.dart';

void main() {
  test('English export preserves verses and one source chorus', () {
    final data = jsonDecode(File('assets/hymns.json').readAsStringSync());
    final row = (data['hymns'] as List)
        .firstWhere((dynamic h) => h['number'] == 2 && h['version'] == 'new');
    final export = HymnTextExport(Hymn(
        number: 2, title: row['title'], body: row['body'], version: 'new'));
    expect(export.sections.length, 5);
    expect(export.sections[0].label, 'Verse 1');
    expect(export.sections[1].label, 'CHORUS:');
    expect(export.sections[2].label, 'Verse 2');
    expect('CHORUS:'.allMatches(export.text()).length, 1);
    expect(export.text(section: 2), contains('New Hymnal\n\n2\n'));
    expect(export.text(section: 2), isNot(contains('O fire')));
    expect(export.text(), isNot(contains('<br>')));
    expect(export.text(), isNot(contains(r'\n')));
  });

  test('entities and non-Latin source text survive export', () {
    final export = HymnTextExport(Hymn(
        number: 1,
        title: 'Слава',
        body: '<b>1</b><br>Слава &amp; мир<br>Ёж и йод<br><br>'
            '<b>Припев:</b><br>Свят!',
        version: 'sda-ru-1997',
        languageTag: 'ru',
        bookTitle: 'Гимны Надежды 1997'));
    expect(export.lyrics, '1\nСлава & мир\nЁж и йод\n\nПрипев:\nСвят!');
    expect(export.sections.length, 2);
    expect(export.sections[1].label, 'Припев:');
    expect(export.text(section: 1), contains('Гимны Надежды 1997'));
  });

  test('all imported hymns retain every nonblank source lyric line', () {
    for (final id in [
      'sda-es-2009',
      'sda-es-1962',
      'sda-pt-1996',
      'sda-ru-1997'
    ]) {
      final pack = HymnalPack.fromJson(
          File('assets/hymnals/$id.json').readAsStringSync());
      for (final hymn in pack.hymns) {
        final export = HymnTextExport(hymn);
        final lines =
            export.lyrics.split('\n').where((s) => s.isNotEmpty).toList();
        final sections = export.sections
            .expand((s) => s.text.split('\n'))
            .where((s) => s.isNotEmpty)
            .toList();
        expect(sections, lines, reason: '$id ${hymn.number}');
      }
    }
  });
}
