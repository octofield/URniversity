import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'synced_list_notifier.dart';
import 'future_goals_provider.dart';
import 'semester_goals_provider.dart';
import 'date_provider.dart';
import 'settings_provider.dart';

class TasksNotifier extends SyncedListNotifier<Task> {
  TasksNotifier(super.ref)
      : super(
          table: 'tasks',
          localKey: 'guest_tasks',
          orderColumn: 'sort_order',
        );

  @override
  Task fromJson(Map<String, dynamic> json) => Task.fromJson(json);

  @override
  Map<String, dynamic> toJson(Task item) => item.toJson();

  @override
  String idOf(Task item) => item.id;

  @override
  String? parentIdOf(Task item) => item.parentTaskId;

  // tasks has no parent_task_id foreign key, so an orphaned subtask only needs
  // re-attaching for consistency (see system_design.md UC6). The link columns do
  // have real foreign keys with ON DELETE SET NULL, but that only fires while
  // the task row exists — a task sitting in the trash keeps the id of a goal
  // deleted after it, and restoring it would insert a dangling reference
  @override
  Task sanitizeForRestore(Task item) {
    final parentGone =
        item.parentTaskId != null && !state.any((x) => x.id == item.parentTaskId);
    final targetGone = item.linkedTargetId != null &&
        !ref.read(semesterGoalsProvider).any((g) => g.id == item.linkedTargetId);
    final goalGone = item.linkedGoalId != null &&
        !ref.read(futureGoalsProvider).any((g) => g.id == item.linkedGoalId);
    if (!parentGone && !targetGone && !goalGone) return item;
    return item.copyWith(
      parentTaskId: parentGone ? null : item.parentTaskId,
      linkedTargetId: targetGone ? null : item.linkedTargetId,
      linkedGoalId: goalGone ? null : item.linkedGoalId,
    );
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
      id: newRowId(),
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
    upsert(task);
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
    upsert(updated);
  }

  void toggleOnDate(String id, DateTime date) {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null) return;

    // Task.toggledOn() holds the rule so the notification's background handler
    // can apply exactly the same one without a copy
    final updated = task.toggledOn(date);
    state = [for (final t in state) if (t.id == id) updated else t];
    upsert(updated);
  }

  void toggle(String id) => toggleOnDate(id, DateTime.now());

  void update(Task task) {
    state = [for (final t in state) if (t.id == task.id) task else t];
    upsert(task);
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
      deleteRow(t.id);
    }
    return removed;
  }

}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(
  (ref) => TasksNotifier(ref),
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

// Daily view: recurring tasks by recurrence rule; non-recurring only if dueTime matches date.
// Public because the notification scheduler needs the same answer and a second
// copy of this would drift from the one the UI uses
bool taskAppliesTo(Task task, DateTime date) {
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
    final matching = all.where((t) => taskAppliesTo(t, date)).toList();
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
  final matching = all.where((t) => taskAppliesTo(t, date)).toList();
  if (matching.isEmpty) return null;
  final done = matching.where((t) => t.isCompletedOn(date)).length;
  return (done: done, total: matching.length);
}

final tasksForDateProvider = Provider.family<List<Task>, DateTime>((ref, date) {
  final all = ref.watch(tasksProvider);
  final matching = all.where((t) => taskAppliesTo(t, date)).toList();
  final recurring = matching.where(_isRecurring).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final nonRecurring = matching.where((t) => !_isRecurring(t)).toList()
    ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
  return _applyManualOrder([...recurring, ...nonRecurring]);
});
