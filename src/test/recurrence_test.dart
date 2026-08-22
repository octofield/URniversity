import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/tasks_provider.dart';

// taskCompletionStatsOn() is the public entry point into the private
// _taskAppliesTo/_recurringAppliesTo logic, so recurrence rules can be tested
// without touching Supabase or Riverpod.
//
// It returns null when no task applies on the given day, so "applies" is
// simply "stats != null".
bool appliesOn(Task task, DateTime date) =>
    taskCompletionStatsOn([task], date) != null;

Task makeTask({
  required DateTime createdAt,
  RecurrenceRule? recurrence,
  DateTime? dueTime,
}) =>
    Task(
      id: 't1',
      title: 'test',
      createdAt: createdAt,
      recurrence: recurrence,
      dueTime: dueTime,
    );

void main() {
  // A Wednesday, so weekday == 3
  final created = DateTime(2026, 1, 7);

  group('non-recurring', () {
    test('applies only on its due date', () {
      final task = makeTask(createdAt: created, dueTime: DateTime(2026, 1, 9));
      expect(appliesOn(task, DateTime(2026, 1, 9)), isTrue);
      expect(appliesOn(task, DateTime(2026, 1, 10)), isFalse);
    });

    test('never applies without a due time', () {
      final task = makeTask(createdAt: created);
      expect(appliesOn(task, created), isFalse);
    });
  });

  group('daily', () {
    final task = makeTask(
      createdAt: created,
      recurrence: const RecurrenceRule(type: RecurrenceType.daily),
    );

    test('applies on and after the creation day', () {
      expect(appliesOn(task, created), isTrue);
      expect(appliesOn(task, DateTime(2026, 3, 1)), isTrue);
    });

    test('never applies before the creation day', () {
      expect(appliesOn(task, DateTime(2026, 1, 6)), isFalse);
    });
  });

  group('weekly', () {
    test('with no weekdays falls back to the creation weekday', () {
      final task = makeTask(
        createdAt: created,
        recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
      );
      expect(appliesOn(task, DateTime(2026, 1, 14)), isTrue); // +7d, Wed
      expect(appliesOn(task, DateTime(2026, 1, 15)), isFalse); // Thu
    });

    test('with explicit weekdays ignores the creation weekday', () {
      // Mon + Fri
      final task = makeTask(
        createdAt: created,
        recurrence: const RecurrenceRule(
            type: RecurrenceType.weekly, weekdays: [1, 5]),
      );
      expect(appliesOn(task, DateTime(2026, 1, 12)), isTrue); // Mon
      expect(appliesOn(task, DateTime(2026, 1, 16)), isTrue); // Fri
      expect(appliesOn(task, DateTime(2026, 1, 14)), isFalse); // Wed
    });
  });

  group('monthly', () {
    test('with no days falls back to the creation day-of-month', () {
      final task = makeTask(
        createdAt: created, // the 7th
        recurrence: const RecurrenceRule(type: RecurrenceType.monthly),
      );
      expect(appliesOn(task, DateTime(2026, 2, 7)), isTrue);
      expect(appliesOn(task, DateTime(2026, 2, 8)), isFalse);
    });

    test('with explicit days matches any of them', () {
      final task = makeTask(
        createdAt: created,
        recurrence: const RecurrenceRule(
            type: RecurrenceType.monthly, monthDays: [1, 15]),
      );
      expect(appliesOn(task, DateTime(2026, 2, 1)), isTrue);
      expect(appliesOn(task, DateTime(2026, 2, 15)), isTrue);
      expect(appliesOn(task, DateTime(2026, 2, 7)), isFalse);
    });

    test('a day the month does not have simply does not occur', () {
      final task = makeTask(
        createdAt: created,
        recurrence: const RecurrenceRule(
            type: RecurrenceType.monthly, monthDays: [31]),
      );
      expect(appliesOn(task, DateTime(2026, 1, 31)), isTrue);
      // February 2026 has 28 days, so nothing matches that month
      for (var d = 1; d <= 28; d++) {
        expect(appliesOn(task, DateTime(2026, 2, d)), isFalse);
      }
    });

    test('kLastDayOfMonth resolves per month, including leap February', () {
      final task = makeTask(
        createdAt: created,
        recurrence: const RecurrenceRule(
            type: RecurrenceType.monthly, monthDays: [kLastDayOfMonth]),
      );
      expect(appliesOn(task, DateTime(2026, 1, 31)), isTrue); // 31-day month
      expect(appliesOn(task, DateTime(2026, 4, 30)), isTrue); // 30-day month
      expect(appliesOn(task, DateTime(2026, 2, 28)), isTrue); // non-leap Feb
      expect(appliesOn(task, DateTime(2028, 2, 29)), isTrue); // leap Feb
      expect(appliesOn(task, DateTime(2028, 2, 28)), isFalse);
    });
  });

  group('everyNDays', () {
    test('matches multiples of the interval from the creation day', () {
      final task = makeTask(
        createdAt: created,
        recurrence: const RecurrenceRule(
            type: RecurrenceType.everyNDays, interval: 3),
      );
      expect(appliesOn(task, created), isTrue);
      expect(appliesOn(task, DateTime(2026, 1, 10)), isTrue);
      expect(appliesOn(task, DateTime(2026, 1, 9)), isFalse);
    });

    test('an interval of 0 stored in the DB is clamped on read', () {
      // A 0 persisted before validation existed would otherwise throw on
      // mobile and silently produce NaN on web
      final task = Task.fromJson({
        'id': 't1',
        'title': 'test',
        'created_at': created.toIso8601String(),
        'recurrence_type': 'everyNDays',
        'recurrence_interval': 0,
      });
      expect(task.recurrence!.interval, 1);
      expect(() => appliesOn(task, DateTime(2026, 1, 8)), returnsNormally);
      expect(appliesOn(task, DateTime(2026, 1, 8)), isTrue);
    });
  });

  group('completion stats', () {
    test('returns null when nothing applies that day', () {
      final task = makeTask(createdAt: created, dueTime: DateTime(2026, 1, 9));
      expect(taskCompletionStatsOn([task], DateTime(2026, 1, 10)), isNull);
    });

    test('counts done vs total for the day', () {
      final a = Task(
          id: 'a',
          title: 'a',
          createdAt: created,
          dueTime: DateTime(2026, 1, 9),
          isCompleted: true);
      final b = Task(
          id: 'b',
          title: 'b',
          createdAt: created,
          dueTime: DateTime(2026, 1, 9));
      final stats = taskCompletionStatsOn([a, b], DateTime(2026, 1, 9));
      expect(stats, isNotNull);
      expect(stats!.done, 1);
      expect(stats.total, 2);
    });
  });
}
