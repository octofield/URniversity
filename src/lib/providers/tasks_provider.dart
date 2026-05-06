import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super([]);

  void add(String title, {String? content, int priority = 1, DateTime? dueTime}) {
    state = [
      ...state,
      Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        dueTime: dueTime,
        priority: priority,
        createdAt: DateTime.now(),
      ),
    ];
  }

  void toggle(String id) {
    state = [
      for (final task in state)
        if (task.id == id) task.copyWith(isCompleted: !task.isCompleted) else task,
    ];
  }

  void remove(String id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(
  (ref) => TasksNotifier(),
);
