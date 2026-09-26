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
  // widget_state is not written from here any more: the native side owns it,
  // because switching tab, period or filter happens there without Dart
  // Stored so the background engine can build the snapshot in the user's own
  // language. App settings never reach SharedPreferences otherwise, and a guest
  // has no cloud row to read the choice back from
  static const languageKey = 'widget_language';
  // The app style in use; must match WidgetStyle.KEY in WidgetStyle.kt
  static const styleKey = 'app_style';

  // Must match the provider's class name in AndroidManifest
  static const _providerName = 'TaskWidgetProvider';
  static const _qualifiedProviderName =
      'com.octofield.urniversity.TaskWidgetProvider';

  // iOS would need a WidgetKit extension written in Swift, which is a separate
  // piece of work. The desktop targets have no home screen at all
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> push(WidgetSnapshot snapshot, {String? languageCode, String? styleName}) async {
    if (!isSupported) return;
    try {
      await HomeWidget.saveWidgetData<String>(snapshotKey, snapshot.encode());
      if (languageCode != null) {
        await HomeWidget.saveWidgetData<String>(languageKey, languageCode);
      }
      // The app style, which WidgetStyle.kt turns into the widget's colours
      if (styleName != null) {
        await HomeWidget.saveWidgetData<String>(styleKey, styleName);
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

  // Takes back a tick the native side drew ahead of a write that then failed
  Future<void> untick(String checkAction) async {
    if (!isSupported) return;
    try {
      final raw = await HomeWidget.getWidgetData<String>(snapshotKey);
      if (raw == null) return;
      await HomeWidget.saveWidgetData<String>(
          snapshotKey, untickInSnapshot(raw, checkAction));
      await HomeWidget.updateWidget(
        androidName: _providerName,
        qualifiedAndroidName: _qualifiedProviderName,
      );
    } catch (e) {
      // The failed write itself is already in the action log for the app to
      // report; this only costs the widget a stale tick until the next push
      debugPrint('[widget] could not take back the tick: $e');
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

}
