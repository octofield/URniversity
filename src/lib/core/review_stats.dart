import '../models/journal.dart';
import '../models/review.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart' show SemesterSettings;
import '../providers/tasks_provider.dart' show taskCompletionStatsOn;
import '../utils/semester_helpers.dart';
import 'history_stats.dart';

// The rules behind the guided review (system_design.md §3-P): which review is
// due, the numbers it opens with, and which tasks it offers to carry over.
// Pure functions, like history_stats.dart, so each rule is unit-tested and the
// screens only draw them.

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

// Monday to Sunday, the week a date falls in
({DateTime start, DateTime end}) weekOf(DateTime date) {
  final start = _day(date).subtract(Duration(days: date.weekday - 1));
  return (start: start, end: start.add(const Duration(days: 6)));
}

({DateTime start, DateTime end}) monthOf(DateTime date) => (
      start: DateTime(date.year, date.month),
      end: DateTime(date.year, date.month + 1, 0),
    );

class ReviewWindow {
  final ReviewPeriod period;
  final DateTime start;
  final DateTime end;

  const ReviewWindow(this.period, this.start, this.end);

  bool sameAs(Review r) =>
      r.period == period && _day(r.periodStart) == start && _day(r.periodEnd) == end;

  @override
  bool operator ==(Object other) =>
      other is ReviewWindow && other.period == period && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(period, start, end);
}

// The review the card offers right now, or null. A semester review comes first,
// then the month's, then the week's — at most one card at a time.
//
//  - week: from Sunday 18:00, when the week is nearly over, through Tuesday, so
//    a busy weekend does not lose it
//  - month: the first three days of the next month
//  - semester: the last 20 days of the term and its first week after. The term
//    runs to the day before the next one starts (semesterEnd), which includes
//    the break; until the timetable phase knows the real last day of classes,
//    that is the closest the app can tell
ReviewWindow? dueReviewWindow({
  required DateTime now,
  required SemesterSettings settings,
  required List<Review> done,
}) {
  bool reviewed(ReviewWindow w) => done.any(w.sameAs);

  for (final window in [
    _semesterWindow(now, settings),
    _monthWindow(now),
    _weekWindow(now),
  ]) {
    if (window != null && !reviewed(window)) return window;
  }
  return null;
}

ReviewWindow? _weekWindow(DateTime now) {
  if (now.weekday == DateTime.sunday && now.hour >= 18) {
    final w = weekOf(now);
    return ReviewWindow(ReviewPeriod.week, w.start, w.end);
  }
  if (now.weekday == DateTime.monday || now.weekday == DateTime.tuesday) {
    final w = weekOf(now.subtract(const Duration(days: 7)));
    return ReviewWindow(ReviewPeriod.week, w.start, w.end);
  }
  return null;
}

ReviewWindow? _monthWindow(DateTime now) {
  if (now.day > 3) return null;
  final m = monthOf(DateTime(now.year, now.month - 1));
  return ReviewWindow(ReviewPeriod.month, m.start, m.end);
}

ReviewWindow? _semesterWindow(DateTime now, SemesterSettings settings) {
  final today = _day(now);
  // The term that just started is not the one being wrapped up; look at the
  // one before it too
  final current = termAt(now, settings);
  for (final token in [current, _previousTerm(current, settings)]) {
    if (token == null) continue;
    final start = _day(semesterStart(token, settings));
    final end = _day(semesterEnd(token, settings));
    final opens = end.subtract(const Duration(days: 20));
    final closes = end.add(const Duration(days: 7));
    if (!today.isBefore(opens) && !today.isAfter(closes)) {
      return ReviewWindow(ReviewPeriod.semester, start, end);
    }
  }
  return null;
}

// The review of each kind that [now] would title correctly — this week, last
// month, this term — whether or not it is due. Developer mode opens these
ReviewWindow latestReviewWindow(ReviewPeriod period, DateTime now, SemesterSettings settings) {
  switch (period) {
    case ReviewPeriod.week:
      final w = weekOf(now);
      return ReviewWindow(period, w.start, w.end);
    case ReviewPeriod.month:
      final m = monthOf(DateTime(now.year, now.month - 1));
      return ReviewWindow(period, m.start, m.end);
    case ReviewPeriod.semester:
      final token = termAt(now, settings);
      return ReviewWindow(period, _day(semesterStart(token, settings)), _day(semesterEnd(token, settings)));
  }
}

// The term running on [date]: the latest one that has already begun. The same
// rule as currentSemester(), which reads the wall clock — this takes the date,
// so developer mode's date override and the tests both move it
String termAt(DateTime date, SemesterSettings settings) {
  final rocYear = date.year - 1911;
  var result = '${rocYear - 1}-1';
  var resultStart = DateTime(1900);
  for (var ay = rocYear - 1; ay <= rocYear + 1; ay++) {
    for (var t = 1; t <= settings.startMonths.length; t++) {
      final start = semesterStart('$ay-$t', settings);
      if (!start.isAfter(date) && start.isAfter(resultStart)) {
        resultStart = start;
        result = '$ay-$t';
      }
    }
  }
  return result;
}

