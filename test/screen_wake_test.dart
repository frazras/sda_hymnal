// ScreenWake: the hymn page holds the wakelock, the setting gates it, and
// prev/next (which builds the next page before disposing the current one)
// never drops it in between.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/services/screen_wake.dart';

/// Records what the plugin was asked to do, in order.
class _FakeWakelock extends WakelockPlusPlatformInterface {
  final List<bool> calls = [];
  bool _enabled = false;

  @override
  Future<void> toggle({required bool enable}) async {
    calls.add(enable);
    _enabled = enable;
  }

  @override
  Future<bool> get enabled async => _enabled;
}

void main() {
  late _FakeWakelock fake;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    fake = _FakeWakelock();
    wakelockPlusPlatformInstance = fake;
    await KeepScreenOn.instance.load();
  });

  tearDown(() async {
    // ScreenWake is a singleton: hand every holder back so the next test
    // starts from zero.
    while (ScreenWake.instance.enabled) {
      ScreenWake.instance.release();
      await Future<void>.delayed(Duration.zero);
    }
  });

  test('defaults to on', () {
    expect(KeepScreenOn.instance.value, isTrue);
  });

  test('holds the lock while a screen is open, releases after', () async {
    ScreenWake.instance.acquire();
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, [true]);

    ScreenWake.instance.release();
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, [true, false]);
  });

  test('prev/next keeps the lock across the page swap', () async {
    ScreenWake.instance.acquire();
    await Future<void>.delayed(Duration.zero);

    // pushReplacement order: the incoming page's initState runs before the
    // outgoing page's dispose.
    ScreenWake.instance.acquire();
    ScreenWake.instance.release();
    await Future<void>.delayed(Duration.zero);

    expect(fake.calls, [true], reason: 'no toggle between hymns');
    expect(ScreenWake.instance.enabled, isTrue);
  });

  test('the setting gates it, and applies mid-hymn', () async {
    await KeepScreenOn.instance.set(false);
    ScreenWake.instance.acquire();
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, isEmpty, reason: 'setting off, so never taken');

    // Flipped on while the hymn page is already open.
    await KeepScreenOn.instance.set(true);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, [true]);

    // ...and back off again without leaving the page.
    await KeepScreenOn.instance.set(false);
    await Future<void>.delayed(Duration.zero);
    expect(fake.calls, [true, false]);

    ScreenWake.instance.release();
  });

  test('the setting survives a restart', () async {
    await KeepScreenOn.instance.set(false);
    KeepScreenOn.instance.value = true; // pretend a fresh process
    await KeepScreenOn.instance.load();
    expect(KeepScreenOn.instance.value, isFalse);
  });
}
