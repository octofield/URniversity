import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import 'date_provider.dart';
import 'settings_provider.dart';

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super([]);

  String? _userId;
  SupabaseClient get _db => Supabase.instance.client;
  static const _localKey = 'guest_tasks';
  bool get _isGuest => _userId == 'guest';

  Future<void> loadGuest() async {
    _userId = 'guest';
    final p = await SharedPreferences.getInstance();
    final json = p.getString(_localKey);
    if (json != null) {
      state = (jsonDecode(json) as List)
          .map((j) => Task.fromJson(j as Map<String, dynamic>))
          .toList();
    } else {
      state = [];
    }
  }

  void _persistLocally() {
    SharedPreferences.getInstance().then((p) {
      p.setString(_localKey, jsonEncode(state.map((t) => t.toJson()).toList()));
    });
  }

  Future<void> load(String userId) async {
    if (_userId == userId) return;
    _userId = userId;
    try {
      final rows =
          await _db.from('tasks').select().eq('user_id', userId).order('sort_order');
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

  Future<void> mergeToUser(String userId) async {
    _userId = userId;
    for (final task in state) {
      try {
        await _db.from('tasks').upsert({...task.toJson(), 'user_id': userId});
      } catch (_) {}
    }
  }

  void _upsert(Task task) {
    if (_isGuest) { _persistLocally(); return; }
    if (_userId == null) return;
    _db.from('tasks')
        .upsert({...task.toJson(), 'user_id': _userId})
        .catchError((_) {});
  }

  void _delete(String id) {
    if (_isGuest) { _persistLocally(); return; }
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
    String? parentTaskId,
  }) {
    final maxOrder = state
        .where((t) => t.parentTaskId == parentTaskId)
        .fold(0, (prev, t) => t.sortOrder > prev ? t.sortOrder : prev);
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
      parentTaskId: parentTaskId,
      sortOrder: maxOrder + 1000,
    );
    state = [...state, task];
    _upsert(task);
  }

  // Moves a task within its own group, or between top level and a parent.
  // Subtasks are capped at one level: a task that has children can't become
  // a subtask, and a subtask can't gain children
  void reorderTask(String draggedId, String? newParentId, int newSortOrder) {
    if (draggedId == newParentId) return;
    final dragged = state.where((t) => t.id == draggedId).firstOrNull;
    if (dragged == null) return;
    if (newParentId != null) {
      // Can't nest under a subtask, and can't nest a task that has children
      final newParent = state.where((t) => t.id == newParentId).firstOrNull;
      if (newParent == null || newParent.parentTaskId != null) return;
      if (state.any((t) => t.parentTaskId == draggedId)) return;
    }
    final updated =
        dragged.copyWith(parentTaskId: newParentId, sortOrder: newSortOrder);
    state = [for (final t in state) if (t.id == draggedId) updated else t];
    _upsert(updated);
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

  // Returns every task actually removed (the task plus its subtasks) so the
  // caller can snapshot all of them to the trash — snapshotting only the root
  // would leave the subtasks unrestorable
  List<Task> remove(String id) {
    final removed = state
        .where((t) => t.id == id || t.parentTaskId == id)
        .toList();
    if (removed.isEmpty) return const [];
    final removedIds = removed.map((t) => t.id).toSet();
    state = state.where((t) => !removedIds.contains(t.id)).toList();
    for (final t in removed) {
      _delete(t.id);
    }
    return removed;
  }

  void restore(Task task) {
    if (!state.any((t) => t.id == task.id)) {
      // If the parent is gone, restore at top level rather than orphaning it
      final restored = task.parentTaskId != null &&
              !state.any((t) => t.id == task.parentTaskId)
          ? task.copyWith(parentTaskId: null)
          : task;
      state = [...state, restored];
      _upsert(restored);
    }
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(
  (ref) => TasksNotifier(),
);

// 0 = all tasks, 1 = daily view, 2 = weekly view
final taskViewProvider = StateProvider<int>((ref) => ref.read(defaultTaskViewProvider));

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
      // Chosen weekdays if set; otherwise fall back to "same weekday as
      // creation", which is how tasks created before this option behave
      final weekdays = task.recurrence!.weekdays;
      if (weekdays.isNotEmpty) return weekdays.contains(targetDay.weekday);
      return targetDay.difference(createdDay).inDays % 7 == 0;
    case RecurrenceType.monthly:
      final monthDays = task.recurrence!.monthDays;
      if (monthDays.isEmpty) return targetDay.day == createdDay.day;
      // A day the month doesn't have simply doesn't occur that month (e.g. 31
      // in February); kLastDayOfMonth resolves to whatever the last day is
      final lastDay = DateTime(targetDay.year, targetDay.month + 1, 0).day;
      return monthDays.any((d) =>
          d == kLastDayOfMonth ? targetDay.day == lastDay : targetDay.day == d);
    case RecurrenceType.everyNDays:
      // safeInterval guards against a 0 persisted before validation existed;
      // a raw 0 here throws on mobile and yields NaN on web
      return targetDay.difference(createdDay).inDays %
              task.recurrence!.safeInterval ==
          0;
  }
}

// Daily view: recurring tasks by recurrence rule; non-recurring only if dueTime matches date
bool _taskAppliesTo(Task task, DateTime date) {
  if (_isRecurring(task)) return _recurringAppliesTo(task, date);
  if (task.dueTime == null) return false;
  return _dateOnly(task.dueTime!) == _dateOnly(date);
}

// Manual drag order wins, with the automatic grouping above as the tiebreaker.
// Tasks that have never been dragged all share sortOrder 0, so the automatic
// order is what shows until the user actually reorders something
List<Task> _applyManualOrder(List<Task> autoOrdered) {
  final autoIndex = {
    for (var i = 0; i < autoOrdered.length; i++) autoOrdered[i].id: i,
  };
  return [...autoOrdered]..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return autoIndex[a.id]!.compareTo(autoIndex[b.id]!);
    });
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
    return _applyManualOrder([...recurring, ...nonRecurring]);
  }

  // All tasks: recurring first, then with dueTime, then without dueTime
  final recurring = all.where(_isRecurring).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final withDue = all.where((t) => !_isRecurring(t) && t.dueTime != null).toList()
    ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
  final withoutDue = all.where((t) => !_isRecurring(t) && t.dueTime == null).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return _applyManualOrder([...recurring, ...withDue, ...withoutDue]);
});

final taskTargetFilterProvider = StateProvider<Set<String>>((ref) => const {});
final taskGoalFilterProvider = StateProvider<Set<String>>((ref) => const {});

// Completion stats for a single day; null when no task applies that day
// (distinct from 0%, which means tasks existed but none were done)
({int done, int total})? taskCompletionStatsOn(List<Task> all, DateTime date) {
  final matching = all.where((t) => _taskAppliesTo(t, date)).toList();
  if (matching.isEmpty) return null;
  final done = matching.where((t) => t.isCompletedOn(date)).length;
  return (done: done, total: matching.length);
}

final tasksForDateProvider = Provider.family<List<Task>, DateTime>((ref, date) {
  final all = ref.watch(tasksProvider);
  final matching = all.where((t) => _taskAppliesTo(t, date)).toList();
  final recurring = matching.where(_isRecurring).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final nonRecurring = matching.where((t) => !_isRecurring(t)).toList()
    ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
  return _applyManualOrder([...recurring, ...nonRecurring]);
});
