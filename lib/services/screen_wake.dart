import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:sdahymnal/services/prefs.dart';

/// Owns the screen wakelock, so the phone does not lock while a hymn is being
/// read off a propped-up screen.
///
/// Screens that want the display kept awake [acquire] on the way in and
/// [release] on the way out; the lock is really held only while at least one
/// holder is active, [KeepScreenOn] is on, and the app is in the foreground.
///
/// The holder count (rather than a plain on/off) is what makes prev/next work:
/// [pushReplacement] builds the incoming hymn page before disposing the
/// outgoing one, so the count dips to 1 instead of 0 and the screen never
/// blinks back to the system timeout between hymns.
class ScreenWake with WidgetsBindingObserver {
  ScreenWake._() {
    // Flipping the setting takes effect immediately, even mid-hymn.
    KeepScreenOn.instance.addListener(_apply);
    // Never keep the screen alive behind another app. Both platforms scope
    // their wakelock to the app already; releasing explicitly means we do not
    // depend on that.
    WidgetsBinding.instance.addObserver(this);
  }

  static final ScreenWake instance = ScreenWake._();

  /// Number of live screens asking for the wakelock.
  int _holders = 0;

  /// Last state handed to the plugin; keeps [_apply] from re-issuing calls.
  bool _enabled = false;

  /// Visible for tests: whether the wakelock is currently meant to be held.
  @visibleForTesting
  bool get enabled => _enabled;

  /// Called by a screen that wants the display kept awake while it is alive.
  void acquire() {
    _holders++;
    _apply();
  }

  /// Called by that screen when it goes away. Balanced with [acquire].
  void release() {
    if (_holders > 0) _holders--;
    _apply();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground re-asserts the lock even if we believe
    // it is already held: a toggle that failed silently (the catch below)
    // must not leave the screen timing out for the rest of the session.
    _apply(reassert: state == AppLifecycleState.resumed);
  }

  /// Only a paused or detached app is "background". Null (before the first
  /// lifecycle message) and `inactive` both count as foreground: iOS reports
  /// `inactive` while the app is plainly on screen — system overlays, the
  /// volume HUD, the moment a scene starts — and gating on `resumed` alone
  /// left the lock never requested on the phone (the screen kept timing out
  /// mid-hymn, 2026-08-23).
  bool get _foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached;
  }

  Future<void> _apply({bool reassert = false}) async {
    final want = _holders > 0 && KeepScreenOn.instance.value && _foreground;
    if (want == _enabled && !(reassert && want)) return;
    // Recorded before the await so overlapping calls cannot double-toggle.
    _enabled = want;
    try {
      await WakelockPlus.toggle(enable: want);
    } catch (_) {
      // No plugin under `flutter test`, and not every platform supports a
      // wakelock; the screen timeout just stays at the system default.
    }
  }
}
