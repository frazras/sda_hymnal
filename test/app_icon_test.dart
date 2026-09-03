import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/services/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sdahymnal/app_icon');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final controller = AppDesignController.instance;
  final calls = <MethodCall>[];

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await controller.load();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('fresh installs default to Modern and do not opt into Classic',
      () async {
    expect(controller.value, AppDesign.modern);
    expect(calls, isEmpty,
        reason: 'loading preferences must not invoke UIKit before launch');
    await controller.syncIcon();
    expect(calls.single.method, 'setDesign');
    expect(calls.single.arguments, 'modern');
    expect(
        (await SharedPreferences.getInstance()).getString('appDesign'), isNull);
  });

  test('Classic and Modern persist before invoking the matching native icon',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      expect((await SharedPreferences.getInstance()).getString('appDesign'),
          call.arguments);
      return null;
    });
    await controller.set(AppDesign.classic);
    await controller.set(AppDesign.modern);
    expect(calls.map((c) => c.arguments), ['classic', 'modern']);
    expect(controller.iconError.value, isNull);
    expect(controller.iconBusy.value, isFalse);
  });

  test(
      'saved Classic migrates its icon after launch, not during preference load',
      () async {
    SharedPreferences.setMockInitialValues({'appDesign': 'classic'});
    await controller.load();
    expect(calls, isEmpty);
    await controller.syncIcon();
    expect(calls.single.arguments, 'classic');
  });

  test('launcher failure leaves layout saved and supports retry', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'ICON_CHANGE_FAILED');
    });
    await controller.set(AppDesign.classic);
    expect(controller.value, AppDesign.classic);
    expect((await SharedPreferences.getInstance()).getString('appDesign'),
        'classic');
    expect(controller.iconError.value, contains('layout is saved'));
    expect(controller.iconBusy.value, isFalse);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    await controller.syncIcon();
    expect(calls.single.arguments, 'classic');
    expect(controller.iconError.value, isNull);
  });

  test('concurrent requests serialize and finish with the latest design',
      () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (calls.length == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
      return null;
    });
    final first = controller.set(AppDesign.classic);
    await firstStarted.future;
    final last = controller.set(AppDesign.modern);
    // Wait until the new preference is published, while the first OS call
    // is still outstanding. No second OS operation should start yet.
    await Future<void>.delayed(Duration.zero);
    expect(controller.value, AppDesign.modern);
    expect(controller.iconBusy.value, isTrue);
    expect(calls, hasLength(1));
    releaseFirst.complete();
    await Future.wait([first, last]);
    expect(calls.map((c) => c.arguments), ['classic', 'modern']);
    expect(controller.value, AppDesign.modern);
    expect(controller.iconBusy.value, isFalse);
  });

  test('unsupported desktop targets keep the layout without native calls',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await controller.set(AppDesign.classic);
    expect(controller.value, AppDesign.classic);
    expect(calls, isEmpty);
    expect(controller.iconError.value, isNull);
  });
}
