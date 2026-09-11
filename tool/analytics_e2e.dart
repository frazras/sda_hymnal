// Real SQLite -> shared app transport -> live CloudFront/Lambda.
// Uses a protected test namespace; never changes production statistics.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sdahymnal/services/analytics_store.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  sqfliteFfiInit();
  final state =
      jsonDecode(await File('build/analytics/deployment.json').readAsString())
          as Map<String, dynamic>;
  final transport = AnalyticsTransport(Uri.parse(state['Endpoint'] as String),
      testToken: state['TestSecret'] as String);
  final directory =
      await Directory.systemTemp.createTemp('sdahymnal_analytics_e2e_');
  final version = '0.0.${Random.secure().nextInt(99999)}';
  Map<String, dynamic>? original;
  final acknowledgements = <Map<String, dynamic>>[];
  bool offline = true;
  Future<AnalyticsStore> open() => AnalyticsStore.open(
          databaseFactoryFfi, '${directory.path}/analytics.sqlite',
          version: version, platform: 'android', sender: (batch) async {
        original ??= batch;
        if (offline) throw const SocketException('simulated offline');
        final reply = await transport.send(batch);
        if (reply.status != 200) {
          stderr.writeln('Collector response: ${reply.status} ${reply.body}');
        }
        acknowledgements.add(reply.body);
        return reply;
      });
  var store = await open();
  try {
    check(
        store.enabled, 'Fresh installation must enable statistics by default');
    for (int i = 0; i < 3; i++) {
      await store.record('hymn_open',
          variant: 'keypad', hymn: 1, edition: 'new');
    }
    await store.record('play_attempt',
        variant: 'classic', hymn: 1, edition: 'new');
    await store.record('play_start_ms', total: 250);
    await store.uploadIfDue(force: true);
    check((await store.pending()).length == 1, 'Offline batch must persist');
    final saved = (await store.pending()).single['body'];
    await store.close();
    store = await open();
    check((await store.pending()).single['body'] == saved,
        'Restart must preserve exact batch');
    offline = false;
    await store.uploadIfDue(force: true);
    check((await store.pending()).isEmpty,
        'Live submission must be acknowledged: ${store.status}');
    final duplicate = await transport.send(original!);
    check(duplicate.status == 200 && duplicate.body['duplicate'] == true,
        'Retry must be deduplicated');
    final conflict = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    (conflict['rows'] as List).first['count'] = 100;
    check((await transport.send(conflict)).status == 409,
        'Changed payload must be rejected');
    final invalid = {
      ...original!,
      'batch_id': analyticsId(),
      'search_text': 'must never be stored'
    };
    check((await transport.send(invalid)).status == 400,
        'Unapproved fields must be rejected');
    final report = {
      'version': version,
      'week': original!['week'],
      'batch_id': original!['batch_id'],
      'endpoint': state['Endpoint'],
      'checks': [
        'offline persistence',
        'restart recovery',
        'HTTPS submission',
        'duplicate retry',
        'payload conflict',
        'schema rejection'
      ],
      'expected': original!['rows'],
      'acknowledgement': acknowledgements.single
    };
    await File('build/analytics/e2e-submission.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(
        'PASS: SQLite restart -> live endpoint -> acknowledged; duplicate and invalid submissions handled.');
    stdout.writeln('Verification report: build/analytics/e2e-submission.json');
  } finally {
    await store.close();
    await directory.delete(recursive: true);
  }
}
