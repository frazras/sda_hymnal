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
      expect(allStories, hasLength(264));
      expect(
        allStories.where((story) => story['sourceId'] == 'sharefaith'),
        hasLength(70),
      );
      expect(
        allStories.where((story) => story['sourceId'] == 'tanbible'),
        hasLength(194),
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

    test('retains inline text recovered from every attached ShareFaith story',
        () {
      final shareFaithStories = <String, String>{
        for (final hymn in data['hymns'] as List<dynamic>)
          for (final story
              in (hymn as Map<String, dynamic>)['stories'] as List<dynamic>? ??
                  const [])
            if ((story as Map<String, dynamic>)['sourceId'] == 'sharefaith')
              story['id'] as String: story['text'] as String,
      };
      const recoveredText = <String, String>{
        'sharefaith-12-all-creatures-of-our-god-and-king':
            'The heavens declare the glory of God',
        'sharefaith-1-abide-with-me': 'written copy of Abide With Me',
        'sharefaith-47-o-worship-the-king': 'book titled Sacred Poems',
        'sharefaith-67-great-is-thy-faithfulness':
            'They are new every morning: great is Thy faithfulness.',
        'sharefaith-21-when-i-survey-the-wondrous-cross':
            'When I Survey the Wondrous Cross',
        'sharefaith-56-jesus-paid-it-all':
            'The words to the song Jesus Paid It All',
        'sharefaith-70-face-to-face': 'All for me the Savior suffered',
        'sharefaith-11-all-hail-the-power-of-jesus':
            'began to play and sing All Hail',
        'sharefaith-46-o-for-a-thousand-tongues-to-sing':
            'Christ the Lord is Risen Today',
        'sharefaith-24-turn-your-eyes-upon-jesus': 'Seattle Post',
        'sharefaith-53-lord-im-coming-home': "new song Lord I'm Coming Home",
        'sharefaith-54-just-as-i-am': 'Just As I Am has been around since 1835',
        'sharefaith-51-my-jesus-i-love-thee':
            "Featherson's poem My Jesus I Love Thee",
        'sharefaith-14-id-rather-have-jesus': "I'd Rather Have Jesus",
        'sharefaith-33-take-my-life-and-let-it-be':
            'I Gave My Life for Thee and God Will Take Care of You',
        'sharefaith-2-come-thou-fount-of-every-blessing':
            'wrote Come Thou Fount of Every Blessing',
        'sharefaith-15-i-will-sing-of-my-redeemer':
            'Almost Persuaded, Let the Lower Lights Be Burning',
        'sharefaith-42-shall-we-gather-at-the-river':
            'I Need Thee Every Hour and Low in the Grave He Lay',
        'sharefaith-5-blessed-assurance': 'tune was called Assurance',
        'sharefaith-34-sunshine-in-my-soul': 'hymn Sunshine in My Soul',
        'sharefaith-50-nearer-my-god-to-thee':
            'Nearer My God to Thee was written',
        'sharefaith-60-in-the-garden': 'lyrics to In The Garden',
        'sharefaith-55-jesus-lover-of-my-soul':
            'prayer of trust in God as his refuge',
        'sharefaith-22-what-a-friend-we-have-in-jesus':
            'poems entitled What a Friend We Have in Jesus',
        'sharefaith-25-tis-so-sweet-to-trust-in-jesus':
            'prompted the lyrics of Tis So Sweet to Trust in Jesus',
        'sharefaith-23-under-his-wings':
            'including Hiding in Thee, and Ring the Bells of Heaven',
        'sharefaith-7-be-thou-my-vision': 'words to Be Thou My Vision',
        'sharefaith-69-for-the-beauty-of-the-earth':
            'first published as The Sacrifice of Praise',
        'sharefaith-26-this-little-light-of-mine':
            'song This Little Light of Mine in 1920',
        'sharefaith-9-am-i-a-soldier-of-the-cross':
            '“Watch ye, stand fast in the faith',
        'sharefaith-41-stand-up-stand-up-for-jesus':
            '“Go now ye that are men and serve the Lord”',
        'sharefaith-13-alas-and-did-my-savior-bleed':
            'including Joy to the World and Alas and Did My Savior Bleed',
        'sharefaith-10-almost-persuaded':
            'including The Light of the World is Jesus and Dare to Be a Daniel',
        'sharefaith-48-o-happy-day-that-fixed-my-choice':
            'including the very popular O Happy Day',
        'sharefaith-59-it-is-well-with-my-soul':
            'those now famous words, When sorrow like sea billows roll',
      };

      expect(shareFaithStories, hasLength(recoveredText.length));
      for (final entry in recoveredText.entries) {
        expect(
          shareFaithStories[entry.key],
          contains(entry.value),
          reason: entry.key,
        );
      }
    });

    test('keeps the Because He Lives lead-in with its continuation', () {
      final metadata = catalog.forHymn('new', 526)!;
      final story = metadata.stories.singleWhere(
        (item) => item.id == 'tanbible-191-because-he-lives',
      );
      final storyText = story.text!;
      expect(storyText,
          contains('came out of their personal bout with darkness:'));
      expect(storyText, contains('I knew I could have that baby'));
      expect(storyText.trim(), endsWith('—Gloria Gaither'));
      expect(storyText, isNot(contains('In\nthe late 1960s')));
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
