import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menu language is independent of the selected hymn book and lyric language.
class AppLanguage extends ValueNotifier<Locale> {
  AppLanguage._() : super(const Locale('en'));
  static final instance = AppLanguage._();
  static const preferenceKey = 'appInterfaceLanguage';
  static const supportedCodes = {'en', 'es', 'pt', 'ru'};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.get(preferenceKey);
    value = Locale(
        saved is String && supportedCodes.contains(saved) ? saved : 'en');
  }

  Future<void> _saves = Future.value();
  Future<void> set(String code) {
    if (!supportedCodes.contains(code)) {
      return Future.error(
          ArgumentError.value(code, 'code', 'Unsupported interface language'));
    }
    final next = _saves.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(preferenceKey, code)) {
        throw StateError('Could not save interface language');
      }
      value = Locale(code);
    });
    _saves = next.catchError((Object _) {});
    return next;
  }
}
