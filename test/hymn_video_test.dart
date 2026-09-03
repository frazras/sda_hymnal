import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdahymnal/models/hymn_video.dart';
import 'package:sdahymnal/services/api.dart';

void main() {
  final videoRaw = File('assets/hymn_videos.json').readAsStringSync();
  final data = json.decode(videoRaw) as Map<String, dynamic>;
  final videos = HymnVideoCatalog.fromJson(videoRaw);
  final hymns = HymnApi.allHymnsFromJson(
    File('assets/hymns.json').readAsStringSync(),
    videos: videos,
  );

  group('hymn video catalog', () {
    test('provides a playable video for every New Hymnal song', () {
      final modern = hymns.where((hymn) => hymn.version == 'new').toList();
      expect(modern, hasLength(695));
      for (final hymn in modern) {
        expect(hymn.video, isNotNull,
            reason: 'New ${hymn.number}: ${hymn.title}');
      }
    });

    test('uses valid IDs and references only declared videos', () {
      final declared = <String>{};
      for (final raw in data['videos'] as List<dynamic>) {
        final video = raw as Map<String, dynamic>;
        final id = video['youtubeVideoId'] as String;
        expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{11}$')));
        expect(video['priority'], inInclusiveRange(1, 4));
        declared.add(id);
      }
      for (final id in (data['lookup'] as Map<String, dynamic>).values) {
        expect(declared, contains(id));
      }
      expect(data['statistics'], containsPair('assignedReferences', 1387));
      expect(data['statistics'], containsPair('unmatchedReferences', 11));
    });

    test('prioritizes Amazing Worship TV for Rejoice Ye Pure in Heart', () {
      final old = videos.forHymn('old', 17)!;
      final modern = videos.forHymn('new', 27)!;
      expect(old.youtubeVideoId, modern.youtubeVideoId);
      expect(old.youtubeVideoId, 'eqg3Sv4Nicg');
      expect(old.channel, 'Amazing Worship TV');
      expect(old.priority, 1);
    });

    test('contains no external PDF destinations', () {
      final metadata = File('assets/hymn_metadata.json').readAsStringSync();
      expect(metadata.toLowerCase(), isNot(contains('.pdf')));
      expect(videoRaw.toLowerCase(), isNot(contains('.pdf')));
    });
  });
}
