import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/models/hymn_metadata.dart';
import 'package:sdahymnal/services/api.dart';

void main() {
  final raw = File('assets/hymn_metadata.json').readAsStringSync();
  final data = json.decode(raw) as Map<String, dynamic>;
  final catalog = HymnMetadataCatalog.fromJson(raw);
  final hymns = HymnApi.allHymnsFromJson(
    File('assets/hymns.json').readAsStringSync(),
    metadata: catalog,
  );

  group('hymn metadata catalog', () {
    test('covers every Old and New Hymnal reference', () {
      expect(data['schemaVersion'], 1);
      expect((data['lookup'] as Map<String, dynamic>), hasLength(hymns.length));
      for (final hymn in hymns) {
        expect(hymn.metadata, isNotNull,
            reason: '${hymn.version} ${hymn.number} ${hymn.title}');
      }
      for (final rawHymn in data['hymns'] as List<dynamic>) {
        final hymn = rawHymn as Map<String, dynamic>;
        expect(hymn, containsPair('authors', isA<List<dynamic>>()));
        expect(hymn, contains('authorStatus'));
        expect(hymn['numbers'], containsPair('old', isA<List<dynamic>>()));
        expect(hymn['numbers'], containsPair('new', isA<List<dynamic>>()));
      }
    });

    test('formalizes the Old 17 and New 27 cross-reference', () {
      final old = catalog.forHymn('old', 17)!;
      final modern = catalog.forHymn('new', 27)!;
      expect(old.id, modern.id);
      expect(old.title, 'Rejoice, Ye Pure in Heart!');
      expect(old.authorsFor('old', 17), contains('Edward H. Plumptre'));
      expect(
        modern.authorsFor('new', 27).single,
        startsWith('Edward H. Plumptre'),
      );
      expect(old.editionFor('old', 17)?.tuneTitle, 'MARION');
      expect(modern.editionFor('new', 27)?.tuneTitle, 'MARION');
    });

    test('keeps Old 118-120 as the three Watts settings', () {
      final metadata = catalog.forHymn('old', 119)!;
      expect(metadata.title, 'When I Survey the Wondrous Cross');
      expect(metadata.authorsFor('old', 119), ['Isaac Watts']);
      expect(
        metadata.editionFor('old', 119)?.firstLine,
        'When I survey the wondrous cross',
      );
    });

    test('sanitizes recovered story artifacts and preserves every record', () {
      final allStories = <Map<String, dynamic>>[
        for (final hymn in data['hymns'] as List<dynamic>)
          for (final story
              in (hymn as Map<String, dynamic>)['stories'] as List<dynamic>? ??
                  const [])
            story as Map<String, dynamic>,
        for (final story in data['supplementalStories'] as List<dynamic>)
          story as Map<String, dynamic>,
      ];
      expect(allStories, hasLength(265));
      expect(
        allStories.where((story) => story['sourceId'] == 'sharefaith'),
        hasLength(70),
      );
      expect(
        allStories.where((story) => story['sourceId'] == 'tanbible'),
        hasLength(195),
      );
      for (final story in allStories) {
        expect(story['title'].toString(), isNot(contains('~')));
        expect(story['text']?.toString() ?? '', isNot(contains('~')));
        expect(story['text']?.toString() ?? '', isNot(matches(r'\+{5,}')));
        expect(story, isNot(contains('sourceUrl')),
            reason: 'Stories are fully bundled; no external document links');
        expect(
          (story['text']?.toString().trim().isNotEmpty ?? false) ||
              (story['sourceUrl']?.toString().trim().isNotEmpty ?? false),
          isTrue,
          reason: story['id'].toString(),
        );
      }
    });

    test('removes the appended lyrics from the ShareFaith story body', () {
      final abide = catalog.forHymn('old', 50)!;
      final story = abide.stories.singleWhere(
        (item) => item.sourceId == 'sharefaith',
      );
      expect(story.text, contains('something lasting and beautiful'));
      expect(story.text, isNot(contains('Swift to its close ebbs')));
      expect(abide.stories, hasLength(2));
    });

    test('retains edition-specific credit and tune metadata', () {
      var credited = 0;
      for (final hymn in hymns) {
        final metadata = hymn.metadata!;
        final edition = metadata.editionFor(hymn.version, hymn.number);
        expect(edition, isNotNull,
            reason: '${hymn.version} ${hymn.number} ${hymn.title}');
        if (metadata.authorsFor(hymn.version, hymn.number).isNotEmpty) {
          credited++;
        }
      }
      expect(credited, greaterThan(1150));
    });

    test('preserves the recovered crawler diagnostics as structured data', () {
      final diagnostics = data['scrapeDiagnostics'] as Map<String, dynamic>;
      final duplicateRequests =
          diagnostics['tanBibleDuplicateRequests'] as List<dynamic>;
      expect(duplicateRequests, hasLength(56));
      expect(
        duplicateRequests.fold<int>(
          0,
          (total, item) =>
              total + (item as Map<String, dynamic>)['count'] as int,
        ),
        62,
      );
    });
  });
}