String? _previousTerm(String token, SemesterSettings settings) {
  final parts = token.split('-');
  final year = int.tryParse(parts[0]);
  final term = int.tryParse(parts[1]);
  if (year == null || term == null) return null;
  return term > 1 ? '$year-${term - 1}' : '${year - 1}-${settings.startMonths.length}';
}

// The period before, the same length — what "up 13% on last week" compares to
ReviewWindow previousWindow(ReviewWindow w) {
  final days = w.end.difference(w.start).inDays + 1;
  return switch (w.period) {
    ReviewPeriod.month => () {
        final m = monthOf(DateTime(w.start.year, w.start.month - 1));
        return ReviewWindow(ReviewPeriod.month, m.start, m.end);
      }(),
    _ => ReviewWindow(
        w.period,
        w.start.subtract(Duration(days: days)),
        w.start.subtract(const Duration(days: 1)),
      ),
  };
}

// One completion rate per day, oldest first; null on a day with nothing planned.
// Drives the heat map, where "nothing planned" has to look different from "0%"
List<double?> dailyRates(List<Task> tasks, DateTime from, DateTime to) => [
      for (var d = _day(from); !d.isAfter(_day(to)); d = d.add(const Duration(days: 1)))
        () {
          final stats = taskCompletionStatsOn(tasks, d);
          return stats == null || stats.total == 0 ? null : stats.done / stats.total;
        }(),
    ];

// How each top-level target of a semester moved in the period: its milestones
// (as they stand) and the tasks hung anywhere under it that fell in the period
List<TargetProgress> targetProgressBetween({
  required List<SemesterGoal> goals,
  required List<Task> tasks,
  required String semester,
  required DateTime from,
  required DateTime to,
}) {
  final childrenOf = <String, List<SemesterGoal>>{};
  for (final g in goals) {
    if (g.parentId != null) childrenOf.putIfAbsent(g.parentId!, () => []).add(g);
  }
  Set<String> subtree(String id) => {
        id,
        for (final child in childrenOf[id] ?? const <SemesterGoal>[]) ...subtree(child.id),
      };

  return [
    for (final root in goals.where((g) => g.parentId == null && g.semester == semester))
      () {
        final ids = subtree(root.id);
        final milestones = goals.where((g) => g.id != root.id && ids.contains(g.id));
        final totals = totalsBetween(
          tasks.where((t) => ids.contains(t.linkedTargetId)).toList(),
          from,
          to,
        );
        return TargetProgress(
          id: root.id,
          title: root.title,
          milestonesDone: milestones.where((m) => m.isDone).length,
          milestonesTotal: milestones.length,
          tasksDone: totals.done,
          tasksTotal: totals.total,
        );
      }(),
  ];
}

// One-off tasks due in the period and still open — what "move to next week"
// offers. Repeating tasks come round again by themselves, so they are left out
List<Task> carryOverCandidates(List<Task> tasks, DateTime from, DateTime to) {
  final start = _day(from);
  final end = _day(to).add(const Duration(days: 1));
  return [
    for (final t in tasks)
      if ((t.recurrence == null || t.recurrence!.isNone) &&
          !t.isCompleted &&
          t.dueTime != null &&
          !t.dueTime!.isBefore(start) &&
          t.dueTime!.isBefore(end))
        t,
  ];
}

// The numbers a review opens with, frozen into the review when it is saved
ReviewStats buildReviewStats({
  required ReviewWindow window,
  required List<Task> tasks,
  required List<SemesterGoal> goals,
  required List<Journal> journals,
  required bool Function(Journal) writtenByUser,
  required SemesterSettings settings,
  required DateTime now,
}) {
  final totals = totalsBetween(tasks, window.start, window.end);
  final previous = previousWindow(window);
  final lastDay = now.isBefore(window.end) ? _day(now) : window.end;
  // The term the period sits in, not today's: a review done on the first days
  // of a new term is still about the one that ended
  final semester = termAt(window.end, settings);

  return ReviewStats(
    done: totals.done,
    total: totals.total,
    rate: totals.total == 0 ? null : totals.done / totals.total,
    previousRate: rateBetween(tasks, previous.start, previous.end),
    streak: allDoneStreak(tasks, lastDay),
    bestWeekday: bestWeekday(tasks, window.start, window.end)?.weekday,
    journals: journals
        .where(writtenByUser)
        .where((j) => !_day(j.date).isBefore(window.start) && !_day(j.date).isAfter(window.end))
        .length,
    targets: targetProgressBetween(
      goals: goals,
      tasks: tasks,
      semester: semester,
      from: window.start,
      to: window.end,
    ),
  );
}

// The targets picked in the review that closed the week before this one — what
// "focus this week" shows. The review done on a Sunday evening counts from then
List<String> activeFocus(List<Review> reviews, DateTime today) {
  final day = _day(today);
  Review? latest;
  for (final r in reviews) {
    if (r.period != ReviewPeriod.week || r.focusTargetIds.isEmpty) continue;
    final end = _day(r.periodEnd);
    if (day.isBefore(end) || day.isAfter(end.add(const Duration(days: 7)))) continue;
    if (latest == null || end.isAfter(_day(latest.periodEnd))) latest = r;
  }
  return latest?.focusTargetIds ?? const [];
}
