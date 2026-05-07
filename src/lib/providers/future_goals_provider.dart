import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/future_goal.dart';

class FutureGoalsNotifier extends StateNotifier<List<FutureGoal>> {
  FutureGoalsNotifier() : super([]);

  void addGoal({
    String? parentId,
    required String title,
    List<String> categories = const [FutureCategories.other],
    String? startSemester,
    String? endSemester,
    String? notes,
  }) {
    state = [
      ...state,
      FutureGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        parentId: parentId,
        title: title,
        categories: categories,
        startSemester: startSemester,
        endSemester: endSemester,
        notes: notes,
      ),
    ];
  }

  void updateGoal(
    String goalId, {
    required String title,
    required List<String> categories,
    String? startSemester,
    String? endSemester,
    String? notes,
  }) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          FutureGoal(
            id: g.id,
            parentId: g.parentId,
            title: title,
            categories: categories,
            startSemester: startSemester,
            endSemester: endSemester,
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
  List<FutureGoal> getWithDescendants(String goalId) {
    final result = <FutureGoal>[];
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

  void restore(FutureGoal goal) {
    if (!state.any((g) => g.id == goal.id)) {
      // If parent no longer exists, restore as top-level
      final parentExists = goal.parentId == null ||
          state.any((g) => g.id == goal.parentId);
      state = [
        ...state,
        parentExists ? goal : goal.copyWith(parentId: null),
      ];
    }
  }
}

final futureGoalsProvider =
    StateNotifierProvider<FutureGoalsNotifier, List<FutureGoal>>(
  (ref) => FutureGoalsNotifier(),
);
