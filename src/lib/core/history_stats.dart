import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart'
    show currentOccurrence, taskAppliesTo, taskCompletionStatsOn;
import '../utils/category_helpers.dart';

// What the completion-history page says beyond the bar chart (design A,
// 2026-09-20): how the period compares with the one before it, how long the
// user has kept every day clear, which weekday goes best, which category is
// falling behind, and what has been sitting undone the longest.
//
// All pure functions over the task list, so the page stays a drawing of them
// and every rule here is unit-tested. Every range is a list of days, inclusive
// at both ends, and every day is counted the way the today page counts it
// (taskCompletionStatsOn).

List<DateTime> _daysBetween(DateTime from, DateTime to) => [
      for (var d = 0; !from.add(Duration(days: d)).isAfter(to); d++)
        from.add(Duration(days: d)),
    ];

// Done and total across a range. Days with nothing planned add nothing
({int done, int total}) totalsBetween(
  List<Task> tasks,
  DateTime from,
  DateTime to,
) {
  var done = 0, total = 0;
  for (final day in _daysBetween(from, to)) {
    final stats = taskCompletionStatsOn(tasks, day);
    if (stats == null) continue;
    done += stats.done;
    total += stats.total;
  }
  return (done: done, total: total);
}

// The completion rate of a range, or null when nothing applied in it
double? rateBetween(List<Task> tasks, DateTime from, DateTime to) {
  final t = totalsBetween(tasks, from, to);
  return t.total == 0 ? null : t.done / t.total;
}

// How many days in a row everything planned was finished, counting back from
// today. Today is allowed to be unfinished — the day is not over — but an
// unfinished yesterday ends it. A day with nothing planned neither extends nor
// breaks the run: there was nothing to keep up
int allDoneStreak(List<Task> tasks, DateTime today) {
  var streak = 0;
  for (var back = 0; back <= 366; back++) {
    final day = today.subtract(Duration(days: back));
    final stats = taskCompletionStatsOn(tasks, day);
    if (stats == null) continue;
    if (stats.done == stats.total) {
      streak++;
      continue;
    }
    // Today still has time left; any earlier day does not
    if (back == 0) continue;
    break;
  }
  return streak;
}

// The weekday (1 = Monday) with the best average rate in the range, with that
// average. Null when no day in the range had anything planned
({int weekday, double rate})? bestWeekday(
  List<Task> tasks,
  DateTime from,
  DateTime to,
) {
  final sums = <int, ({double rate, int days})>{};
  for (final day in _daysBetween(from, to)) {
    final stats = taskCompletionStatsOn(tasks, day);
    if (stats == null || stats.total == 0) continue;
    final prev = sums[day.weekday] ?? (rate: 0.0, days: 0);
    sums[day.weekday] =
        (rate: prev.rate + stats.done / stats.total, days: prev.days + 1);
  }
  if (sums.isEmpty) return null;

  var best = sums.keys.first;
  for (final weekday in sums.keys) {
    final a = sums[weekday]!;
    final b = sums[best]!;
    if (a.rate / a.days > b.rate / b.days) best = weekday;
  }
  final winner = sums[best]!;
  return (weekday: best, rate: winner.rate / winner.days);
}

// Done and total per category in the range, biggest shortfall first.
//
// A task's category is the one its linked target carries (§3-J). Tasks linked
// to nothing, or to a target with no category, have no category to count under
// and are left out — the list is about which category is falling behind, and
// "no category" is not one
List<({String category, int done, int total})> categoryTotals(
  List<Task> tasks,
  List<SemesterGoal> targets,
  DateTime from,
  DateTime to,
) {
  final categoryOf = <String, String?>{
    for (final target in targets) target.id: primaryCategoryOf(target.categories),
  };

  final byCategory = <String, ({int done, int total})>{};
  for (final day in _daysBetween(from, to)) {
    for (final task in tasks.where((t) => taskAppliesTo(t, day))) {
      final category = categoryOf[task.linkedTargetId];
      if (category == null) continue;
      final prev = byCategory[category] ?? (done: 0, total: 0);
      byCategory[category] = (
        done: prev.done + (task.isCompletedOn(day) ? 1 : 0),
        total: prev.total + 1,
      );
    }
  }

  final rows = [
    for (final entry in byCategory.entries)
      (category: entry.key, done: entry.value.done, total: entry.value.total),
  ];
  // Most left undone first; a tie goes to the bigger pile
  rows.sort((a, b) {
    final left = (b.total - b.done).compareTo(a.total - a.done);
    return left != 0 ? left : b.total.compareTo(a.total);
  });
  return rows;
}

// What has been waiting longest: the occurrence is in the past and still not
// ticked off. Recurring tasks count from their current occurrence (the same one
// the all-tasks view shows), so a monthly task skipped twice reports the older
// of the two dates it is still carrying
List<({Task task, int daysLate})> stalestTasks(
  List<Task> tasks,
  DateTime today, {
  int limit = 3,
}) {
  final late = <({Task task, int daysLate})>[];
  for (final task in tasks) {
    final day = currentOccurrence(task, today);
    if (day == null || !day.isBefore(today)) continue;
    if (task.isCompletedOn(day)) continue;
    late.add((task: task, daysLate: today.difference(day).inDays));
  }
  late.sort((a, b) => b.daysLate.compareTo(a.daysLate));
  return late.take(limit).toList();
}

