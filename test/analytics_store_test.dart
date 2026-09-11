import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sdahymnal/services/analytics_store.dart';

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late DateTime now;
  late List<Map<String, dynamic>> sent;
  late bool offline;
  late AnalyticsStore store;

  Future<AnalyticsStore> open({BatchSender? sender}) => AnalyticsStore.open(
      databaseFactoryFfi, '${directory.path}/analytics.sqlite',
      version: '4.2.0',
      platform: 'android',
      clock: () => now,
      sender: sender ??
          (batch) async {
            sent.add(batch);
            if (offline) throw const SocketException('offline');
            return (
              status: 200,
              body: <String, dynamic>{'accepted': batch['batch_id']}
            );
          });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('hymnal_analytics_test_');
    now = DateTime.utc(2026, 9, 6, 12);
    sent = [];
    offline = false;
    store = await open();
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test('on by default; first upload waits a week; explicit opt-out persists',
      () async {
    expect(store.enabled, isTrue);
    await store.record('hymn_open', variant: 'keypad', hymn: 1, edition: 'new');
    await store.record('app_session');
    await store.uploadIfDue();
    expect(sent, isEmpty);
    now = now.add(const Duration(days: 8));
    await store.uploadIfDue();
    expect(sent, hasLength(1));
    await store.setEnabled(false);
    await store.close();
    store = await open();
    expect(store.enabled, isFalse);
    await store.record('app_session');
    await store.uploadIfDue(force: true);
    expect(sent, hasLength(1));
    expect(await store.db.query('history'), isEmpty);
    await store.uploadIfDue();
    expect(sent, hasLength(1));
  });

  test('offline restart preserves exact immutable batch and newer counters',
      () async {
    await store.setEnabled(true);
    await store.record('hymn_open', variant: 'keypad', hymn: 1, edition: 'new');
    offline = true;
    await store.uploadIfDue(force: true);
    final original = jsonEncode(sent.single);
    await store.close();
    store = await open();
    expect(store.enabled, isTrue);
    await store.record('play_attempt',
        variant: 'classic', hymn: 1, edition: 'new');
    await store.uploadIfDue(); // backoff survives restart
    expect(sent, hasLength(1));
    offline = false;
    await store.uploadIfDue(force: true);
    expect(jsonEncode(sent[1]), original);
    expect(sent, hasLength(3));
    expect(await store.pending(), isEmpty);
    expect(await store.db.query('history'), hasLength(2));
  });

  test('aggregation and bounded chunks preserve all counts', () async {
    await store.setEnabled(true);
    for (int i = 1; i <= 81; i++) {
      await store.record('hymn_open',
          variant: 'search', hymn: i, edition: 'new');
    }
    await store.record('hymn_open', variant: 'search', hymn: 1, edition: 'new');
    await store.uploadIfDue(force: true);
    expect(sent.map((b) => (b['rows'] as List).length), [40, 40, 2]);
    final rows = sent.expand((b) => (b['rows'] as List).cast<Map>());
    expect(
        rows
            .where((r) => r['metric'] == 'hymn_open')
            .fold<int>(0, (sum, row) => sum + (row['count'] as int)),
        82);
    expect(rows.singleWhere((r) => r['metric'] == 'hymn_repeat')['count'], 1);
    expect(sent.map((b) => b['token']).toSet(), hasLength(1));
  });

  test('reporting weeks rotate contributor token and schema rejects text',
      () async {
    await store.setEnabled(true);
    await expectLater(store.record('raw_search', variant: 'private text'),
        throwsArgumentError);
    await expectLater(store.record('search_results', variant: 'private text'),
        throwsArgumentError);
    await store.record('app_session');
    await store.uploadIfDue(force: true);
    now = now.add(const Duration(days: 8));
    await store.record('app_session');
    await store.uploadIfDue(force: true);
    expect(sent[0]['token'], isNot(sent[1]['token']));
    expect(sent[0].keys.toSet(), {
      'schema',
      'batch_id',
      'week',
      'token',
      'version',
      'platform',
      'design',
      'rows'
    });
  });

  test('repeat opens survive restarts, separate editions, and reset weekly',
      () async {
    await store.record('hymn_open', variant: 'keypad', hymn: 1, edition: 'new');
    await store.close();
    store = await open();
    await store.record('hymn_open', variant: 'search', hymn: 1, edition: 'new');
    await store.record('hymn_open', variant: 'keypad', hymn: 1, edition: 'old');
    await store.uploadIfDue(force: true);
    final rows = sent.expand((b) => b['rows'] as List);
    expect(rows.where((r) => r['metric'] == 'hymn_repeat').single['count'], 1);
    now = now.add(const Duration(days: 8));
    await store.record('hymn_open',
        variant: 'statistics', hymn: 1, edition: 'new');
    await store.uploadIfDue(force: true);
    expect(
        (sent.last['rows'] as List).where((r) => r['metric'] == 'hymn_repeat'),
        isEmpty);
    await store.setEnabled(false);
    expect(await store.db.query('hymns_seen'), isEmpty);
    await store.setEnabled(true);
    await store.record('hymn_open', variant: 'keypad', hymn: 1, edition: 'new');
    await store.uploadIfDue(force: true);
    expect(
        (sent.last['rows'] as List).where((r) => r['metric'] == 'hymn_repeat'),
        isEmpty);
  });

  test('concurrent sync shares one request; disabling clears pending data',
      () async {
    await store.close();
    final started = Completer<void>();
    final reply = Completer<({int status, Map<String, dynamic> body})>();
    String? batchId;
    int requests = 0;
    store = await open(sender: (batch) {
      requests++;
      batchId = batch['batch_id'] as String;
      started.complete();
      return reply.future;
    });
    await store.setEnabled(true);
    await store.record('app_session');
    final first = store.uploadIfDue(force: true);
    final second = store.uploadIfDue(force: true);
    await started.future;
    await store.setEnabled(false);
    reply.complete((status: 200, body: {'accepted': batchId}));
    await Future.wait([first, second]);
    expect(requests, 1);
    expect(await store.pending(), isEmpty);
    expect(await store.db.query('periods'), isEmpty);
    expect(await store.db.query('history'), isEmpty);
    expect(store.status, 'Off');
  });

  test('wrong acknowledgement keeps batch; expired backlog is removed',
      () async {
    await store.close();
    store = await open(
        sender: (_) async => (status: 200, body: {'accepted': 'wrong'}));
    await store.setEnabled(true);
    await store.record('app_session');
    await store.uploadIfDue(force: true);
    expect(await store.pending(), hasLength(1));
    now = now.add(const Duration(days: 100));
    await store.uploadIfDue(force: true);
    expect(await store.pending(), isEmpty);
  });
}
