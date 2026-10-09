import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdahymnal/services/title_collation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sdahymnal/collation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
      'passes source titles and book language and preserves duplicate occurrences',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'sort');
      expect(call.arguments, {
        'titles': ['Ñandú', 'Nube', 'Nube'],
        'language': 'es'
      });
      return [1, 2, 0];
    });
    final order = await TitleCollation.order(['Ñandú', 'Nube', 'Nube'], 'es');
    expect(order, [1, 2, 0]);
    expect(() => order.add(3), throwsUnsupportedError);
  });
  test('rejects incomplete duplicated and out of range native results',
      () async {
    for (final invalid in [
      null,
      [0],
      [0, 0],
      [0, 2],
      [-1, 0]
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => invalid);
      await expectLater(
          TitleCollation.order(['A', 'B'], 'ru'), throwsFormatException);
    }
  });
  test('does not pretend to have locale sorting when bridge is unavailable',
      () async {
    await expectLater(TitleCollation.order(['A'], 'fr'),
        throwsA(isA<MissingPluginException>()));
    expect(await TitleCollation.order([], 'fr'), isEmpty);
    await expectLater(TitleCollation.order(['A'], ''), throwsArgumentError);
  });
}
