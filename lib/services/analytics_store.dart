import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'analytics_schema.dart';

typedef BatchSender = Future<({int status, Map<String, dynamic> body})>
    Function(Map<String, dynamic> batch);

String analyticsId() {
  final random = Random.secure();
  return List.generate(
      16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

String analyticsWeek(DateTime date) {
  // Preserve the same local calendar as weekday/time-of-day measurements.
  return DateTime.utc(date.year, date.month, date.day)
      .subtract(Duration(days: date.weekday - 1))
      .toIso8601String()
      .substring(0, 10);
}

/// HTTPS transport is shared by the app and the real end-to-end harness.
/// No cookie jar, device headers, location calls, redirects, or request logging.
class AnalyticsTransport {
  AnalyticsTransport(this.endpoint, {this.testToken});
  final Uri endpoint;
  final String? testToken;
  HttpClient? _client;

  Future<({int status, Map<String, dynamic> body})> send(
      Map<String, dynamic> batch) async {
    if (endpoint.scheme != 'https') throw ArgumentError('HTTPS required');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    _client = client;
    try {
      return await (() async {
        final request = await client.postUrl(endpoint.resolve('/v1/batches'));
        request.followRedirects = false;
        request.headers.contentType = ContentType.json;
        request.headers
            .set(HttpHeaders.userAgentHeader, 'SDAHymnal-Analytics/1');
        if (testToken != null) {
          request.headers.set('x-analytics-test', testToken!);
        }
        request.add(utf8.encode(jsonEncode(batch)));
        final response = await request.close();
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 8192) {
            throw const FormatException('Response too large');
          }
        }
        return (
          status: response.statusCode,
          body: jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>
        );
      })()
          .timeout(const Duration(seconds: 20));
    } finally {
      client.close(force: true);
      if (identical(_client, client)) _client = null;
    }
  }

  void cancel() => _client?.close(force: true);
}

/// Durable bounded counters and immutable outbox, not a log of individual taps.
class AnalyticsStore {
  AnalyticsStore._(
      this.db, this.version, this.platform, this.clock, this.sender);
  final Database db;
  final String version;
  final String platform;
  final DateTime Function() clock;
  final BatchSender sender;
  bool enabled = false;
  String design = 'modern';
  String status = 'Off';
  Future<void> _writes = Future.value();
  Future<void>? _upload;
  int _generation = 0;

