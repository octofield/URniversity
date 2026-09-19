import 'notification_payload.dart';

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
