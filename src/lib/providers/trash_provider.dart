import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trash_item.dart';
import '../models/task.dart';
import '../models/semester_goal.dart';
import '../models/future_goal.dart';

class TrashNotifier extends StateNotifier<List<TrashItem>> {
  TrashNotifier() : super([]);

  void addTask(Task task) {
    state = [TrashItem.fromTask(task), ...state];
  }

  void addSemesterGoal(SemesterGoal goal) {
    state = [TrashItem.fromSemesterGoal(goal), ...state];
  }

  void addFutureGoal(FutureGoal goal) {
    state = [TrashItem.fromFutureGoal(goal), ...state];
  }

  // Removes item from trash and returns it so the caller can restore it to its provider
  TrashItem? pop(String trashId) {
    final item = state.where((i) => i.id == trashId).firstOrNull;
    if (item != null) state = state.where((i) => i.id != trashId).toList();
    return item;
  }

  void permanentDelete(String trashId) {
    state = state.where((i) => i.id != trashId).toList();
  }

  void clear() => state = [];
}

final trashProvider = StateNotifierProvider<TrashNotifier, List<TrashItem>>(
  (ref) => TrashNotifier(),
);
