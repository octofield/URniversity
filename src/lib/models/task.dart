class _Absent {
  const _Absent();
}

const _absent = _Absent();

enum RecurrenceType { none, daily, weekly, monthly, everyNDays }

class RecurrenceRule {
  final RecurrenceType type;
  final int interval; // used when type == everyNDays

  const RecurrenceRule({required this.type, this.interval = 1});

  static const none = RecurrenceRule(type: RecurrenceType.none);

  bool get isNone => type == RecurrenceType.none;
}

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
  });

  Task copyWith({
    String? title,
    String? content,
    Object? dueTime = _absent,
    int? priority,
    bool? isCompleted,
    Object? recurrence = _absent,
    Object? linkedTargetId = _absent,
    Object? linkedGoalId = _absent,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      dueTime: dueTime is _Absent ? this.dueTime : dueTime as DateTime?,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      recurrence: recurrence is _Absent ? this.recurrence : recurrence as RecurrenceRule?,
      linkedTargetId: linkedTargetId is _Absent ? this.linkedTargetId : linkedTargetId as String?,
      linkedGoalId: linkedGoalId is _Absent ? this.linkedGoalId : linkedGoalId as String?,
    );
  }
}
