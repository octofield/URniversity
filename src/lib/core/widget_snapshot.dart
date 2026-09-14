import 'dart:convert';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart'
    show taskAppliesTo, expandSemGoalIds, expandFutureGoalIds, passesTaskFilter;
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';

// What the widget is currently showing.
//
// The picker is a screen rather than a dialog because a home screen widget has
// no room for one: it reuses the same list, swapping in selectable rows.
enum WidgetMode { tasks, targets, goals, filterPicker }

// Only meaningful in [WidgetMode.tasks]
enum WidgetPeriod { day, week, month }

enum WidgetFilterKind { none, target, goal }

// Persisted between interactions. Small enough to live beside the snapshot
class WidgetState {
  final WidgetMode mode;
  final WidgetPeriod period;
  final WidgetFilterKind filterKind;
  final String? filterId;

  const WidgetState({
    this.mode = WidgetMode.tasks,
    this.period = WidgetPeriod.day,
    this.filterKind = WidgetFilterKind.none,
    this.filterId,
  });

  WidgetState copyWith({
    WidgetMode? mode,
    WidgetPeriod? period,
    WidgetFilterKind? filterKind,
    Object? filterId = _absent,
  }) =>
      WidgetState(
        mode: mode ?? this.mode,
        period: period ?? this.period,
        filterKind: filterKind ?? this.filterKind,
        filterId: filterId == _absent ? this.filterId : filterId as String?,
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'period': period.name,
        'filter_kind': filterKind.name,
        'filter_id': filterId,
      };

  // Every field falls back to its default. This is read in a background
  // isolate, where a payload written by an older build must not throw
  factory WidgetState.fromJson(Map<String, dynamic> j) => WidgetState(
        mode: _enumByName(WidgetMode.values, j['mode']) ?? WidgetMode.tasks,
        period: _enumByName(WidgetPeriod.values, j['period']) ?? WidgetPeriod.day,
        filterKind: _enumByName(WidgetFilterKind.values, j['filter_kind']) ??
            WidgetFilterKind.none,
        filterId: j['filter_id'] as String?,
      );

  static WidgetState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const WidgetState();
    try {
      return WidgetState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const WidgetState();
    }
  }

  String encode() => jsonEncode(toJson());
}

const Object _absent = Object();

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

// Whether a row shows a tick box, and its state. Section headers show none
enum WidgetCheck { none, unchecked, checked }

// One line in the widget's list. The native side renders exactly this and
// knows nothing about tasks, goals or filters
class WidgetRow {
  final String title;
  final String? subtitle;
  // ARGB. 0 means no colour bar on this row
  final int colorArgb;
  final WidgetCheck check;
  // What tapping the row body does; null makes the row inert (section headers)
  final String? tapAction;
  // What tapping the tick box does. Null whenever [check] is none
  final String? checkAction;
  final bool isHeader;

  const WidgetRow({
    required this.title,
    this.subtitle,
    this.colorArgb = 0,
    this.check = WidgetCheck.none,
    this.tapAction,
    this.checkAction,
    this.isHeader = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'color': colorArgb,
        'check': check.name,
        'tap': tapAction,
        'check_action': checkAction,
        'header': isHeader,
      };
}

class WidgetSnapshot {
  final WidgetState state;
  final List<WidgetRow> rows;
  // Shown when [rows] is empty, e.g. "今天沒有任務"
  final String emptyLabel;
  // The current filter's name, for the header button
  final String filterLabel;

  const WidgetSnapshot({
    required this.state,
    required this.rows,
    required this.emptyLabel,
    required this.filterLabel,
  });

