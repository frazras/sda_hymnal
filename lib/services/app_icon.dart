import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native launchers own the home-screen icon; changing a Flutter image alone
/// cannot change it. Both native handlers skip an already-selected icon.
class AppIcon {
  static const _channel = MethodChannel('sdahymnal/app_icon');

  static Future<void> setDesign(String design) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    await _channel.invokeMethod<void>('setDesign', design);
  }
}
