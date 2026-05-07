import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super([]);

  void add(
    String title, {
    String? content,
    int priority = 1,
    DateTime? dueTime,
    RecurrenceRule? recurrence,
    String? linkedTargetId,
    String? linkedGoalId,
  }) {
    state = [
      ...state,
      Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        dueTime: dueTime,
        priority: priority,
        createdAt: DateTime.now(),
        recurrence: recurrence,
        linkedTargetId: linkedTargetId,
        linkedGoalId: linkedGoalId,
      ),
    ];
  }

  void toggle(String id) {
    state = [
      for (final task in state)
        if (task.id == id) task.copyWith(isCompleted: !task.isCompleted) else task,
    ];
  }

  void update(Task task) {
    state = [for (final t in state) if (t.id == task.id) task else t];
  }

  void remove(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  void restore(Task task) {
    if (!state.any((t) => t.id == task.id)) {
      state = [...state, task];
    }
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(
  (ref) => TasksNotifier(),
);
