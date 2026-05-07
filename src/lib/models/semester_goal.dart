class SemesterGoal {
  final String id;
  final String? parentId;   // null = top-level target
  final String title;
  final String semester;
  final String category;
  final String? futureGoalId;
  final String? notes;
  final bool isDone;

  const SemesterGoal({
    required this.id,
    this.parentId,
    required this.title,
    required this.semester,
    this.category = 'other',
    this.futureGoalId,
    this.notes,
    this.isDone = false,
  });

  SemesterGoal copyWith({
    Object? parentId = _sgSentinel,
    String? title,
    String? semester,
    String? category,
    Object? futureGoalId = _sgSentinel,
    Object? notes = _sgSentinel,
    bool? isDone,
  }) {
    return SemesterGoal(
      id: id,
      parentId: parentId == _sgSentinel ? this.parentId : parentId as String?,
      title: title ?? this.title,
      semester: semester ?? this.semester,
      category: category ?? this.category,
      futureGoalId: futureGoalId == _sgSentinel ? this.futureGoalId : futureGoalId as String?,
      notes: notes == _sgSentinel ? this.notes : notes as String?,
      isDone: isDone ?? this.isDone,
    );
  }
}

const Object _sgSentinel = Object();
