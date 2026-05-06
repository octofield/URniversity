enum FutureCategory { exchange, intern, competition, certification, performance, other }

class Subgoal {
  final String id;
  final String title;
  final bool isDone;

  const Subgoal({required this.id, required this.title, this.isDone = false});

  Subgoal copyWith({String? title, bool? isDone}) {
    return Subgoal(id: id, title: title ?? this.title, isDone: isDone ?? this.isDone);
  }
}

class FutureGoal {
  final String id;
  final String title;
  final FutureCategory category;
  final String? startTime;
  final String? endTime;
  final List<Subgoal> subgoals;

  const FutureGoal({
    required this.id,
    required this.title,
    this.category = FutureCategory.other,
    this.startTime,
    this.endTime,
    this.subgoals = const [],
  });

  FutureGoal copyWith({
    String? title,
    FutureCategory? category,
    String? startTime,
    String? endTime,
    List<Subgoal>? subgoals,
  }) {
    return FutureGoal(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subgoals: subgoals ?? this.subgoals,
    );
  }

  int get completedCount => subgoals.where((s) => s.isDone).length;
}
