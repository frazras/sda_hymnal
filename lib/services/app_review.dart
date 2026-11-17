import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'midi_player.dart';

/// Requests a native review only at a quiet routine ending. Store APIs do not
/// reveal whether their dialog appeared, so every request starts the cooldown.
class AppReviewService {
  AppReviewService({
    DateTime Function()? now,
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
    Future<void> Function()? openStore,
    bool Function()? isPlaybackIdle,
  })  : _now = now ?? DateTime.now,
        _isAvailable = isAvailable ?? InAppReview.instance.isAvailable,
        _requestReview = requestReview ?? InAppReview.instance.requestReview,
        _openStore = openStore ??
            (() => InAppReview.instance.openStoreListing(
                appStoreId: appStoreId.isEmpty ? null : appStoreId)),
        _isPlaybackIdle =
            isPlaybackIdle ?? (() => MidiPlayer.instance.current.value == null);

  static final instance = AppReviewService();
  static const lastRequestKey = 'appReviewLastRequestMs';
  static const cooldown = Duration(days: 30);
  static const appStoreId = String.fromEnvironment('APP_STORE_ID');

  final DateTime Function() _now;
  final Future<bool> Function() _isAvailable;
  final Future<void> Function() _requestReview;
  final Future<void> Function() _openStore;
  final bool Function() _isPlaybackIdle;
  final Set<Object> _activities = {};
  final Map<BuildContext, Map<Timer, Completer<bool>>> _pending = {};
  bool _requesting = false;
  int _activityGeneration = 0;
  DateTime? _quietAfter;

  bool get supportsManual =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS &&
              appStoreId.isNotEmpty));

  void setActivity(Object owner, bool active) {
    if (active) {
      _activities.add(owner);
      _activityGeneration++;
    } else {
      _activities.remove(owner);
    }
  }

  bool get _idle =>
      _activities.isEmpty &&
      _isPlaybackIdle() &&
      (_quietAfter == null || !_now().isBefore(_quietAfter!));

  void cancelPending(BuildContext context) {
    final pending = _pending.remove(context);
    pending?.forEach((timer, completion) {
      timer.cancel();
      completion.complete(false);
    });
  }

  void cancelAllPending() {
    for (final context in _pending.keys.toList()) {
      cancelPending(context);
    }
  }

  void userInteracted() {
    _activityGeneration++;
    cancelAllPending();
  }

  /// A context check at each async boundary prevents a delayed prompt from
  /// following the user onto another screen or covering an open sheet.
  Future<void> afterRoutine(BuildContext context,
      {Duration delay = const Duration(milliseconds: 600),
      bool Function()? isSafe}) async {
    final generation = _activityGeneration;
    final completion = Completer<bool>();
    final pending = _pending.putIfAbsent(context, () => {});
    late final Timer timer;
    timer = Timer(delay, () {
      pending.remove(timer);
      if (pending.isEmpty) _pending.remove(context);
      completion.complete(true);
    });
    pending[timer] = completion;
    if (!await completion.future) return;
    bool safe() {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      return context.mounted &&
          generation == _activityGeneration &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          (isSafe?.call() ?? true);
    }

    await tryRequest(isSafe: safe);
  }

  Future<void> afterAutoScroll(BuildContext context,
      {bool Function()? isSafe}) {
    _quietAfter = _now().add(const Duration(seconds: 5));
    return afterRoutine(context,
        delay: const Duration(seconds: 5), isSafe: isSafe);
  }

  Future<bool> tryRequest({required bool Function() isSafe}) async {
    if (_requesting || !_idle || !isSafe()) return false;
    _requesting = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final last = preferences.getInt(lastRequestKey);
      if (last != null &&
          _now().difference(DateTime.fromMillisecondsSinceEpoch(last)) <
              cooldown) {
        return false;
      }
      if (!await _isAvailable() || !_idle || !isSafe()) return false;
      if (!await preferences.setInt(
          lastRequestKey, _now().millisecondsSinceEpoch)) {
        return false;
      }
      if (!_idle || !isSafe()) return false;
      await _requestReview();
      return true;
    } catch (error) {
      // Reviews are optional. A store failure must never break navigation.
      debugPrint('Unable to request an app review: $error');
      return false;
    } finally {
      _requesting = false;
    }
  }

  /// Explicit user requests bypass the automatic cooldown and use a reliable
  /// store link. They also postpone the next automatic request by 30 days.
  Future<bool> openStore() async {
    if (_requesting) return false;
    _requesting = true;
    try {
      await _openStore();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(lastRequestKey, _now().millisecondsSinceEpoch);
      return true;
    } catch (error) {
      debugPrint('Unable to open the app review page: $error');
      return false;
    } finally {
      _requesting = false;
    }
  }
}
