import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_styles.dart';

// The parts of a style Android draws before Flutter runs (system_design.md
// §3-R): the launcher icon and the system splash. MainActivity.kt answers;
// everywhere else there is nothing to change, so these quietly do nothing
class StyleChannel {
  StyleChannel._();

  static const _channel = MethodChannel('urniversity/style');

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // The launcher icon. Only for a style picked by hand: swapping icons on every
  // random launch would leave the home screen icon never the same twice
  static Future<void> setIcon(AppStyle style) => _call('setIcon', style);

  // The splash the next launch shows (Android 13 and up)
  static Future<void> setSplash(AppStyle style) => _call('setSplash', style);

  static Future<void> _call(String method, AppStyle style) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, {'style': style.name});
    } on MissingPluginException {
      // Cosmetic fallback, not a write: no handler under `flutter test` or in
      // a background engine, and the style still applies inside the app
    } on PlatformException catch (e) {
      debugPrint('[style] $method failed - ${e.message}');
    }
  }
}
