// Run explicitly with Flutter so its bundled Dart/native SQLite runtime is used.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'analytics_multilingual_e2e.dart' as verification;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test('live multilingual analytics uses the app store and transport',
      verification.main);
}
