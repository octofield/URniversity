import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:home_widget/home_widget.dart';

import '../core/widget_snapshot.dart';

// The only part of the home screen widget that talks to the platform.
//
// What the widget shows is decided by buildWidgetSnapshot() in
// core/widget_snapshot.dart, a pure function. This file just hands the result
// across and asks the launcher to redraw.
class HomeWidgetService {
  HomeWidgetService._();
  static final instance = HomeWidgetService._();

  // The keys the Kotlin side reads out of HomeWidgetPreferences
  static const snapshotKey = 'widget_snapshot';
  static const stateKey = 'widget_state';
  // Stored so the background engine can build the snapshot in the user's own
  // language. App settings never reach SharedPreferences otherwise, and a guest
  // has no cloud row to read the choice back from
  static const languageKey = 'widget_language';

  // Must match the provider's class name in AndroidManifest
  static const _providerName = 'TaskWidgetProvider';
  static const _qualifiedProviderName =
      'com.octofield.urniversity.TaskWidgetProvider';

  // iOS would need a WidgetKit extension written in Swift, which is a separate
  // piece of work. The desktop targets have no home screen at all
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> push(WidgetSnapshot snapshot, {String? languageCode}) async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<String>(snapshotKey, snapshot.encode());
      await HomeWidget.saveWidgetData<String>(stateKey, snapshot.state.encode());
      if (languageCode != null) {
        await HomeWidget.saveWidgetData<String>(languageKey, languageCode);
      }
      await HomeWidget.updateWidget(
        androidName: _providerName,
        qualifiedAndroidName: _qualifiedProviderName,
      );
    } catch (e) {
      // No platform channel under flutter test, and a launcher that refuses the
      // update is not something the user can act on. The widget keeps showing
      // its previous contents rather than the app falling over
      debugPrint('[widget] could not push snapshot: $e');
    }
  }

  // The language the app last pushed. Read back rather than guessed because
  // app settings are not persisted for guests at all
  Future<String?> readLanguageCode() async {
    if (!isSupported) return null;
    try {
      return await HomeWidget.getWidgetData<String>(languageKey);
    } catch (e) {
      debugPrint('[widget] could not read language: $e');
      return null;
    }
  }

  // The last state the user left the widget in. Defaults are returned when
  // nothing has been stored yet or the payload is from an older build
  Future<WidgetState> readState() async {
    if (!isSupported) return const WidgetState();
    try {
      return WidgetState.decode(
          await HomeWidget.getWidgetData<String>(stateKey));
    } catch (e) {
      debugPrint('[widget] could not read state: $e');
      return const WidgetState();
    }
  }
}
