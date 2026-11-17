import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sdahymnal/services/app_review.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late int requests;
  late int storeOpens;
  late bool idle;
  late bool available;
  late AppReviewService reviews;

  AppReviewService createService() => AppReviewService(
        now: () => now,
        isAvailable: () async => available,
        requestReview: () async => requests++,
        openStore: () async => storeOpens++,
        isPlaybackIdle: () => idle,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 11, 17);
    requests = 0;
    storeOpens = 0;
    idle = true;
    available = true;
    reviews = createService();
  });

  test('all triggers share a persisted 30-day cooldown, including dismissal',
      () async {
    expect(await reviews.tryRequest(isSafe: () => true), isTrue);
    reviews = createService(); // Reopening the app retains the cooldown.
    now = now.add(const Duration(days: 30) - const Duration(milliseconds: 1));
    expect(await reviews.tryRequest(isSafe: () => true), isFalse);
    now = now.add(const Duration(milliseconds: 1));
    expect(await reviews.tryRequest(isSafe: () => true), isTrue);
    expect(requests, 2);
  });

  test('simultaneous routine endings request only one native dialog', () async {
    final results = await Future.wait(
        List.generate(4, (_) => reviews.tryRequest(isSafe: () => true)));
    expect(results.where((requested) => requested), hasLength(1));
    expect(requests, 1);
  });

  test('playback, video, scrolling and unsafe screens defer without cooldown',
      () async {
    idle = false;
    expect(await reviews.tryRequest(isSafe: () => true), isFalse);
    idle = true;
    final video = Object();
    final scroll = Object();
    reviews.setActivity(video, true);
    reviews.setActivity(scroll, true);
    reviews.setActivity(video, false);
    expect(await reviews.tryRequest(isSafe: () => true), isFalse);
    reviews.setActivity(scroll, false);
    expect(await reviews.tryRequest(isSafe: () => false), isFalse);
    available = false;
    expect(await reviews.tryRequest(isSafe: () => true), isFalse);
    expect(
        (await SharedPreferences.getInstance())
            .containsKey(AppReviewService.lastRequestKey),
        isFalse);
    available = true;
    expect(await reviews.tryRequest(isSafe: () => true), isTrue);
  });

  test('rechecks safety when store availability takes time', () async {
    final availability = Completer<bool>();
    var safe = true;
    reviews = AppReviewService(
      isAvailable: () => availability.future,
      requestReview: () async => requests++,
      isPlaybackIdle: () => true,
    );
    final pending = reviews.tryRequest(isSafe: () => safe);
    await Future<void>.delayed(Duration.zero);
    safe = false;
    availability.complete(true);
    expect(await pending, isFalse);
    expect(requests, 0);
  });

  test('native failure is contained and retains cooldown against repeated asks',
      () async {
    reviews = AppReviewService(
      now: () => now,
      isAvailable: () async => true,
      requestReview: () async => throw StateError('store unavailable'),
      isPlaybackIdle: () => true,
    );
    expect(await reviews.tryRequest(isSafe: () => true), isFalse);
    reviews = createService();
    expect(await reviews.tryRequest(isSafe: () => true), isFalse);
  });

  test('manual store action bypasses cooldown and resets automatic cooldown',
      () async {
    await reviews.tryRequest(isSafe: () => true);
    now = now.add(const Duration(days: 10));
    expect(await reviews.openStore(), isTrue);
    expect(await reviews.openStore(), isTrue);
    now = now.add(const Duration(days: 29));
    expect(await reviews.tryRequest(isSafe: () => true), isFalse);
    expect(storeOpens, 2);
    expect(requests, 1);
  });

  Future<BuildContext> mount(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const Scaffold();
    })));
    await tester.pumpAndSettle();
    return context;
  }

  testWidgets('auto-scroll waits five seconds and blocks earlier audio prompt',
      (tester) async {
    final context = await mount(tester);
    unawaited(reviews.afterAutoScroll(context));
    unawaited(reviews.afterRoutine(context));
    now = now.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 4));
    expect(requests, 0);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(requests, 1);
  });

  testWidgets('new activity cancels an old delayed routine prompt',
      (tester) async {
    final context = await mount(tester);
    unawaited(reviews.afterAutoScroll(context));
    reviews.setActivity(thisActivity, true);
    reviews.setActivity(thisActivity, false);
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(requests, 0);
  });

  testWidgets('touching the app cancels a pending request immediately',
      (tester) async {
    final context = await mount(tester);
    final pending = reviews.afterAutoScroll(context);
    reviews.userInteracted();
    await pending;
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(requests, 0);
  });

  testWidgets('navigation and open dialogs suppress delayed requests',
      (tester) async {
    final context = await mount(tester);
    unawaited(reviews.afterRoutine(context));
    unawaited(showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('Busy'))));
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 0);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    unawaited(reviews.afterRoutine(context));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 0);
  });
}

final thisActivity = Object();
