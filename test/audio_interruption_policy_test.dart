import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/audio_interruption_policy.dart';

void main() {
  test('call cancellation precedes pending pause and call end does not resume',
      () async {
    final events = <String>[];
    final gate = Completer<void>();
    final policy = AudioInterruptionPolicy(
      cancelPending: () => events.add('cancel'),
      pause: () {
        events.add('pause');
        return gate.future;
      },
    );
    final beginning = policy.interruption(begin: true);
    expect(events, ['cancel', 'pause']);
    await policy.interruption(begin: false);
    expect(events, ['cancel', 'pause']);
    gate.complete();
    await beginning;
    await policy.interruption(begin: false);
    expect(events, ['cancel', 'pause']);
  });

  test('headphone removal cancels even if pause fails and later events retry',
      () async {
    var cancellations = 0;
    var pauses = 0;
    final policy = AudioInterruptionPolicy(
      cancelPending: () => cancellations++,
      pause: () async {
        if (++pauses == 1) throw StateError('engine failure');
      },
    );
    await policy.headphonesRemoved();
    await policy.interruption(begin: false);
    expect(cancellations, 1);
    expect(pauses, 1);
    await policy.interruption(begin: true);
    await policy.headphonesRemoved();
    expect(cancellations, 3);
    expect(pauses, 3);
  });
}
