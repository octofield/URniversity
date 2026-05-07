class Milestone {
  final String id;
  final String title;
  final bool isDone;

  const Milestone({required this.id, required this.title, this.isDone = false});

  Milestone copyWith({String? title, bool? isDone}) {
    return Milestone(id: id, title: title ?? this.title, isDone: isDone ?? this.isDone);
  }
}

class SemesterGoal {
  final String id;
  final String title;
  final String semester;
  final String category;
  final String? futureGoalId;
  final List<Milestone> milestones;
  final String? notes;

  const SemesterGoal({
    required this.id,
    required this.title,
    required this.semester,
    this.category = 'other',
    this.futureGoalId,
    this.milestones = const [],
    this.notes,
  });

  SemesterGoal copyWith({
    String? title,
    String? semester,
    String? category,
    List<Milestone>? milestones,
    String? notes,
  }) {
    return SemesterGoal(
      id: id,
      title: title ?? this.title,
      semester: semester ?? this.semester,
      category: category ?? this.category,
      futureGoalId: futureGoalId,
      milestones: milestones ?? this.milestones,
      notes: notes ?? this.notes,
    );
  }

  int get completedCount => milestones.where((m) => m.isDone).length;
}
