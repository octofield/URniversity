import 'dart:convert';

class _Absent {
  const _Absent();
}

const _absent = _Absent();

enum RecurrenceType { none, daily, weekly, monthly, everyNDays }

// Sentinel stored in RecurrenceRule.monthDays meaning "the last day of whatever
// month it is". 32 is outside the valid 1-31 range and sorts after them
const int kLastDayOfMonth = 32;

class RecurrenceRule {
  final RecurrenceType type;
  final int interval; // used when type == everyNDays
  // Used when type == weekly: ISO weekdays (Monday = 1 … Sunday = 7).
  // Empty means "same weekday as the task's creation date", which is how
  // weekly recurrence behaved before weekday selection existed
  final List<int> weekdays;
  // Used when type == monthly: days of month (1-31), plus kLastDayOfMonth.
  // Empty means "same day-of-month as the task's creation date"
  final List<int> monthDays;

  const RecurrenceRule({
    required this.type,
    this.interval = 1,
    this.weekdays = const [],
    this.monthDays = const [],
  }) : assert(interval >= 1, 'interval must be at least 1');

  static const none = RecurrenceRule(type: RecurrenceType.none);

  bool get isNone => type == RecurrenceType.none;

  // Guards the modulo in _recurringAppliesTo. The assert above only fires in
  // debug, and a 0 persisted before validation existed still round-trips
  int get safeInterval => interval >= 1 ? interval : 1;
}

String _dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Task {
  final String id;
  final String title;
  final String? content;
  final DateTime? dueTime;
  final int priority; // 1 = low, 2 = medium, 3 = high
  final bool isCompleted;
  final DateTime createdAt;
  final RecurrenceRule? recurrence;
  final String? linkedTargetId;
  final String? linkedGoalId;
  // Parent task id; null = top-level. Subtasks are limited to one level,
  // so a task with a parentTaskId can never itself be a parent
  final String? parentTaskId;
  // Manual ordering within one parentTaskId group; new tasks get max + 1000
  final int sortOrder;
  // Dates on which a recurring task was completed ("yyyy-MM-dd")
  final List<String> completedDates;

  const Task({
    required this.id,
    required this.title,
    this.content,
    this.dueTime,
    this.priority = 1,
    this.isCompleted = false,
    required this.createdAt,
    this.recurrence,
    this.linkedTargetId,
    this.linkedGoalId,
    this.parentTaskId,
    this.sortOrder = 0,
    this.completedDates = const [],
  });

  bool isCompletedOn(DateTime date) {
    if (recurrence == null || recurrence!.isNone) return isCompleted;
    return completedDates.contains(_dateKey(date));
  }

  factory Task.fromJson(Map<String, dynamic> j) {
    List<String> completedDates = const [];
    try {
      final raw = j['completed_dates'];
      if (raw is String && raw.isNotEmpty) {
        completedDates = (jsonDecode(raw) as List).cast<String>();
      }
    } catch (_) {}

    return Task(
      id: j['id'] as String,
      title: j['title'] as String,
      content: j['content'] as String?,
      dueTime: j['due_time'] != null ? DateTime.parse(j['due_time'] as String) : null,
      priority: j['priority'] as int? ?? 1,
      isCompleted: j['is_completed'] as bool? ?? false,
      createdAt: DateTime.parse(j['created_at'] as String),
      recurrence: j['recurrence_type'] != null
          ? RecurrenceRule(
              type: RecurrenceType.values.byName(j['recurrence_type'] as String),
              // Clamped, not just null-defaulted: a 0 stored before validation
              // existed would otherwise round-trip and break the modulo
              interval: switch (j['recurrence_interval'] as int?) {
                null => 1,
                final i when i < 1 => 1,
                final i => i,
              },
              weekdays:
                  (j['recurrence_weekdays'] as List?)?.cast<int>() ?? const [],
              monthDays:
                  (j['recurrence_month_days'] as List?)?.cast<int>() ?? const [],
            )
          : null,
      linkedTargetId: j['linked_target_id'] as String?,
      linkedGoalId: j['linked_goal_id'] as String?,
      parentTaskId: j['parent_task_id'] as String?,
      sortOrder: j['sort_order'] as int? ?? 0,
      completedDates: completedDates,
    );
  }

  Map<String, dynamic> toJson() => {
    // recurrence_month_days is emitted only when actually used: PostgREST
    // rejects the whole row if a key has no matching column, so omitting it
    // keeps every other write working until the column migration is applied
    if (recurrence != null && recurrence!.monthDays.isNotEmpty)
      'recurrence_month_days': recurrence!.monthDays,
    'id': id,
    'title': title,
    'content': content,
    'due_time': dueTime?.toIso8601String(),
    'priority': priority,
    'is_completed': isCompleted,
    'created_at': createdAt.toIso8601String(),
    'recurrence_type': (recurrence != null && !recurrence!.isNone) ? recurrence!.type.name : null,
    'recurrence_interval': (recurrence != null && !recurrence!.isNone) ? recurrence!.interval : null,
    'recurrence_weekdays':
        (recurrence != null && recurrence!.weekdays.isNotEmpty) ? recurrence!.weekdays : null,
    'linked_target_id': linkedTargetId,
    'linked_goal_id': linkedGoalId,
    'parent_task_id': parentTaskId,
    'sort_order': sortOrder,
    'completed_dates': completedDates.isNotEmpty ? jsonEncode(completedDates) : null,
  };

  Task copyWith({
    String? title,
    Object? content = _absent,
    Object? dueTime = _absent,
    int? priority,
    bool? isCompleted,
    Object? recurrence = _absent,
    Object? linkedTargetId = _absent,
    Object? linkedGoalId = _absent,
    Object? parentTaskId = _absent,
    int? sortOrder,
    List<String>? completedDates,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      content: content is _Absent ? this.content : content as String?,
      dueTime: dueTime is _Absent ? this.dueTime : dueTime as DateTime?,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      recurrence: recurrence is _Absent ? this.recurrence : recurrence as RecurrenceRule?,
      linkedTargetId: linkedTargetId is _Absent ? this.linkedTargetId : linkedTargetId as String?,
      linkedGoalId: linkedGoalId is _Absent ? this.linkedGoalId : linkedGoalId as String?,
      parentTaskId: parentTaskId is _Absent ? this.parentTaskId : parentTaskId as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      completedDates: completedDates ?? this.completedDates,
    );
  }
}
