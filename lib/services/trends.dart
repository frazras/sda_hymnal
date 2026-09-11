import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_endpoint.dart';

class SongStatistic {
  const SongStatistic(this.hymn, this.edition, this.title, this.count);
  final int hymn;
  final String edition;
  final String title;
  final int count;
  factory SongStatistic.parse(Map<String, dynamic> value) {
    final hymn = value['hymn'] as int;
    final edition = value['edition'] as String;
    final count = value['count'] as int;
    if (!['old', 'new'].contains(edition) ||
        hymn < 1 ||
        hymn > (edition == 'new' ? 695 : 703) ||
        count < 0) {
      throw const FormatException('Invalid song statistic');
    }
    return SongStatistic(hymn, edition, value['title'] as String, count);
  }
}

class TrendsPeriod {
  TrendsPeriod(Map<String, dynamic> value)
      : start = DateTime.parse(value['start'] as String),
        end = DateTime.parse(value['end'] as String),
        songs = _songs(value['top_songs']),
        repeats = _songs(value['repeat_songs']),
        favorites = _songs(value['favorites']),
        times = _bars(value['times']),
        weekdays = _bars(value['weekdays']),
        countries = {
          for (final country in value['countries'] as List)
            country['country'] as String: _songs(country['songs'])
        };
  final DateTime start, end;
  final List<SongStatistic> songs, repeats, favorites;
  final Map<String, int> times, weekdays;
  final Map<String, List<SongStatistic>> countries;
  static List<SongStatistic> _songs(dynamic values) => (values as List)
      .map((e) => SongStatistic.parse(e as Map<String, dynamic>))
      .toList();
  static Map<String, int> _bars(dynamic values) => {
        for (final row in values as List)
          row['label'] as String: _count(row['count'])
      };
  static int _count(dynamic value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid count');
    }
    return value;
  }
}

class TrendsSnapshot {
  TrendsSnapshot.parse(String source, {this.offline = false}) {
    final value = jsonDecode(source) as Map<String, dynamic>;
    if (value['schema'] != 2 || value['minimum_contributors'] != 20) {
      throw const FormatException('Unsupported community report');
    }
    generated = DateTime.parse(value['generated'] as String);
    periods = {
      for (final period in ['1', '4', '8'])
        period: TrendsPeriod(value['periods'][period] as Map<String, dynamic>)
    };
  }
  late final DateTime generated;
  late final Map<String, TrendsPeriod> periods;
  final bool offline;
}

/// The same public snapshot for everyone, including people who opted out.
/// Only the public report is cached; no login, identifier, or location request.
class TrendsRepository {
  static const cacheKey = 'communityTrendsV2';
  static const fetchedKey = 'communityTrendsFetchedV2';
  Future<TrendsSnapshot> load({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    TrendsSnapshot? previous;
    try {
      if (cached != null) {
        previous = TrendsSnapshot.parse(cached, offline: true);
      }
    } catch (_) {
      await prefs.remove(cacheKey);
    }
    final fetched = prefs.getInt(fetchedKey) ?? 0;
    if (!force &&
        previous != null &&
        DateTime.now().millisecondsSinceEpoch - fetched <
            const Duration(hours: 24).inMilliseconds) {
      return TrendsSnapshot.parse(cached!);
    }
    try {
      final source = await fetch();
      final report = TrendsSnapshot.parse(source);
      await prefs.setString(cacheKey, source);
      await prefs.setInt(fetchedKey, DateTime.now().millisecondsSinceEpoch);
      return report;
    } catch (_) {
      if (previous != null) return previous;
      rethrow;
    }
  }

  Future<String> fetch() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final request =
            await client.getUrl(Uri.parse('$analyticsEndpoint/v1/trends'));
        request.followRedirects = false;
        request.headers
            .set(HttpHeaders.userAgentHeader, 'SDAHymnal-Community/1');
        final response = await request.close();
        if (response.statusCode != 200) {
          throw const HttpException('Report unavailable');
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 4 * 1024 * 1024) {
            throw const FormatException('Report too large');
          }
        }
        return utf8.decode(bytes);
      })()
          .timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }
}