  Map<String, dynamic> toJson() => {
        ...state.toJson(),
        'empty': emptyLabel,
        'filter_label': filterLabel,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());
}

// Everything the widget should display right now.
//
// Pure: no plugin, no platform, no providers. The foreground sync and the
// background isolate both call this, so what the widget shows can never depend
// on which of them happened to run
WidgetSnapshot buildWidgetSnapshot({
  required List<Task> tasks,
  required List<SemesterGoal> semesterGoals,
  required List<FutureGoal> futureGoals,
  required List<CategoryEntry> categories,
  required WidgetState state,
  required SemesterSettings semesterSettings,
  required AppStrings s,
  required DateTime now,
}) {
  final rows = switch (state.mode) {
    WidgetMode.tasks => _taskRows(
        tasks, semesterGoals, futureGoals, categories, state, s, now),
    WidgetMode.targets => _targetRows(semesterGoals, categories, s),
    WidgetMode.goals => _goalRows(futureGoals, categories, s),
    WidgetMode.filterPicker =>
      _filterPickerRows(semesterGoals, futureGoals, categories, semesterSettings, s, now),
  };

  return WidgetSnapshot(
    state: state,
    rows: rows,
    emptyLabel: switch (state.mode) {
      WidgetMode.tasks => s.noTasks,
      WidgetMode.targets => s.noTargets,
      WidgetMode.goals => s.noGoals,
      WidgetMode.filterPicker => s.noTargets,
    },
    filterLabel: _filterLabel(state, semesterGoals, futureGoals, s),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// The last day the current period covers. Week is the next seven days rather
// than a calendar week: on a widget, "what is coming up" beats "what Monday to
// Sunday holds", which would show almost nothing on a Saturday
DateTime _periodEnd(WidgetPeriod period, DateTime today) => switch (period) {
      WidgetPeriod.day => today,
      WidgetPeriod.week => today.add(const Duration(days: 6)),
      // Day 0 of next month is the last day of this one
      WidgetPeriod.month => DateTime(today.year, today.month + 1, 0),
    };

int _colorForCategories(List<CategoryEntry> categories, List<String> cats) =>
    cats.isEmpty ? 0 : resolveCatColor(categories, cats.first).toARGB32();

List<WidgetRow> _taskRows(
  List<Task> tasks,
  List<SemesterGoal> semesterGoals,
  List<FutureGoal> futureGoals,
  List<CategoryEntry> categories,
  WidgetState state,
  AppStrings s,
  DateTime now,
) {
  final today = _dateOnly(now);
  final end = _periodEnd(state.period, today);

  final targetIds = state.filterKind == WidgetFilterKind.target && state.filterId != null
      ? expandSemGoalIds({state.filterId!}, semesterGoals)
      : <String>{};
  final goalIds = state.filterKind == WidgetFilterKind.goal && state.filterId != null
      ? expandFutureGoalIds({state.filterId!}, futureGoals)
      : <String>{};

  // One row per task, not one per occurrence: a daily task over a month would
  // otherwise fill the whole list by itself. The subtitle carries the soonest
  // day it is still outstanding
  final due = <String, DateTime>{};
  final byId = <String, Task>{};

  for (final task in tasks) {
    if (task.parentTaskId != null) continue;
    if (!passesTaskFilter(task, targetIds, goalIds)) continue;

    for (var day = today; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      if (!taskAppliesTo(task, day)) continue;
      if (task.isCompletedOn(day)) continue;
      due[task.id] = day;
      byId[task.id] = task;
      break;
    }
  }

  final ordered = due.entries.toList()
    ..sort((a, b) {
      final byDay = a.value.compareTo(b.value);
      if (byDay != 0) return byDay;
      return byId[a.key]!.sortOrder.compareTo(byId[b.key]!.sortOrder);
    });

  return [
    for (final entry in ordered)
      () {
        final task = byId[entry.key]!;
        final linkedCats = _taskCategories(task, semesterGoals, futureGoals);
        return WidgetRow(
          title: task.title,
          subtitle: _taskSubtitle(task, entry.value, today, s),
          colorArgb: _colorForCategories(categories, linkedCats),
          check: WidgetCheck.unchecked,
          tapAction: WidgetAction.openItem(kind: 'task', id: task.id),
          checkAction: WidgetAction.toggleDone(taskId: task.id, date: entry.value),
        );
      }(),
  ];
}

// The colour comes from whatever the task is linked to, matching the colour bar
// the task list already draws in the app
List<String> _taskCategories(
  Task task,
  List<SemesterGoal> semesterGoals,
  List<FutureGoal> futureGoals,
) {
  if (task.linkedTargetId != null) {
    final target =
        semesterGoals.where((g) => g.id == task.linkedTargetId).firstOrNull;
    if (target != null) return target.categories;
  }
  if (task.linkedGoalId != null) {
    final goal = futureGoals.where((g) => g.id == task.linkedGoalId).firstOrNull;
    if (goal != null) return goal.categories;
  }
  return const [];
}

String? _taskSubtitle(Task task, DateTime day, DateTime today, AppStrings s) {
  final parts = <String>[
    if (day != today) '${day.month}/${day.day}',
    if (task.dueTime != null)
      '${task.dueTime!.hour.toString().padLeft(2, '0')}:'
          '${task.dueTime!.minute.toString().padLeft(2, '0')}',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

// Top level only, with the progress of their direct children — the same
// done/total the semester screen shows on each card
List<WidgetRow> _targetRows(
  List<SemesterGoal> goals,
  List<CategoryEntry> categories,
  AppStrings s,
) {
  final top = goals.where((g) => g.parentId == null).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  return [
    for (final goal in top)
      () {
        final children = goals.where((g) => g.parentId == goal.id).toList();
        final done = children.where((g) => g.isDone).length;
        return WidgetRow(
          title: goal.title,
          subtitle: children.isEmpty
              ? goal.semester
              : '${goal.semester}  ${s.goalProgress(done, children.length)}',
          colorArgb: _colorForCategories(categories, goal.categories),
          check: goal.isDone ? WidgetCheck.checked : WidgetCheck.none,
          tapAction: WidgetAction.openItem(kind: 'semesterGoal', id: goal.id),
        );
      }(),
  ];
}

List<WidgetRow> _goalRows(
  List<FutureGoal> goals,
  List<CategoryEntry> categories,
  AppStrings s,
) {
  final top = goals.where((g) => g.parentId == null).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  return [
    for (final goal in top)
      () {
        final children = goals.where((g) => g.parentId == goal.id).toList();
        final done = children.where((g) => g.isDone).length;
        return WidgetRow(
          title: goal.title,
          subtitle: children.isEmpty
              ? null
              : s.goalProgress(done, children.length),
          colorArgb: _colorForCategories(categories, goal.categories),
          check: goal.isDone ? WidgetCheck.checked : WidgetCheck.none,
          tapAction: WidgetAction.openItem(kind: 'futureGoal', id: goal.id),
        );
      }(),
  ];
}

// Targets are grouped under their semester; visions are not, because a vision
// spans a range of semesters rather than belonging to one. Past semesters are
// left out — filtering today's tasks by a finished semester's target is not
// something anyone reaches for from a home screen
List<WidgetRow> _filterPickerRows(
  List<SemesterGoal> semesterGoals,
  List<FutureGoal> futureGoals,
  List<CategoryEntry> categories,
  SemesterSettings settings,
  AppStrings s,
  DateTime now,
) {
  final rows = <WidgetRow>[
    WidgetRow(title: s.catAll, tapAction: WidgetAction.setFilter()),
  ];

  final today = _dateOnly(now);
  final topTargets = semesterGoals.where((g) => g.parentId == null).toList();
  final semesters = topTargets.map((g) => g.semester).toSet().toList()
    ..sort(compareSemesters);

  for (final semester in semesters) {
    // Skip a semester that already ended
    if (semesterEnd(semester, settings).isBefore(today)) continue;

    final inSemester = topTargets.where((g) => g.semester == semester).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (inSemester.isEmpty) continue;

    rows.add(WidgetRow(
      title: formatSemester(semester, settings, s),
      isHeader: true,
    ));
    for (final goal in inSemester) {
      rows.add(WidgetRow(
        title: goal.title,
        colorArgb: _colorForCategories(categories, goal.categories),
        tapAction: WidgetAction.setFilter(kind: WidgetFilterKind.target, id: goal.id),
      ));
    }
  }

  final topGoals = futureGoals.where((g) => g.parentId == null).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  if (topGoals.isNotEmpty) {
    rows.add(WidgetRow(title: s.goals, isHeader: true));
    for (final goal in topGoals) {
      rows.add(WidgetRow(
        title: goal.title,
        colorArgb: _colorForCategories(categories, goal.categories),
        tapAction: WidgetAction.setFilter(kind: WidgetFilterKind.goal, id: goal.id),
      ));
    }
  }

  return rows;
}

String _filterLabel(
  WidgetState state,
  List<SemesterGoal> semesterGoals,
  List<FutureGoal> futureGoals,
  AppStrings s,
) {
  final id = state.filterId;
  if (id == null) return s.filters;
  return switch (state.filterKind) {
    WidgetFilterKind.target =>
      semesterGoals.where((g) => g.id == id).firstOrNull?.title ?? s.filters,
    WidgetFilterKind.goal =>
      futureGoals.where((g) => g.id == id).firstOrNull?.title ?? s.filters,
    WidgetFilterKind.none => s.filters,
  };
}

// The action URIs the widget sends back. Kept beside the rows that carry them
// so a renamed action cannot go unnoticed on one side
class WidgetAction {
  static const scheme = 'urniversity';

  // Hosts are lower case on purpose: Uri.host lower-cases whatever it is
  // given, so a camelCase host would never match on the way back
  static String toggleDone({required String taskId, required DateTime date}) =>
      '$scheme://toggle?id=$taskId&date=${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static String switchMode(WidgetMode mode) => '$scheme://mode?value=${mode.name}';

  static String switchPeriod(WidgetPeriod period) =>
      '$scheme://period?value=${period.name}';

  static String setFilter({
    WidgetFilterKind kind = WidgetFilterKind.none,
    String? id,
  }) =>
      '$scheme://filter?kind=${kind.name}${id == null ? '' : '&id=$id'}';

  static String openItem({required String kind, required String id}) =>
      '$scheme://open?kind=$kind&id=$id';
}
