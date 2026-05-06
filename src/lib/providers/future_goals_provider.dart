import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/future_goal.dart';

class FutureGoalsNotifier extends StateNotifier<List<FutureGoal>> {
  FutureGoalsNotifier() : super([]);

  void addGoal({
    required String title,
    FutureCategory category = FutureCategory.other,
    String? startTime,
    String? endTime,
  }) {
    state = [
      ...state,
      FutureGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        startTime: startTime,
        endTime: endTime,
      ),
    ];
  }

  void removeGoal(String goalId) {
    state = state.where((g) => g.id != goalId).toList();
  }

  void addSubgoal(String goalId, String title) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          g.copyWith(subgoals: [
            ...g.subgoals,
            Subgoal(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
            ),
          ])
        else
          g,
    ];
  }

  void toggleSubgoal(String goalId, String subgoalId) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          g.copyWith(subgoals: [
            for (final s in g.subgoals)
              if (s.id == subgoalId) s.copyWith(isDone: !s.isDone) else s,
          ])
        else
          g,
    ];
  }

  void removeSubgoal(String goalId, String subgoalId) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          g.copyWith(subgoals: g.subgoals.where((s) => s.id != subgoalId).toList())
        else
          g,
    ];
  }
}

final futureGoalsProvider =
    StateNotifierProvider<FutureGoalsNotifier, List<FutureGoal>>(
  (ref) => FutureGoalsNotifier(),
);
