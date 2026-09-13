import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notification_constants.dart';
import '../core/notification_schedule.dart';
import '../models/notification_settings.dart';
import '../services/notification_service.dart';
import 'semester_goals_provider.dart';
import 'settings_provider.dart';
import 'tasks_provider.dart';

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(NotificationSettings.initial) {
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(NotificationConstants.prefsKey);
    if (raw == null) return;
    try {
      state = NotificationSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // A parse fallback, not a swallowed write: unreadable settings cost the
      // user their choices, and refusing to start is worse
      state = NotificationSettings.initial;
    }
  }

  Future<void> update(NotificationSettings next) async {
    state = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(
        NotificationConstants.prefsKey, jsonEncode(next.toJson()));
  }

  // Asking the OS is separate from flipping the switch: a denied permission has
  // to leave the switch off, or the screen would promise reminders that the
  // system will never deliver. Returns false when that happened
  Future<bool> enable() async {
    final granted = await NotificationService.instance.requestPermission();
    await update(state.copyWith(enabled: granted));
    return granted;
  }

  Future<void> disable() async {
    await update(state.copyWith(enabled: false));
    await NotificationService.instance.cancelAll();
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(),
);

// The schedule the device should currently hold. Derived rather than stored, so
// adding a task, completing one, or changing a setting all recompute it the
// same way and there is no cache to go stale
final notificationScheduleProvider = Provider<List<ScheduledNotification>>((ref) {
  return buildNotificationSchedule(
    tasks: ref.watch(tasksProvider),
    goals: ref.watch(semesterGoalsProvider),
    settings: ref.watch(notificationSettingsProvider),
    semesterSettings: ref.watch(semesterSettingsProvider),
    s: ref.watch(stringsProvider),
    now: DateTime.now(),
  );
});

// Pushes that schedule to the OS whenever it changes. Watched once from App so
// the wiring lives in exactly one place, the way syncProvider does
final notificationSyncProvider = Provider<void>((ref) {
  if (!NotificationService.isSupported) return;

  ref.listen<List<ScheduledNotification>>(
    notificationScheduleProvider,
    (_, next) => unawaited(NotificationService.instance.apply(next)),
    fireImmediately: true,
  );
});
