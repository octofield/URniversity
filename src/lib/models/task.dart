class _Absent {
  const _Absent();
}

const _absent = _Absent();

class Task {
  final String id;
  final String title;
  final String? content;
  final DateTime? dueTime;
  final int priority; // 1 = low, 2 = medium, 3 = high
  final bool isCompleted;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    this.content,
    this.dueTime,
    this.priority = 1,
    this.isCompleted = false,
    required this.createdAt,
  });

  Task copyWith({
    String? title,
    String? content,
    Object? dueTime = _absent,
    int? priority,
    bool? isCompleted,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      dueTime: dueTime is _Absent ? this.dueTime : dueTime as DateTime?,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }
}
