class FutureCategories {
  static const exchange = 'exchange';
  static const intern = 'intern';
  static const competition = 'competition';
  static const certification = 'certification';
  static const performance = 'performance';
  static const other = 'other';

  static const builtIns = <String>[
    exchange, intern, competition, certification, performance, other,
  ];
}

class Subgoal {
  final String id;
  final String title;
  final bool isDone;

  const Subgoal({required this.id, required this.title, this.isDone = false});

  Subgoal copyWith({String? title, bool? isDone}) {
    return Subgoal(id: id, title: title ?? this.title, isDone: isDone ?? this.isDone);
  }
}

// Compare semester strings like "114-1" < "114-2" < "115-1"
int compareSemesters(String a, String b) {
  final pa = a.split('-');
  final pb = b.split('-');
  final yearDiff = int.parse(pa[0]) - int.parse(pb[0]);
  if (yearDiff != 0) return yearDiff;
  return int.parse(pa[1]) - int.parse(pb[1]);
}

class FutureGoal {
  final String id;
  final String title;
  final String category;
  final String? startSemester;
  final String? endSemester;
  final String? notes;
  final List<Subgoal> subgoals;

  const FutureGoal({
    required this.id,
    required this.title,
    this.category = FutureCategories.other,
    this.startSemester,
    this.endSemester,
    this.notes,
    this.subgoals = const [],
  });

  FutureGoal copyWith({
    String? title,
    String? category,
    String? startSemester,
    String? endSemester,
    String? notes,
    List<Subgoal>? subgoals,
  }) {
    return FutureGoal(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      startSemester: startSemester ?? this.startSemester,
      endSemester: endSemester ?? this.endSemester,
      notes: notes ?? this.notes,
      subgoals: subgoals ?? this.subgoals,
    );
  }

  int get completedCount => subgoals.where((s) => s.isDone).length;
}
