import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';

// Which occurrence of a recurring task the all-tasks view is about.
//
// The report: a task set to the 20th of each month showed up every day. The
// view lists every task, so what it needs is the occurrence each row stands
// for — this month's — and whether that one is done.
void main() {
  Task monthly(List<int> days, {DateTime? createdAt, List<String> done = const []}) => Task(
        id: 't1',
        title: '繳費',
        createdAt: createdAt ?? DateTime(2026, 1, 20),
        recurrence: RecurrenceRule(type: RecurrenceType.monthly, monthDays: days),
        completedDates: done,
      );

  group('currentOccurrence', () {
    test('on the day itself, that is the occurrence', () {
      expect(currentOccurrence(monthly([20]), DateTime(2026, 9, 20, 10)),
          DateTime(2026, 9, 20));
    });

    test('after it, the row still stands for that day', () {
      // The 21st is not a rule day, but this month's is not done yet
      expect(currentOccurrence(monthly([20]), DateTime(2026, 9, 21, 10)),
          DateTime(2026, 9, 20));
    });

    test('before the first one, it looks forward instead', () {
      final task = monthly([20], createdAt: DateTime(2026, 9, 25));
      expect(currentOccurrence(task, DateTime(2026, 9, 26)), DateTime(2026, 10, 20));
    });

    test('a weekly task answers with the most recent matching weekday', () {
      final task = Task(
        id: 't2',
        title: '週會',
        createdAt: DateTime(2026, 1, 1),
        recurrence: const RecurrenceRule(type: RecurrenceType.weekly, weekdays: [1]),
      );
      // 2026-09-19 is a Saturday; the Monday before is the 14th
      expect(currentOccurrence(task, DateTime(2026, 9, 19)), DateTime(2026, 9, 14));
    });

    test('a task with a due time answers with that day', () {
      final task = Task(
        id: 't3',
        title: '報告',
        createdAt: DateTime(2026, 9, 1),
        dueTime: DateTime(2026, 9, 30, 23, 59),
      );
      expect(currentOccurrence(task, DateTime(2026, 9, 19)), DateTime(2026, 9, 30));
    });

    test('a task with no date and no rule has no occurrence', () {
      final task = Task(id: 't4', title: '有空再做', createdAt: DateTime(2026, 9, 1));
      expect(currentOccurrence(task, DateTime(2026, 9, 19)), isNull);
    });
  });

  group('what the all-tasks view shows', () {
    // The row is outstanding until the occurrence it stands for is ticked off
    bool outstanding(Task task, DateTime now) =>
        !task.isCompletedOn(currentOccurrence(task, now)!);

    test('an unfinished monthly task stays listed after its day', () {
      expect(outstanding(monthly([20]), DateTime(2026, 9, 21)), isTrue);
    });

    test('once this month is ticked off it drops out', () {
      final task = monthly([20], done: const ['2026-09-20']);
      expect(outstanding(task, DateTime(2026, 9, 21)), isFalse);
      expect(outstanding(task, DateTime(2026, 10, 19)), isFalse);
    });

    test('and comes back on the next one', () {
      final task = monthly([20], done: const ['2026-09-20']);
      expect(outstanding(task, DateTime(2026, 10, 20)), isTrue);
    });
  });

  group('untilNextDay', () {
    test('counts to just past midnight', () {
      final now = DateTime(2026, 9, 19, 23, 30);
      expect(untilNextDay(now), const Duration(minutes: 30, seconds: 1));
    });

    test('a whole day ahead at one second past midnight', () {
      final now = DateTime(2026, 9, 19, 0, 0, 1);
      expect(untilNextDay(now), const Duration(hours: 24));
    });
  });
}
