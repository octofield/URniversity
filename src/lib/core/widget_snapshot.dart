import 'dart:convert';

import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/course.dart';
import '../models/future_goal.dart';
import '../providers/courses_provider.dart' show TermInfo;
import 'review_stats.dart' show termAt;
import 'timetable.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart' show taskAppliesTo;
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';

// What the widget is showing. Owned by the native side now: switching is done
// there without waking Dart, so these names are only the vocabulary the action
// URIs and the snapshot keys share with Kotlin
enum WidgetMode { tasks, targets, goals, classes, filterPicker }

// `all` is first because it sits leftmost in the widget's period row
enum WidgetPeriod { all, day, week, month }

enum WidgetFilterKind { none, target, goal }

// Whether a row shows a tick box, and its state. Section headers show none
enum WidgetCheck { none, unchecked, checked }

// One line in the widget's list. The native side renders exactly this
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
  // Every target and vision id this task counts under: what it links to plus
  // all of their ancestors. The native side keeps a row when the selected
  // filter id is in here, so picking a parent still catches the work linked to
  // its milestones without Kotlin knowing anything about trees
  final List<String> filters;

  const WidgetRow({
    required this.title,
    this.subtitle,
    this.colorArgb = 0,
    this.check = WidgetCheck.none,
    this.tapAction,
    this.checkAction,
    this.isHeader = false,
    this.filters = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'color': colorArgb,
        'check': check.name,
        'tap': tapAction,
        'check_action': checkAction,
        'header': isHeader,
        'filters': filters,
      };
}

// Every screen the widget can show, computed up front.
//
// Switching tab, period or filter used to go through a background Flutter
// engine and five Supabase queries — over a second per tap. With every view
// already here, the native side switches by picking a different list
class WidgetSnapshot {
  // Keyed by [viewKey]
  final Map<String, List<WidgetRow>> views;
  // Shown when a view is empty, keyed like [views] minus the period suffix
  final Map<String, String> emptyLabels;
  // The filter button's label when nothing is selected
  final String filterDefaultLabel;
  // Title for every target and vision id, so the filter button can name the
  // current selection without another round trip
  final Map<String, String> filterLabels;

  const WidgetSnapshot({
    required this.views,
    required this.emptyLabels,
    required this.filterDefaultLabel,
    required this.filterLabels,
  });

  static String viewKey(WidgetMode mode, [WidgetPeriod period = WidgetPeriod.day]) =>
      switch (mode) {
        WidgetMode.tasks => 'tasks_${period.name}',
        WidgetMode.targets => 'targets',
        WidgetMode.goals => 'goals',
        WidgetMode.classes => 'classes',
        WidgetMode.filterPicker => 'filter_picker',
      };

  Map<String, dynamic> toJson() => {
        'views': {
          for (final entry in views.entries)
            entry.key: entry.value.map((r) => r.toJson()).toList(),
        },
        'empty': emptyLabels,
        'filter_default': filterDefaultLabel,
        'filter_labels': filterLabels,
      };

  String encode() => jsonEncode(toJson());
}

