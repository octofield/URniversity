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

  factory Task.fromJson(Map<String, dynamic> j) => Task(
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
            interval: j['recurrence_interval'] as int? ?? 1,
          )
        : null,
    linkedTargetId: j['linked_target_id'] as String?,
    linkedGoalId: j['linked_goal_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'due_time': dueTime?.toIso8601String(),
    'priority': priority,
    'is_completed': isCompleted,
    'created_at': createdAt.toIso8601String(),
    'recurrence_type': (recurrence != null && !recurrence!.isNone) ? recurrence!.type.name : null,
    'recurrence_interval': (recurrence != null && !recurrence!.isNone) ? recurrence!.interval : null,
    'linked_target_id': linkedTargetId,
    'linked_goal_id': linkedGoalId,
  };

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
