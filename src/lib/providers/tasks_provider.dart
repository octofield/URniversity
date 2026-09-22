import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import 'sort_prefs.dart';
import 'synced_list_notifier.dart';
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

  // Tasks are a flat list: the column survives from the subtask feature but
  // nothing writes it, so no task waits on another to be merged first
  @override
  String? parentIdOf(Task item) => null;

  // linked_target_id has a real foreign key with ON DELETE SET NULL, but that
  // only fires while the task row exists — a task sitting in the trash keeps
  // the id of a goal deleted after it, and restoring it would insert a dangling
  // reference (see system_design.md UC6)
  @override
  Task sanitizeForRestore(Task item) {
    final targetGone = item.linkedTargetId != null &&
        !ref.read(semesterGoalsProvider).any((g) => g.id == item.linkedTargetId);
    if (!targetGone) return item;
    return item.copyWith(linkedTargetId: null);
  }

  void add(
    String title, {
    String? content,
    DateTime? dueTime,
    RecurrenceRule? recurrence,
    String? linkedTargetId,
  }) {
    // Newest first: one step before the smallest there is, so a new task lands
    // on top without moving anything the user has dragged
    final minOrder =
        state.fold(0, (prev, t) => t.sortOrder < prev ? t.sortOrder : prev);
    final task = Task(
      id: newRowId(),
      title: title,
      content: content,
      dueTime: dueTime,
      createdAt: DateTime.now(),
      recurrence: recurrence,
      linkedTargetId: linkedTargetId,
      sortOrder: minOrder - 1000,
    );
    state = [...state, task];
    upsert(task);
  }

  // Moves a task within the list. There is no nesting: a drop is only ever a
  // new position
  void reorderTask(String draggedId, int newSortOrder) {
    final dragged = state.where((t) => t.id == draggedId).firstOrNull;
    if (dragged == null) return;
    final updated = dragged.copyWith(sortOrder: newSortOrder);
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

    // The reminder stays on screen until the task is actually done, so this is
    // where it comes down. Not awaited: the tick must not wait on the shade
    if (updated.isCompletedOn(date)) {
      unawaited(NotificationService.instance.cancelForTask(id));
    }
  }

  void toggle(String id) => toggleOnDate(id, DateTime.now());

  void update(Task task) {
    state = [for (final t in state) if (t.id == task.id) task else t];
    upsert(task);
  }

  // Returns the removed task as a list so the caller can snapshot it to the
  // trash the same way the goal providers do
  List<Task> remove(String id) {
    final removed = state.where((t) => t.id == id).toList();
    if (removed.isEmpty) return const [];
    state = state.where((t) => t.id != id).toList();
    deleteRow(id);
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

// Which occurrence of a task is the one being looked at right now.
//
// A recurring task answers with today when the rule matches, otherwise with the
// most recent day it did — so the monthly task created for the 20th is still
// "this month's" on the 21st, and ticking it off there marks that occurrence
// rather than an unrelated day. A rule that has not come round yet answers with
// its first day instead. Non-recurring tasks answer with their due day.
DateTime? currentOccurrence(Task task, DateTime now) {
  final today = _dateOnly(now);
  if (!_isRecurring(task)) {
    return task.dueTime == null ? null : _dateOnly(task.dueTime!);
  }

  // A year each way: enough for every rule the app offers, and bounded so a
  // task created long ago cannot turn this into a long walk
  final createdDay = _dateOnly(task.createdAt);
  for (var i = 0; i <= 366; i++) {
    final day = today.subtract(Duration(days: i));
    if (day.isBefore(createdDay)) break;
    if (taskAppliesTo(task, day)) return day;
  }
  for (var i = 1; i <= 366; i++) {
    final day = today.add(Duration(days: i));
    if (taskAppliesTo(task, day)) return day;
  }
  return null;
}

// The day a row in the current view is about. The day and week views are about
// the date being shown; the all-tasks view is about each task's own current
// occurrence, which is what lets a finished monthly task drop out of the list
// until the 20th comes round again
final taskRowDateProvider = Provider.family<DateTime, Task>((ref, task) {
  final selected = ref.watch(dateProvider);
  if (ref.watch(taskViewProvider) != 0) return selected;
  return currentOccurrence(task, ref.watch(effectiveNowProvider)) ?? selected;
});

// Manual drag order wins, with the automatic grouping above as the tiebreaker.
// Tasks that have never been dragged all share sortOrder 0, so the automatic
// order is what shows until the user actually reorders something
// How the task list is ordered. Manual is the drag order the user set
// themselves; the rest answer a question ("what is due next?", "what belongs to
// this target?") and switch dragging off while they are on, because a drag
// would write an order nothing on screen reflects.
enum TaskSort { manual, created, title, target, due }

final taskSortProvider = StateNotifierProvider<EnumPrefNotifier<TaskSort>, TaskSort>(
  (ref) => EnumPrefNotifier('task_sort', TaskSort.values, TaskSort.manual),
);

// Whether the list shows drag handles. Held in memory only: coming back to the
// app in the middle of rearranging is not something to restore
final taskSortModeProvider = StateProvider<bool>((ref) => false);

// Orders a list that is already in the app's automatic order (recurring first,
// then by due time), which is what decides ties: two tasks created in the same
// minute, or both linked to the same target, keep the order the list already
// had rather than swapping about on every rebuild.
List<Task> applyTaskSort(
  List<Task> autoOrdered,
  TaskSort sort, {
  Map<String, String> targetTitles = const {},
}) {
  if (sort == TaskSort.manual) return _applyManualOrder(autoOrdered);

  final autoIndex = {
    for (var i = 0; i < autoOrdered.length; i++) autoOrdered[i].id: i,
  };

  int compare(Task a, Task b) {
    switch (sort) {
      case TaskSort.created:
        // Newest first, the same way the lists put new items on top
        return b.createdAt.compareTo(a.createdAt);
      case TaskSort.title:
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      case TaskSort.target:
        // Grouped by the target's name; anything unlinked goes last
        final at = targetTitles[a.linkedTargetId];
        final bt = targetTitles[b.linkedTargetId];
        if (at == null || bt == null) {
          if (at == null && bt == null) return 0;
          return at == null ? 1 : -1;
        }
        return at.toLowerCase().compareTo(bt.toLowerCase());
      case TaskSort.due:
        // Soonest first; no due time at all goes last
        final ad = a.dueTime;
        final bd = b.dueTime;
        if (ad == null || bd == null) {
          if (ad == null && bd == null) return 0;
          return ad == null ? 1 : -1;
        }
        return ad.compareTo(bd);
      case TaskSort.manual:
        return 0;
    }
  }

  return [...autoOrdered]..sort((a, b) {
      final byKey = compare(a, b);
      return byKey != 0 ? byKey : autoIndex[a.id]!.compareTo(autoIndex[b.id]!);
    });
}

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
  final sort = ref.watch(taskSortProvider);
  final targetTitles = ref.watch(taskTargetTitlesProvider);

  if (taskView == 1) {
    final date = ref.watch(dateProvider);
    final matching = all.where((t) => taskAppliesTo(t, date)).toList();
    final recurring = matching.where(_isRecurring).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final nonRecurring = matching.where((t) => !_isRecurring(t)).toList()
      ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
    return applyTaskSort([...recurring, ...nonRecurring], sort,
        targetTitles: targetTitles);
  }

  // All tasks: recurring first, then with dueTime, then without dueTime
  final recurring = all.where(_isRecurring).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final withDue = all.where((t) => !_isRecurring(t) && t.dueTime != null).toList()
    ..sort((a, b) => a.dueTime!.compareTo(b.dueTime!));
  final withoutDue = all.where((t) => !_isRecurring(t) && t.dueTime == null).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return applyTaskSort([...recurring, ...withDue, ...withoutDue], sort,
      targetTitles: targetTitles);
});

