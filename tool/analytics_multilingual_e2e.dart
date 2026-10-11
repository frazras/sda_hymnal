// Real app counter storage and HTTPS transport, isolated from production totals.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sdahymnal/services/analytics_store.dart';

Future<void> main() async {
  sqfliteFfiInit();
  final state =
      jsonDecode(await File('build/analytics/deployment.json').readAsString())
          as Map;
  final transport = AnalyticsTransport(Uri.parse(state['Endpoint'] as String),
      testToken: state['TestSecret'] as String);
  final directory =
      await Directory.systemTemp.createTemp('native_hymnal_analytics_');
  Map<String, dynamic>? sent;
  bool offline = true;
  Future<AnalyticsStore> open() => AnalyticsStore.open(
          databaseFactoryFfi, '${directory.path}/counters.sqlite',
          version: '0.4.${Random.secure().nextInt(99999)}',
          platform: 'ios', sender: (batch) async {
        if (offline) throw const SocketException('simulated offline');
        sent = batch;
        return transport.send(batch);
      });
  var store = await open();
  try {
    await store.record('hymn_open',
        variant: 'keypad', hymn: 303, edition: 'sda-es-2009');
    await store.record('hymn_open',
        variant: 'keypad', hymn: 303, edition: 'sda-es-1962');
    await store.record('hymn_open', variant: 'keypad', hymn: 1, edition: 'new');
    await store.uploadIfDue(force: true);
    final saved = (await store.pending()).single['body'];
    await store.close();
    store = await open();
    if ((await store.pending()).single['body'] != saved) {
      throw StateError('Batch changed across restart');
    }
    offline = false;
    await store.uploadIfDue(force: true);
    if ((await store.pending()).isNotEmpty || sent?['schema'] != 2) {
      throw StateError('Native batch not acknowledged');
    }
    final replay = await transport.send(sent!);
    if (replay.status != 200 || replay.body['duplicate'] != true) {
      throw StateError('Retry not deduplicated');
    }
    final invalid = jsonDecode(jsonEncode(sent)) as Map<String, dynamic>;
    invalid['batch_id'] = analyticsId();
    (invalid['rows'] as List).first['book_id'] = 'sda-es-unknown';
    if ((await transport.send(invalid)).status != 400) {
      throw StateError('Unknown book accepted');
    }
    stdout.writeln(
        'PASS: app SQLite counters, offline restart, mixed schema-2 HTTPS upload, retry and unknown-book rejection.');
  } finally {
    await store.close();
    await directory.delete(recursive: true);
  }
}
