import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../models/release_notes.dart';
import 'analytics_endpoint.dart';
import 'analytics_store.dart';

/// UI-safe facade: analytics must never prevent reading or music playback.
class AppAnalytics extends ChangeNotifier {
  AppAnalytics._();
  static final instance = AppAnalytics._();
  AnalyticsStore? _store;
  AnalyticsTransport? _transport;
  Timer? _timer;
  bool _foreground = true;
  DateTime _checkpointAt = DateTime.now();
  DateTime? _backgroundAt;
  String _screen = 'numbers';
  int _hymn = 0;
  String _edition = '';
  bool get enabled => _store?.enabled ?? false;
  String get status => _store?.status ?? 'Statistics unavailable';
  bool get available => _store != null;

  Future<void> initialize(
      {String design = 'modern',
      String? testToken,
      String? testVersion}) async {
    if (!kDebugMode && (testToken != null || testVersion != null)) {
      throw StateError('Test configuration is only supported in debug builds');
    }
    if (_store != null || analyticsEndpoint.isEmpty) return;
    try {
      final path = await const MethodChannel('sdahymnal/analytics_storage')
          .invokeMethod<String>('directory');
      if (path == null) return;
      _transport = AnalyticsTransport(Uri.parse(analyticsEndpoint),
          testToken: testToken);
      _store = await AnalyticsStore.open(
          databaseFactory, '$path/analytics.sqlite',
          version: testVersion ?? appReleaseVersion,
          platform: Platform.isIOS ? 'ios' : 'android',
          sender: _transport!.send);
      _store!.design = design;
      _checkpointAt = DateTime.now();
      event('app_session');
      event('screen_view', variant: _screen);
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        _checkpoint();
        if (_foreground) unawaited(_upload());
      });
      unawaited(_upload());
      notifyListeners();
    } catch (_) {
      // Storage/channel failure leaves analytics disabled, never blocks startup.
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final store = _store;
    if (store == null) return;
    if (!enabled) _transport?.cancel();
    try {
      await store.setEnabled(enabled);
      _checkpointAt = DateTime.now();
      if (enabled) {
        event('app_session');
        event('screen_view', variant: _screen);
      }
    } catch (_) {
      store.enabled = false;
      store.status = 'Statistics storage unavailable';
    }
    notifyListeners();
  }

  void event(String metric,
      {String variant = '', int hymn = 0, String edition = '', int total = 0}) {
    // The deployed collector still accepts English aliases only. Do not emit
    // foreign book IDs or mislabel them as English until its schema is upgraded.
    if (edition.isNotEmpty && edition != 'new' && edition != 'old') return;
    final store = _store;
    if (store == null || !store.enabled) return;
    unawaited(store
        .record(metric,
            variant: variant, hymn: hymn, edition: edition, total: total)
        .catchError((Object _) {}));
  }

  void setDesign(String design) {
    if (_store != null) _store!.design = design;
  }

  void screen(String screen) {
    _checkpoint();
    _screen = screen;
    event('screen_view', variant: screen);
  }

  void openHymn(int n, String edition, String source) {
    _checkpoint();
    _hymn = n;
    _edition = edition;
    event('hymn_open', hymn: n, edition: edition, variant: source);
  }

  void closeHymn(int n, String edition) {
    if (n != _hymn || edition != _edition) return;
    _checkpoint();
    _hymn = 0;
    _edition = '';
  }

  void lifecycle(bool foreground) {
    if (_foreground == foreground) return;
    _checkpoint();
    _foreground = foreground;
    final now = DateTime.now();
    if (foreground) {
      if (_backgroundAt != null &&
          now.difference(_backgroundAt!) >= const Duration(minutes: 30)) {
        event('app_session');
      }
      unawaited(_upload());
    } else {
      _backgroundAt = now;
    }
    _checkpointAt = now;
  }

  void _checkpoint() {
    final now = DateTime.now();
    final seconds = now.difference(_checkpointAt).inSeconds.clamp(0, 60);
    _checkpointAt = now;
    if (!_foreground || !enabled || seconds == 0) return;
    event('app_active_seconds', total: seconds);
    if (_hymn > 0) {
      event('hymn_read_seconds',
          hymn: _hymn, edition: _edition, total: seconds);
    } else {
      event('screen_seconds', variant: _screen, total: seconds);
    }
  }

  Future<void> _upload() async {
    try {
      final before = status;
      await _store?.uploadIfDue();
      if (status != before) notifyListeners();
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> submitForTesting() async {
    if (!kDebugMode) throw StateError('Debug only');
    await _store?.uploadIfDue(force: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _transport?.cancel();
    super.dispose();
  }
}