// Target titles by id, for the "by target" sort. Its own provider so the sort
// does not have to know where targets come from
final taskTargetTitlesProvider = Provider<Map<String, String>>((ref) => {
      for (final goal in ref.watch(semesterGoalsProvider)) goal.id: goal.title,
    });

// Goal-link filtering. Public and living here rather than inside today_screen
// because the home screen widget applies the same rule, and the widget's copy
// would drift from the one the user sees in the app.

// A task passes when it is linked to any selected target. An empty selection
// means "no filter", not "nothing matches"
bool passesTaskFilter(Task t, Set<String> targetIds) {
  if (targetIds.isEmpty) return true;
  return t.linkedTargetId != null && targetIds.contains(t.linkedTargetId);
}

// Selecting a parent has to catch tasks linked to its children too, otherwise
// filtering by a target silently hides the work done under its milestones
Set<String> expandSemGoalIds(Set<String> selected, List<SemesterGoal> all) {
  if (selected.isEmpty) return selected;
  final expanded = Set<String>.from(selected);
  void collect(String parentId) {
    for (final g in all.where((g) => g.parentId == parentId)) {
      if (expanded.add(g.id)) collect(g.id);
    }
  }

  for (final id in List<String>.from(selected)) {
    collect(id);
  }
  return expanded;
}

final taskTargetFilterProvider = StateProvider<Set<String>>((ref) => const {});

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
