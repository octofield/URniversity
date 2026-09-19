import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/history_stats.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/models/task.dart';

// The numbers the completion-history page shows around the bar chart
// (design A): the run of clear days, the best weekday, which category is
// falling behind, and what has been waiting longest.
void main() {
  final today = DateTime(2026, 9, 20); // a Sunday

  Task dueOn(DateTime day, {bool done = false, String? targetId, String id = 't'}) => Task(
        id: id,
        title: id,
        dueTime: DateTime(day.year, day.month, day.day, 9),
        isCompleted: done,
        createdAt: day.subtract(const Duration(days: 40)),
        linkedTargetId: targetId,
      );

  group('allDoneStreak', () {
    test('counts back while every day was cleared', () {
      final tasks = [
        for (var back = 0; back < 4; back++)
          dueOn(today.subtract(Duration(days: back)), done: true, id: 'd$back'),
      ];
      expect(allDoneStreak(tasks, today), 4);
    });

    test('today being unfinished does not end it', () {
      final tasks = [
        dueOn(today, id: 'today'),
        dueOn(today.subtract(const Duration(days: 1)), done: true, id: 'y'),
        dueOn(today.subtract(const Duration(days: 2)), done: true, id: 'y2'),
      ];
      expect(allDoneStreak(tasks, today), 2);
    });

    test('an unfinished earlier day ends it', () {
      final tasks = [
        dueOn(today, done: true, id: 'today'),
        dueOn(today.subtract(const Duration(days: 1)), id: 'y'),
        dueOn(today.subtract(const Duration(days: 2)), done: true, id: 'y2'),
      ];
      expect(allDoneStreak(tasks, today), 1);
    });

    test('a day with nothing planned neither extends nor breaks it', () {
      final tasks = [
        dueOn(today, done: true, id: 'today'),
        // Nothing at all on the 19th
        dueOn(today.subtract(const Duration(days: 2)), done: true, id: 'y2'),
      ];
      expect(allDoneStreak(tasks, today), 2);
    });

    test('no tasks at all is zero', () {
      expect(allDoneStreak(const [], today), 0);
    });
  });

  group('the range totals', () {
    test('add up every day that had something planned', () {
      final tasks = [
        dueOn(today, done: true, id: 'a'),
        dueOn(today, id: 'b'),
        dueOn(today.subtract(const Duration(days: 1)), done: true, id: 'c'),
      ];
      final totals =
          totalsBetween(tasks, today.subtract(const Duration(days: 6)), today);

      expect(totals, (done: 2, total: 3));
      expect(rateBetween(tasks, today.subtract(const Duration(days: 6)), today), 2 / 3);
    });

    test('an empty range has no rate at all, which is not 0%', () {
      expect(rateBetween(const [], today.subtract(const Duration(days: 6)), today), isNull);
    });
  });

  test('bestWeekday picks the highest average, not the busiest day', () {
    final wednesday = DateTime(2026, 9, 16);
    final thursday = DateTime(2026, 9, 17);
    final tasks = [
      dueOn(wednesday, done: true, id: 'w1'),
      dueOn(wednesday, done: true, id: 'w2'),
      dueOn(thursday, done: true, id: 'h1'),
      dueOn(thursday, id: 'h2'),
      dueOn(thursday, id: 'h3'),
    ];

    final best = bestWeekday(tasks, today.subtract(const Duration(days: 6)), today);
    expect(best?.weekday, DateTime.wednesday);
    expect(best?.rate, 1.0);
  });

  test('categoryTotals ranks by what is left undone', () {
    SemesterGoal target(String id, List<String> categories) => SemesterGoal(
          id: id,
          title: id,
          semester: '115-1',
          categories: categories,
        );
    final targets = [
      target('cert-goal', const ['cert']),
      target('intern-goal', const ['intern']),
      target('bare', const []),
    ];
    final tasks = [
      dueOn(today, targetId: 'cert-goal', id: 'c1'),
      dueOn(today, targetId: 'cert-goal', id: 'c2'),
      dueOn(today, targetId: 'cert-goal', done: true, id: 'c3'),
      dueOn(today, targetId: 'intern-goal', done: true, id: 'i1'),
      dueOn(today, targetId: 'intern-goal', id: 'i2'),
      // No link at all, and a target with no category: neither can be counted
      dueOn(today, id: 'loose'),
      dueOn(today, targetId: 'bare', id: 'bare-task'),
    ];

    final rows = categoryTotals(tasks, targets, today, today);
    expect(rows.map((r) => r.category).toList(), ['cert', 'intern']);
    expect(rows.first, (category: 'cert', done: 1, total: 3));
  });

  group('stalestTasks', () {
    test('the longest wait comes first', () {
      final tasks = [
        dueOn(today.subtract(const Duration(days: 12)), id: 'old'),
        dueOn(today.subtract(const Duration(days: 5)), id: 'recent'),
        dueOn(today.subtract(const Duration(days: 20)), done: true, id: 'done'),
        dueOn(today, id: 'today'),
      ];

      final stale = stalestTasks(tasks, today);
      expect(stale.map((e) => e.task.id).toList(), ['old', 'recent']);
      expect(stale.first.daysLate, 12);
    });

    test('a recurring task counts from the occurrence it is still carrying', () {
      final monthly = Task(
        id: 'monthly',
        title: '每月 20 號',
        createdAt: DateTime(2026, 1, 20),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.monthly,
          monthDays: [15],
        ),
      );

      final stale = stalestTasks([monthly], today);
      expect(stale.single.daysLate, 5, reason: 'the 15th was five days ago');
    });

    test('only as many as asked for', () {
      final tasks = [
        for (var back = 1; back <= 5; back++)
          dueOn(today.subtract(Duration(days: back)), id: 'l$back'),
      ];
      expect(stalestTasks(tasks, today, limit: 2), hasLength(2));
    });
  });
}
