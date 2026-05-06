import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester_goal.dart';

class SemesterGoalsNotifier extends StateNotifier<List<SemesterGoal>> {
  SemesterGoalsNotifier() : super([]);

  void addGoal(String title) {
    state = [
      ...state,
      SemesterGoal(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title),
    ];
  }

  void removeGoal(String goalId) {
    state = state.where((g) => g.id != goalId).toList();
  }

  void addMilestone(String goalId, String title) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          g.copyWith(milestones: [
            ...g.milestones,
            Milestone(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: title,
            ),
          ])
        else
          g,
    ];
  }

  void toggleMilestone(String goalId, String milestoneId) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          g.copyWith(milestones: [
            for (final m in g.milestones)
              if (m.id == milestoneId) m.copyWith(isDone: !m.isDone) else m,
          ])
        else
          g,
    ];
  }

  void removeMilestone(String goalId, String milestoneId) {
    state = [
      for (final g in state)
        if (g.id == goalId)
          g.copyWith(milestones: g.milestones.where((m) => m.id != milestoneId).toList())
        else
          g,
    ];
  }
}

final semesterGoalsProvider =
    StateNotifierProvider<SemesterGoalsNotifier, List<SemesterGoal>>(
  (ref) => SemesterGoalsNotifier(),
);