// Everything the widget can display right now.
//
// Pure: no plugin, no platform, no providers. The foreground sync and the
// background engine both call this, so what the widget shows can never depend
// on which of them happened to run
WidgetSnapshot buildWidgetSnapshot({
  required List<Task> tasks,
  required List<SemesterGoal> semesterGoals,
  required List<FutureGoal> futureGoals,
  required List<CategoryEntry> categories,
  required SemesterSettings semesterSettings,
  required AppStrings s,
  required DateTime now,
  List<Course> courses = const [],
  Map<String, TermInfo> terms = const {},
}) {
  final targetParents = {for (final g in semesterGoals) g.id: g.parentId};

  return WidgetSnapshot(
    views: {
      for (final period in WidgetPeriod.values)
        WidgetSnapshot.viewKey(WidgetMode.tasks, period): _taskRows(tasks,
            semesterGoals, futureGoals, categories, targetParents, period, now),
      WidgetSnapshot.viewKey(WidgetMode.targets): _targetRows(semesterGoals, categories, s),
      WidgetSnapshot.viewKey(WidgetMode.goals): _goalRows(futureGoals, categories, s),
      WidgetSnapshot.viewKey(WidgetMode.classes): _classRows(courses, terms, semesterSettings, s, now),
      WidgetSnapshot.viewKey(WidgetMode.filterPicker): _filterPickerRows(
          semesterGoals, futureGoals, categories, semesterSettings, s, now),
    },
    emptyLabels: {
      'tasks': s.noTasks,
      'targets': s.noTargets,
      'goals': s.noGoals,
      'classes': s.widgetNoClasses,
      'filter_picker': s.noTargets,
    },
    filterDefaultLabel: s.filters,
    filterLabels: {
      for (final g in semesterGoals) g.id: g.title,
      for (final g in futureGoals) g.id: g.title,
    },
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// The last day the current period covers. Week is the next seven days rather
// than a calendar week: on a widget, "what is coming up" beats "what Monday to
// Sunday holds", which would show almost nothing on a Saturday
DateTime _periodEnd(WidgetPeriod period, DateTime today) => switch (period) {
      // "All" has no end; a year is how far ahead a recurring task is searched
      // for its next outstanding day before it is treated as having none
      WidgetPeriod.all => today.add(const Duration(days: 365)),
      WidgetPeriod.day => today,
      WidgetPeriod.week => today.add(const Duration(days: 6)),
      // Day 0 of next month is the last day of this one
      WidgetPeriod.month => DateTime(today.year, today.month + 1, 0),
    };

// A task that carries neither a due time nor a recurrence never lands on a
// day, so only the "all" view can show it
bool _isUndated(Task task) =>
    task.dueTime == null && (task.recurrence == null || task.recurrence!.isNone);

int _colorForCategories(List<CategoryEntry> categories, List<String> cats) =>
    cats.isEmpty ? 0 : resolveCatColor(categories, cats.first).toARGB32();

// An id plus every ancestor above it. A dangling id is kept on its own, and a
// parent loop stops at the first repeat rather than spinning
List<String> _withAncestors(String? id, Map<String, String?> parents) {
  if (id == null) return const [];
  final out = <String>[];
  String? current = id;
  while (current != null && !out.contains(current)) {
    out.add(current);
    current = parents[current];
  }
  return out;
}

List<WidgetRow> _taskRows(
  List<Task> tasks,
  List<SemesterGoal> semesterGoals,
  List<FutureGoal> futureGoals,
  List<CategoryEntry> categories,
  Map<String, String?> targetParents,
  WidgetPeriod period,
  DateTime now,
) {
  final today = _dateOnly(now);
  final end = _periodEnd(period, today);

  // One row per task, not one per occurrence: a daily task over a month would
  // otherwise fill the whole list by itself. The subtitle carries the soonest
  // day it is still outstanding; a task with no day at all carries none
  final dated = <({Task task, DateTime day})>[];
  final undated = <Task>[];

  for (final task in tasks) {
    if (_isUndated(task)) {
      // Matches the app's "all tasks" view, which hides one once it is ticked
      // off for today
      if (period == WidgetPeriod.all && !task.isCompletedOn(today)) {
        undated.add(task);
      }
      continue;
    }

    for (var day = today; !day.isAfter(end); day = day.add(const Duration(days: 1))) {
      if (!taskAppliesTo(task, day)) continue;
      if (task.isCompletedOn(day)) continue;
      dated.add((task: task, day: day));
      break;
    }
  }

  dated.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    if (byDay != 0) return byDay;
    return a.task.sortOrder.compareTo(b.task.sortOrder);
  });
  undated.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  WidgetRow rowFor(Task task, DateTime? day) {
    final target = semesterGoals
        .where((g) => g.id == task.linkedTargetId)
        .firstOrNull;
    // The same rule the app's own rows follow: the target's category, or the
    // category of the vision it hangs off when it has none of its own
    final colour = taskLinkColor(categories, target,
        targetVision: visionOf(target, futureGoals));
    return WidgetRow(
      title: task.title,
      subtitle: _taskSubtitle(task, day, today),
      colorArgb: colour?.toARGB32() ?? 0,
      check: WidgetCheck.unchecked,
      tapAction: WidgetAction.openItem(kind: 'task', id: task.id),
      // A task with no day of its own is ticked off against today, the same
      // day the app's own list would tick it off against
      checkAction: WidgetAction.toggleDone(taskId: task.id, date: day ?? today),
      filters: _withAncestors(task.linkedTargetId, targetParents),
    );
  }

  return [
    for (final entry in dated) rowFor(entry.task, entry.day),
    // Tasks with no date sit after the dated ones rather than at the top
    for (final task in undated) rowFor(task, null),
  ];
}

// Null rather than an empty string when there is nothing to say, so the native
// side hides the line and the title centres on its own
String? _taskSubtitle(Task task, DateTime? day, DateTime today) {
  final parts = <String>[
    if (day != null && day != today) '${day.month}/${day.day}',
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

  return rows;
}

String _hm(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

// The "Classes" tab (§3-S): what is left of today's classes, and once they are
// all over, tomorrow's under a header. A day outside its semester's teaching
// weeks (once a first day is known) has none
List<WidgetRow> _classRows(
  List<Course> courses,
  Map<String, TermInfo> terms,
  SemesterSettings semesterSettings,
  AppStrings s,
  DateTime now,
) {
  List<ClassMeeting> on(DateTime day) {
    final semester = termAt(day, semesterSettings);
    final term = terms[semester];
    if (term != null && !inTerm(day, term.firstDay, term.weeks)) return const [];
    return meetingsOn(day, semester, courses);
  }

  WidgetRow row(ClassMeeting m) => WidgetRow(
        title: m.course.title,
        subtitle: [
          '${_hm(m.session.startMinute)}–${_hm(m.session.endMinute)}',
          ?m.session.location,
        ].join('・'),
        colorArgb: m.course.color,
        tapAction: WidgetAction.openItem(kind: 'timetable', id: m.course.id),
      );

  final today = _dateOnly(now);
  final minute = now.hour * 60 + now.minute;
  final left = on(today).where((m) => m.session.endMinute > minute).toList();
  if (left.isNotEmpty) return [for (final m in left) row(m)];
  final tomorrow = on(today.add(const Duration(days: 1)));
  if (tomorrow.isEmpty) return const [];
  return [
    WidgetRow(title: s.widgetTomorrow, isHeader: true),
    for (final m in tomorrow) row(m),
  ];
}

// The action URIs the widget sends. Kept beside the rows that carry them so a
// renamed action cannot go unnoticed on one side
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

  // The + button. [kind] is 'task', 'semesterGoal' or 'futureGoal', matching
  // whichever tab the widget is on
  static String newItem({required String kind}) => '$scheme://new?kind=$kind';
}

// The native side ticks a task the instant it is tapped, ahead of the write
// that makes it true. When that write fails the tick has to be taken back, and
// with no network there is nothing to rebuild the snapshot from, so the stored
// one is patched instead
String untickInSnapshot(String snapshotJson, String checkAction) {
  final json = jsonDecode(snapshotJson) as Map<String, dynamic>;
  final views = json['views'] as Map<String, dynamic>;
  for (final rows in views.values) {
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      if (row['check_action'] == checkAction) {
        row['check'] = WidgetCheck.unchecked.name;
      }
    }
  }
  return jsonEncode(json);
}
