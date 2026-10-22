import 'notification_payload.dart';
import '../models/task.dart';

// Which of the notifications currently on screen belong to one task.
//
// A reminder stays in the shade until its task is done, and the task can be
// ticked off from three places: the app, the notification's own button, and the
// home screen widget. The app and the widget run in different isolates and each
// has to find the right notification itself, so the matching rule lives here
// rather than being written twice.
//
// Matched on the payload, not the id: ids are handed out positionally when the
// schedule is built (see notification_schedule.dart), so the id on screen
// cannot be recomputed from the task alone.
List<int> notificationIdsForTask(
  Iterable<({int? id, String? payload})> shown,
  String taskId,
) {
  final ids = <int>[];
  for (final n in shown) {
    final id = n.id;
    if (id == null) continue;
    if (TaskNotificationPayload.decode(n.payload)?.taskId != taskId) continue;
    ids.add(id);
  }
  return ids;
}

// The task reminders in the shade that should go (2026-10-22): their task has
// been done for the day the reminder was about, or deleted — on this device or,
// through sync, on another. Other kinds (the daily summary) stay. A list with
// nothing in it yet, as at start-up before the tasks arrive, deletes nothing
List<int> notificationIdsToDismiss(
  Iterable<({int? id, String? payload})> shown,
  List<Task> tasks,
) {
  final byId = {for (final t in tasks) t.id: t};
  final ids = <int>[];
  for (final n in shown) {
    final id = n.id;
    final payload = TaskNotificationPayload.decode(n.payload);
    if (id == null || payload == null) continue;
    final task = byId[payload.taskId];
    final gone = task == null && tasks.isNotEmpty;
    if (gone || (task != null && task.isCompletedOn(payload.date))) ids.add(id);
  }
  return ids;
}

