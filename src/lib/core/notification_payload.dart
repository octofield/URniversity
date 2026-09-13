import 'dart:convert';

// What a task notification carries so the action handler knows what it is
// acting on.
//
// The date matters as much as the id: a recurring task's notification is for
// one specific day's occurrence, and marking it done must tick that day rather
// than the whole series.
class TaskNotificationPayload {
  final String taskId;
  final DateTime date;

  const TaskNotificationPayload({required this.taskId, required this.date});

  // "{taskId}|{yyyy-MM-dd}". A flat string because the platform hands the
  // payload back as one, and row ids never contain a pipe (newRowId() produces
  // "{millis}_{random}")
  String encode() {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$taskId|$y-$m-$d';
  }

  // Returns null rather than throwing. This is parsed in a background isolate
  // where an exception has nowhere to go, and a payload written by an older
  // build must not take the handler down with it
  static TaskNotificationPayload? decode(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 2 || parts[0].isEmpty) return null;
    final date = DateTime.tryParse(parts[1]);
    if (date == null) return null;
    return TaskNotificationPayload(taskId: parts[0], date: date);
  }
}

// One thing the background isolate did, left for the main isolate to reconcile.
//
// Every entry means "the stored data changed underneath you, reload"; an entry
// with an [error] additionally means the write never landed and the user has
// not been told yet.
class NotificationActionRecord {
  final String taskId;
  final String? error;

  const NotificationActionRecord({required this.taskId, this.error});

  bool get failed => error != null;

  Map<String, dynamic> toJson() => {
        'task_id': taskId,
        if (error != null) 'error': error,
      };

  static NotificationActionRecord fromJson(Map<String, dynamic> j) =>
      NotificationActionRecord(
        taskId: j['task_id'] as String? ?? '',
        error: j['error'] as String?,
      );

  // A malformed log is dropped rather than thrown: it only costs the reload
  // hint, and refusing to start the app over it would be far worse
  static List<NotificationActionRecord> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .where((r) => r.taskId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encodeList(List<NotificationActionRecord> records) =>
      jsonEncode(records.map((r) => r.toJson()).toList());
}
