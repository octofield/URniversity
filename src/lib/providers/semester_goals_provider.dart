import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester_goal.dart';
import 'settings_provider.dart';

// Find current semester given settings; robust algorithm based on most-recent start
String currentSemester(SemesterSettings settings) {
  final now = DateTime.now();
  final rocYear = now.year - 1911;

  String result = '${rocYear - 1}-1';
  DateTime resultStart = DateTime(2000);

  for (int ay = rocYear - 1; ay <= rocYear + 1; ay++) {
    int yearOffset = 0;
    for (int t = 0; t < settings.startMonths.length; t++) {
      if (t > 0 && settings.startMonths[t] <= settings.startMonths[t - 1]) yearOffset++;
      final semStart = DateTime(ay + 1911 + yearOffset, settings.startMonths[t]);
      if (!semStart.isAfter(now) && semStart.isAfter(resultStart)) {
        resultStart = semStart;
        result = '$ay-${t + 1}';
      }
    }
  }

  return result;
}

List<String> generateSemesters(SemesterSettings settings) {
  final curSem = currentSemester(settings);
  final curYear = int.parse(curSem.split('-')[0]);
  final n = settings.startMonths.length;
  final sems = <String>[];
  for (var ay = curYear - 4; ay <= curYear + 3; ay++) {
    for (var t = 1; t <= n; t++) {
      sems.add('$ay-$t');
    }
  }
  return sems;
}

final currentSemesterProvider = Provider<String>((ref) {
  final settings = ref.watch(semesterSettingsProvider);
  return currentSemester(settings);
});

final selectedSemesterProvider = StateProvider<String>(
  (ref) => ref.read(currentSemesterProvider),
);

class SemesterGoalsNotifier extends StateNotifier<List<SemesterGoal>> {
  SemesterGoalsNotifier() : super([]);

  void addGoal(
    String title,
    String semester, {
    String? parentId,
    String category = 'other',
    String? futureGoalId,
    String? notes,
  }) {
    state = [
      ...state,
      SemesterGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        parentId: parentId,
        title: title,
        semester: semester,
        category: category,
        futureGoalId: futureGoalId,
        notes: notes,
      ),
    ];
  }

  void updateGoal(
    String goalId, {
    required String title,
    required String category,
    String? futureGoalId,
    String? notes,
  }) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          SemesterGoal(
            id: g.id,
            parentId: g.parentId,
            title: title,
            semester: g.semester,
            category: category,
            futureGoalId: futureGoalId,
            notes: notes,
            isDone: g.isDone,
          )
        else
          g,
    ];
  }

  void toggleDone(String goalId) {
    state = [
      for (final g in state)
        if (g.id == goalId) g.copyWith(isDone: !g.isDone) else g,
    ];
  }

  // Returns the goal and ALL its descendants (for cascading trash)
  List<SemesterGoal> getWithDescendants(String goalId) {
    final result = <SemesterGoal>[];
    void collect(String id) {
      final goal = state.where((g) => g.id == id).firstOrNull;
      if (goal == null) return;
      result.add(goal);
      for (final child in state.where((g) => g.parentId == id)) {
        collect(child.id);
      }
    }
    collect(goalId);
    return result;
  }

  void remove(String goalId) {
    final toRemove = getWithDescendants(goalId).map((g) => g.id).toSet();
    state = state.where((g) => !toRemove.contains(g.id)).toList();
  }

  void restore(SemesterGoal goal) {
    if (!state.any((g) => g.id == goal.id)) {
      final parentExists = goal.parentId == null ||
          state.any((g) => g.id == goal.parentId);
      state = [
        ...state,
        parentExists ? goal : goal.copyWith(parentId: null),
      ];
    }
  }
}

final semesterGoalsProvider =
    StateNotifierProvider<SemesterGoalsNotifier, List<SemesterGoal>>(
  (ref) => SemesterGoalsNotifier(),
);
