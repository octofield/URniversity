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
  final List<Milestone> milestones;

  const SemesterGoal({required this.id, required this.title, this.milestones = const []});

  SemesterGoal copyWith({String? title, List<Milestone>? milestones}) {
    return SemesterGoal(
      id: id,
      title: title ?? this.title,
      milestones: milestones ?? this.milestones,
    );
  }

  int get completedCount => milestones.where((m) => m.isDone).length;
}