  static Future<AnalyticsStore> open(DatabaseFactory factory, String path,
      {required String version,
      required String platform,
      required BatchSender sender,
      DateTime Function()? clock}) async {
    final db = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 2,
            onUpgrade: (db, old, _) async {
              if (old < 2) {
                await _createSeen(db);
                final history = await db.query('history');
                for (final item in history) {
                  final row = jsonDecode(item['row'] as String) as Map;
                  if (row['metric'] == 'hymn_open' &&
                      (row['hymn'] as int) > 0) {
                    await db.insert(
                        'hymns_seen',
                        {
                          'week': item['week'],
                          'edition': row['edition'],
                          'hymn': row['hymn']
                        },
                        conflictAlgorithm: ConflictAlgorithm.ignore);
                  }
                }
              }
            },
            onCreate: (db, _) async {
              await db.execute(
                  'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
              await db.execute(
                  'CREATE TABLE periods (week TEXT PRIMARY KEY, token TEXT NOT NULL)');
              for (final table in ['counters', 'history']) {
                await db.execute(
                    'CREATE TABLE $table (id TEXT PRIMARY KEY, week TEXT NOT NULL, context TEXT NOT NULL, row TEXT NOT NULL, count INTEGER NOT NULL, total INTEGER NOT NULL)');
              }
              await db.execute(
                  'CREATE TABLE outbox (id TEXT PRIMARY KEY, week TEXT NOT NULL, body TEXT NOT NULL)');
              await _createSeen(db);
            }));
    final store =
        AnalyticsStore._(db, version, platform, clock ?? DateTime.now, sender);
    final savedChoice = await store._get('enabled');
    if (savedChoice == null) {
      // Enable on first use, with a full week before the first upload.
      // A saved opt-out survives upgrades and must never be overridden.
      await store.setEnabled(true);
    } else {
      store.enabled = savedChoice == '1';
    }
    store.status = store.enabled ? 'Waiting for weekly upload' : 'Off';
    return store;
  }

  Future<String?> _get(String key) async {
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  static Future<void> _createSeen(DatabaseExecutor db) => db.execute(
      'CREATE TABLE hymns_seen (week TEXT NOT NULL, edition TEXT NOT NULL, hymn INTEGER NOT NULL, PRIMARY KEY (week, edition, hymn))');

  Future<void> _put(DatabaseExecutor db, String key, Object value) async {
    await db.insert('meta', {'key': key, 'value': '$value'},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> setEnabled(bool value) {
    enabled = value; // stop capture immediately, including queued UI callbacks
    _generation++;
    status = value ? 'Waiting for weekly upload' : 'Off';
    return _serial(() => db.transaction((tx) async {
          if (!value) {
            for (final table in [
              'periods',
              'counters',
              'history',
              'outbox',
              'hymns_seen',
              'meta'
            ]) {
              await tx.delete(table);
            }
          }
          await _put(tx, 'enabled', value ? 1 : 0);
          if (value) {
            // Spread weekly upload sessions rather than synchronize every Sabbath.
            await _put(
                tx,
                'due',
                clock().millisecondsSinceEpoch +
                    const Duration(days: 7).inMilliseconds +
                    Random.secure().nextInt(21600000));
            await _put(tx, 'failures', 0);
          }
        }));
  }

  Future<void> record(String metric,
      {String variant = '', int hymn = 0, String edition = '', int total = 0}) {
    if (!enabled) return Future.value();
    if (!(analyticsVariants[metric]?.contains(variant) ?? false) ||
        hymn < 0 ||
        hymn > (edition == 'new' ? 695 : 703) ||
        total < 0 ||
        total > 3600000 ||
        !['', 'new', 'old'].contains(edition) ||
        (hymn == 0) != (edition == '')) {
      return Future.error(ArgumentError('Invalid analytics measurement'));
    }
    final now = clock();
    final week = analyticsWeek(now);
    final context = jsonEncode({
      'week': week,
      'version': version,
      'platform': platform,
      'design': design
    });
    final row = jsonEncode({
      'metric': metric,
      'variant': variant,
      'hymn': hymn,
      'edition': edition,
      'weekday': now.weekday,
      'time': now.hour < 6
          ? 'night'
          : now.hour < 12
              ? 'morning'
              : now.hour < 18
                  ? 'afternoon'
                  : 'evening'
    });
    final generation = _generation;
    return _serial(() async {
      if (!enabled || generation != _generation) return;
      await db.transaction((tx) async {
        final measurements = <(String, int)>[(row, total)];
        if (metric == 'hymn_open' && hymn > 0) {
          final seen = await tx.query('hymns_seen',
              where: 'week = ? AND edition = ? AND hymn = ?',
              whereArgs: [week, edition, hymn]);
          if (seen.isNotEmpty) {
            measurements.add((
              jsonEncode({
                ...jsonDecode(row) as Map<String, dynamic>,
                'metric': 'hymn_repeat',
                'variant': ''
              }),
              0
            ));
          } else {
            await tx.insert(
                'hymns_seen', {'week': week, 'edition': edition, 'hymn': hymn});
          }
          await tx.delete('hymns_seen', where: 'week < ?', whereArgs: [
            analyticsWeek(now.subtract(const Duration(days: 90)))
          ]);
        }
        for (final (measurement, value) in measurements) {
          final id =
              sha256.convert(utf8.encode(context + measurement)).toString();
          for (final table in ['counters', 'history']) {
            await tx.rawInsert(
                'INSERT INTO $table (id, week, context, row, count, total) VALUES (?, ?, ?, ?, 1, ?) '
                'ON CONFLICT(id) DO UPDATE SET count = MIN(count + 1, 100000), total = MIN(total + excluded.total, 360000000000)',
                [id, week, context, measurement, value]);
            // Protect app storage even under pathological event/dimension volume.
            await tx.rawDelete(
                'DELETE FROM $table WHERE id IN (SELECT id FROM $table ORDER BY week DESC, rowid DESC LIMIT -1 OFFSET 10000)');
          }
        }
      });
    });
  }

  Future<void> _seal() => _serial(() => db.transaction((tx) async {
        // Weeks older than this are not accepted by the server. Prune before seal.
        final oldest = clock()
            .toUtc()
            .subtract(const Duration(days: 83))
            .toIso8601String()
            .substring(0, 10);
        for (final table in [
          'counters',
          'history',
          'periods',
          'outbox',
          'hymns_seen'
        ]) {
          await tx.delete(table, where: 'week < ?', whereArgs: [oldest]);
        }
        final rows = await tx.query('counters', orderBy: 'context, id');
        int index = 0;
        while (index < rows.length) {
          final context = rows[index]['context'] as String;
          final group = <Map<String, Object?>>[];
          while (index < rows.length &&
              rows[index]['context'] == context &&
              group.length < 40) {
            group.add(rows[index++]);
          }
          final header = jsonDecode(context) as Map<String, dynamic>;
          final week = header['week'] as String;
          final tokens =
              await tx.query('periods', where: 'week = ?', whereArgs: [week]);
          final token =
              tokens.isEmpty ? analyticsId() : tokens.first['token'] as String;
          if (tokens.isEmpty) {
            await tx.insert('periods', {'week': week, 'token': token});
          }
          final id = analyticsId();
          final body = {
            'schema': 1,
            'batch_id': id,
            'token': token,
            ...header,
            'rows': [
              for (final r in group)
                {
                  ...jsonDecode(r['row'] as String) as Map<String, dynamic>,
                  'count': r['count'],
                  'total': r['total']
                }
            ]
          };
          await tx.insert(
              'outbox', {'id': id, 'week': week, 'body': jsonEncode(body)});
          for (final r in group) {
            await tx.delete('counters', where: 'id = ?', whereArgs: [r['id']]);
          }
        }
        await tx.rawDelete(
            'DELETE FROM outbox WHERE id IN (SELECT id FROM outbox ORDER BY week DESC, rowid DESC LIMIT -1 OFFSET 500)');
      }));

  Future<void> uploadIfDue({bool force = false}) {
    if (_upload != null) return _upload!;
    return _upload = _uploadDue(force).whenComplete(() => _upload = null);
  }

  Future<void> _uploadDue(bool force) async {
    if (!enabled) return;
    final generation = _generation;
    await _writes;
    final due = int.tryParse(await _get('due') ?? '') ??
        clock().millisecondsSinceEpoch + const Duration(days: 7).inMilliseconds;
    if (!enabled || generation != _generation) return;
    if (!force && clock().millisecondsSinceEpoch < due) return;
    status = 'Uploading';
    try {
      await _seal();
      if (!enabled || generation != _generation) return;
      // Bounded work per foreground opportunity. A backlog drains on later resumes.
      final batches =
          await db.query('outbox', orderBy: 'week, rowid', limit: 20);
      for (final batch in batches) {
        if (!enabled || generation != _generation) return;
        final body =
            jsonDecode(batch['body'] as String) as Map<String, dynamic>;
        final response = await sender(body);
        if (!enabled || generation != _generation) return;
        if (response.status != 200 ||
            response.body['accepted'] != batch['id']) {
          throw const FormatException('Batch not acknowledged');
        }
        await _serial(() async {
          if (!enabled || generation != _generation) return;
          await db.delete('outbox', where: 'id = ?', whereArgs: [batch['id']]);
        });
      }
      await _serial(() async {
        if (!enabled || generation != _generation) return;
        final empty = await db.transaction((tx) async {
          final remaining = await tx.query('outbox', columns: ['id'], limit: 1);
          await _put(
              tx,
              'due',
              clock().millisecondsSinceEpoch +
                  (remaining.isEmpty
                      ? const Duration(days: 7).inMilliseconds +
                          Random.secure().nextInt(21600000)
                      : const Duration(minutes: 15).inMilliseconds));
          await _put(tx, 'failures', 0);
          await _put(tx, 'last_upload', clock().toUtc().toIso8601String());
          return remaining.isEmpty;
        });
        if (!enabled || generation != _generation) return;
        status = empty ? 'Weekly statistics sent' : 'More statistics queued';
      });
    } catch (_) {
      await _serial(() async {
        if (!enabled || generation != _generation) return;
        await db.transaction((tx) async {
          final rows =
              await tx.query('meta', where: 'key = ?', whereArgs: ['failures']);
          final failures = min(
              8,
              (int.tryParse(
                          rows.isEmpty ? '' : rows.first['value'] as String) ??
                      0) +
                  1);
          await _put(tx, 'failures', failures);
          await _put(
              tx,
              'due',
              clock().millisecondsSinceEpoch +
                  min(86400000, 900000 * (1 << failures)) +
                  Random.secure().nextInt(300000));
        });
        if (!enabled || generation != _generation) return;
        status = 'Saved offline; upload will retry later';
      });
    }
  }

  Future<List<Map<String, Object?>>> pending() async {
    await _writes;
    return db.query('outbox', orderBy: 'week, rowid');
  }

  Future<void> close() async {
    await _upload;
    await _writes;
    await db.close();
  }
}
