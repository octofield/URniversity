import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import 'date_provider.dart';

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super([]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows = await _db.from('tasks').select().eq('user_id', userId);
      state = (rows as List<dynamic>)
          .map((r) => Task.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _userId = null;
    }
  }

  void clear() {
    _userId = null;
    state = [];
  }

  void _upsert(Task task) {
    if (_userId == null) return;
    _db.from('tasks')
        .upsert({...task.toJson(), 'user_id': _userId})
        .catchError((_) {});
  }

  void _delete(String id) {
    if (_userId == null) return;
    _db.from('tasks').delete().eq('id', id).catchError((_) {});
  }

  void add(
    String title, {
    String? content,
    int priority = 1,
    DateTime? dueTime,
    RecurrenceRule? recurrence,
    String? linkedTargetId,
    String? linkedGoalId,
  }) {
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      dueTime: dueTime,
      priority: priority,
      createdAt: DateTime.now(),
      recurrence: recurrence,
      linkedTargetId: linkedTargetId,
      linkedGoalId: linkedGoalId,
    );
    state = [...state, task];
    _upsert(task);
  }

  void toggleOnDate(String id, DateTime date) {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null) return;

    final Task updated;
    if (task.recurrence == null || task.recurrence!.isNone) {
      updated = task.copyWith(isCompleted: !task.isCompleted);
    } else {
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final newDates = List<String>.from(task.completedDates);
      if (newDates.contains(key)) {
        newDates.remove(key);
      } else {
        newDates.add(key);
      }
      updated = task.copyWith(completedDates: newDates);
    }

    state = [for (final t in state) if (t.id == id) updated else t];
    _upsert(updated);
  }

  void toggle(String id) => toggleOnDate(id, DateTime.now());

  void update(Task task) {
    state = [for (final t in state) if (t.id == task.id) task else t];
    _upsert(task);
  }

  void remove(String id) {
    state = state.where((t) => t.id != id).toList();
    _delete(id);
  }

  void restore(Task task) {
    if (!state.any((t) => t.id == task.id)) {
      state = [...state, task];
      _upsert(task);
    }
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(
  (ref) => TasksNotifier(),
);

// 0 = all tasks, 1 = daily view, 2 = weekly view
final taskViewProvider = StateProvider<int>((ref) => 0);

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

bool _isRecurring(Task t) => t.recurrence != null && !t.recurrence!.isNone;

// Checks if a recurring task applies to the given date
bool _recurringAppliesTo(Task task, DateTime date) {
  final createdDay = _dateOnly(task.createdAt);
  final targetDay = _dateOnly(date);
  if (targetDay.isBefore(createdDay)) return false;
  switch (task.recurrence!.type) {
    case RecurrenceType.none:       return false;
    case RecurrenceType.daily:      return true;
    case RecurrenceType.weekly:
      return targetDay.difference(createdDay).inDays % 7 == 0;
    case RecurrenceType.monthly:
      return targetDay.day == createdDay.day;
    case RecurrenceType.everyNDays:
      return targetDay.difference(createdDay).inDays % task.recurrence!.interval == 0;
  }
}

// Daily view: recurring tasks by recurrence rule; non-recurring only if dueTime matches date
bool _taskAppliesTo(Task task, DateTime date) {
  if (_isRecurring(task)) return _recurringAppliesTo(task, date);
  if (task.dueTime == null) return false;
  return _dateOnly(task.dueTime!) == _dateOnly(date);
}

final filteredTasksProvider = Provider<List<Task>>((ref) {
  final all = ref.watch(tasksProvider);
  final taskView = ref.watch(taskViewProvider);

  if (taskView == 1) {
    final date = ref.watch(dateProvider);
    final matching = all.where((t) => _taskAppliesTo(t, date)).toList();
    final recurring = matching.where(_isRecurring).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final nonRecurring = matching.where((t) => !_isRecurring(t)).toList()
      ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
    return [...recurring, ...nonRecurring];
  }

  // All tasks: recurring first, then with dueTime, then without dueTime
  final recurring = all.where(_isRecurring).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final withDue = all.where((t) => !_isRecurring(t) && t.dueTime != null).toList()
    ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
  final withoutDue = all.where((t) => !_isRecurring(t) && t.dueTime == null).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return [...recurring, ...withDue, ...withoutDue];
});

final tasksForDateProvider = Provider.family<List<Task>, DateTime>((ref, date) {
  final all = ref.watch(tasksProvider);
  final matching = all.where((t) => _taskAppliesTo(t, date)).toList();
  final recurring = matching.where(_isRecurring).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final nonRecurring = matching.where((t) => !_isRecurring(t)).toList()
    ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
  return [...recurring, ...nonRecurring];
});
