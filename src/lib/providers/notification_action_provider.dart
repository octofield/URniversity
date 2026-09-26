import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notification_constants.dart';
import '../core/notification_payload.dart';
import '../services/notification_service.dart';
import 'settings_provider.dart';
import 'synced_list_notifier.dart';
import 'tasks_provider.dart';

// An item the user asked to open from outside the app — the notification's
// "reschedule" button, or a row on the home screen widget.
//
// Held until the row it names has actually loaded: a cold start opens the app
// long before the data arrives, and the destination needs the item itself.
// [kind] is 'task', 'semesterGoal' or 'futureGoal'
final pendingOpenProvider =
    StateProvider<({String kind, String id})?>((ref) => null);

// Reads what the background isolate left behind and puts the main isolate back
// in step with it.
//
// Two separate jobs, both needed:
//   - the stored rows changed underneath this isolate, so the list must be
//     refetched or the screen keeps showing the task as unfinished
//   - a write that failed there had no UI to report through, so it is surfaced
//     here through the same reportSyncError path as any other failed write
Future<void> drainNotificationActions(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  // This isolate's cache predates the background write. Without this the log
  // reads back empty and nothing is reconciled
  await prefs.reload();

  final raw = prefs.getString(NotificationConstants.actionLogKey);
  final records = NotificationActionRecord.decodeList(raw);
  if (records.isEmpty) return;

  await prefs.remove(NotificationConstants.actionLogKey);
  await ref.read(tasksProvider.notifier).reload();

  final s = ref.read(stringsProvider);
  for (final record in records.where((r) => r.failed)) {
    reportSyncError(ref, s.notifActionFailed(record.error!));
  }
}

// Routes a notification the user tapped. Only the reschedule button and a tap
// on the notification body reach here; "done" is handled entirely in the
// background isolate and never wakes the UI
void handleForegroundResponse(Ref ref, NotificationResponse response) {
  if (response.payload == NotificationConstants.reviewPayload) {
    ref.read(pendingOpenProvider.notifier).state = (kind: 'review', id: '');
    return;
  }
  final payload = TaskNotificationPayload.decode(response.payload);
  if (payload == null) return;
  if (response.actionId != null &&
      response.actionId != NotificationConstants.actionRescheduleId) {
    return;
  }
  ref.read(pendingOpenProvider.notifier).state =
      (kind: 'task', id: payload.taskId);
}

// Wires the service to the app. Watched once from App, the way syncProvider is.
final notificationActionProvider = Provider<void>((ref) {
  if (!NotificationService.isSupported) return;

  final service = NotificationService.instance;
  final s = ref.watch(stringsProvider);
  service.doneLabel = s.notifActionDone;
  service.rescheduleLabel = s.notifActionReschedule;
  service.onForegroundResponse = (r) => handleForegroundResponse(ref, r);

  // A cold start misses the callback entirely — nothing was listening when the
  // notification launched the app — so the launch details are asked for instead
  unawaited(Future(() async {
    final launch = await service.launchResponse();
    if (launch != null) handleForegroundResponse(ref, launch);
    await drainNotificationActions(ref);
  }));

  // Every return to the foreground, because the background isolate may have
  // written while the app sat in the recents list
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(drainNotificationActions(ref)),
  );
  ref.onDispose(lifecycle.dispose);
});
