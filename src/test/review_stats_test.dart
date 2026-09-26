import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/review_stats.dart';
import 'package:urniversity/models/review.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/settings_provider.dart';

// The guided review's rules (system_design.md §3-P). The windows are the part a
// user feels most: a card that shows a day late, or keeps showing after the
// review is done, is what makes a ritual feel broken.
void main() {
  const settings = SemesterSettings.defaultSettings; // terms start Aug and Feb

  Review reviewFor(ReviewWindow w, {List<String> focus = const []}) => Review(
        id: 'r_${w.period.name}_${w.start.toIso8601String()}',
        period: w.period,
        periodStart: w.start,
        periodEnd: w.end,
        focusTargetIds: focus,
        stats: const ReviewStats(done: 0, total: 0, streak: 0, journals: 0),
        createdAt: w.end,
      );

  Task oneOff(String id, DateTime due, {bool done = false, String? target}) => Task(
        id: id,
        title: id,
        dueTime: due,
        isCompleted: done,
        createdAt: due.subtract(const Duration(days: 3)),
        linkedTargetId: target,
      );

  group('weeks and months', () {
    test('a week runs Monday to Sunday', () {
      final w = weekOf(DateTime(2026, 9, 23, 15)); // a Wednesday
      expect(w.start, DateTime(2026, 9, 21));
      expect(w.end, DateTime(2026, 9, 27));
    });

    test('a month ends on its own last day', () {
      final m = monthOf(DateTime(2027, 2, 10));
      expect(m.start, DateTime(2027, 2, 1));
      expect(m.end, DateTime(2027, 2, 28));
    });

    test('the period before a month is the whole previous month', () {
      final march = ReviewWindow(ReviewPeriod.month, DateTime(2027, 3, 1), DateTime(2027, 3, 31));
      final prev = previousWindow(march);
      expect(prev.start, DateTime(2027, 2, 1));
      expect(prev.end, DateTime(2027, 2, 28));
    });

    test('the term on a date follows the start months', () {
      expect(termAt(DateTime(2026, 9, 1), settings), '115-1');
      expect(termAt(DateTime(2027, 1, 31), settings), '115-1');
      expect(termAt(DateTime(2027, 2, 1), settings), '115-2');
    });
  });

  group('which review is due', () {
    ReviewWindow? due(DateTime now, [List<Review> done = const []]) =>
        dueReviewWindow(now: now, settings: settings, done: done);

    test('Sunday evening from 18:00 offers this week', () {
      expect(due(DateTime(2026, 9, 27, 17, 59)), isNull);
      final w = due(DateTime(2026, 9, 27, 18))!;
      expect(w.period, ReviewPeriod.week);
      expect(w.start, DateTime(2026, 9, 21));
    });

    test('Monday and Tuesday still offer the week just gone, Wednesday does not', () {
      expect(due(DateTime(2026, 9, 29, 23, 59))!.start, DateTime(2026, 9, 21));
      expect(due(DateTime(2026, 9, 30, 0, 1)), isNull);
    });

    test('the first three days of a month offer last month', () {
      final w = due(DateTime(2026, 10, 2, 9))!; // a Friday, so no week review
      expect(w.period, ReviewPeriod.month);
      expect(w.start, DateTime(2026, 9, 1));
      expect(due(DateTime(2026, 10, 4, 9)), isNull); // a Sunday morning
    });

    test('a done review stops being offered', () {
      final w = due(DateTime(2026, 9, 27, 20))!;
      expect(due(DateTime(2026, 9, 27, 20), [reviewFor(w)]), isNull);
    });

    test('semester beats month beats week, one card at a time', () {
      // Monday 1 Feb 2027: term 115-1 has just ended, January too, and a week
      final now = DateTime(2027, 2, 1, 9);
      final first = due(now)!;
      expect(first.period, ReviewPeriod.semester);
      expect(first.start, DateTime(2026, 8, 1));
      expect(first.end, DateTime(2027, 1, 31));

      final second = due(now, [reviewFor(first)])!;
      expect(second.period, ReviewPeriod.month);

      final third = due(now, [reviewFor(first), reviewFor(second)])!;
      expect(third.period, ReviewPeriod.week);
    });

    test('developer mode opens this week, last month and this term on any day', () {
      final now = DateTime(2026, 9, 23, 10); // a Wednesday, nothing due
      expect(due(now), isNull);

      final week = latestReviewWindow(ReviewPeriod.week, now, settings);
      expect((week.start, week.end), (DateTime(2026, 9, 21), DateTime(2026, 9, 27)));
      final month = latestReviewWindow(ReviewPeriod.month, now, settings);
      expect((month.start, month.end), (DateTime(2026, 8, 1), DateTime(2026, 8, 31)));
      final term = latestReviewWindow(ReviewPeriod.semester, now, settings);
      expect((term.start, term.end), (DateTime(2026, 8, 1), DateTime(2027, 1, 31)));
    });

    test('last month from January is last December', () {
      final month = latestReviewWindow(ReviewPeriod.month, DateTime(2027, 1, 15), settings);
      expect((month.start, month.end), (DateTime(2026, 12, 1), DateTime(2026, 12, 31)));
    });
  });

  group('the numbers', () {
    test('a day with nothing planned is null, not zero', () {
      final day = DateTime(2026, 9, 22);
      final rates = dailyRates(
        [oneOff('a', day.add(const Duration(hours: 9)), done: true), oneOff('b', day.add(const Duration(hours: 10)))],
        DateTime(2026, 9, 21),
        DateTime(2026, 9, 23),
      );
      expect(rates, [null, 0.5, null]);
    });

    test('only open one-off tasks due in the period are offered to carry over', () {
      final mon = DateTime(2026, 9, 21);
      final sun = DateTime(2026, 9, 27);
      final tasks = [
        oneOff('open', DateTime(2026, 9, 24, 14)),
        oneOff('done', DateTime(2026, 9, 24, 14), done: true),
        oneOff('before', DateTime(2026, 9, 20, 23)),
        oneOff('lastMinute', DateTime(2026, 9, 27, 23, 59)),
        oneOff('after', DateTime(2026, 9, 28)),
        Task(
          id: 'repeat',
          title: 'repeat',
          dueTime: DateTime(2026, 9, 24, 9),
          createdAt: DateTime(2026, 9, 1),
          recurrence: const RecurrenceRule(type: RecurrenceType.daily),
        ),
        Task(id: 'noDue', title: 'noDue', createdAt: DateTime(2026, 9, 1)),
      ];

      expect(
        carryOverCandidates(tasks, mon, sun).map((t) => t.id),
        ['open', 'lastMinute'],
      );
    });

    test('a target counts milestones and the tasks hung anywhere under it', () {
      const goals = [
        SemesterGoal(id: 'root', title: 'TOEIC', semester: '115-1'),
        SemesterGoal(id: 'm1', parentId: 'root', title: 'Register', semester: '115-1', isDone: true),
        SemesterGoal(id: 'm2', parentId: 'root', title: 'Mock', semester: '115-1'),
        SemesterGoal(id: 'other', title: 'Other term', semester: '114-2'),
      ];
      final tasks = [
        oneOff('t1', DateTime(2026, 9, 22, 9), done: true, target: 'm2'),
        oneOff('t2', DateTime(2026, 9, 23, 9), target: 'root'),
        oneOff('outside', DateTime(2026, 10, 5, 9), done: true, target: 'root'),
      ];

      final progress = targetProgressBetween(
        goals: goals,
        tasks: tasks,
        semester: '115-1',
        from: DateTime(2026, 9, 21),
        to: DateTime(2026, 9, 27),
      );

      expect(progress.single.id, 'root');
      expect(progress.single.milestonesDone, 1);
      expect(progress.single.milestonesTotal, 2);
      expect(progress.single.tasksDone, 1);
      expect(progress.single.tasksTotal, 2);
    });
  });

  group('focus this week', () {
    final lastWeek = ReviewWindow(ReviewPeriod.week, DateTime(2026, 9, 21), DateTime(2026, 9, 27));

    test('runs from the review\'s Sunday through the following Sunday', () {
      final reviews = [reviewFor(lastWeek, focus: ['root'])];
      expect(activeFocus(reviews, DateTime(2026, 9, 26)), isEmpty);
      expect(activeFocus(reviews, DateTime(2026, 9, 27)), ['root']);
      expect(activeFocus(reviews, DateTime(2026, 10, 4)), ['root']);
      expect(activeFocus(reviews, DateTime(2026, 10, 5)), isEmpty);
    });

    test('the newer week wins when two overlap', () {
      final thisWeek = ReviewWindow(ReviewPeriod.week, DateTime(2026, 9, 28), DateTime(2026, 10, 4));
      final reviews = [
        reviewFor(lastWeek, focus: ['old']),
        reviewFor(thisWeek, focus: ['new']),
      ];
      expect(activeFocus(reviews, DateTime(2026, 10, 4)), ['new']);
    });
  });

  group('stored reviews', () {
    test('a review survives the round trip to the database row', () {
      final original = Review(
        id: 'x',
        period: ReviewPeriod.month,
        periodStart: DateTime(2026, 9, 1),
        periodEnd: DateTime(2026, 9, 30),
        wentWell: 'Finished the mock',
        focusTargetIds: const ['root'],
        stats: const ReviewStats(
          done: 3,
          total: 4,
          rate: 0.75,
          streak: 2,
          journals: 1,
          targets: [
            TargetProgress(id: 'root', title: 'TOEIC', milestonesDone: 1, milestonesTotal: 2, tasksDone: 1, tasksTotal: 2),
          ],
        ),
        createdAt: DateTime(2026, 10, 1, 9),
      );

      final json = original.toJson();
      expect(json['period_start'], '2026-09-01');
      final back = Review.fromJson(json);
      expect(back.period, ReviewPeriod.month);
      expect(back.wentWell, 'Finished the mock');
      expect(back.stats.rate, 0.75);
      expect(back.stats.targets.single.milestonesTotal, 2);
    });

    test('a snapshot missing newer keys still reads', () {
      final back = Review.fromJson({
        'id': 'x',
        'period': 'week',
        'period_start': '2026-09-21',
        'period_end': '2026-09-27',
        'stats': {'done': 1},
        'created_at': '2026-09-27T20:00:00.000',
      });
      expect(back.stats.done, 1);
      expect(back.stats.total, 0);
      expect(back.stats.targets, isEmpty);
      expect(back.focusTargetIds, isEmpty);
    });
  });
}
