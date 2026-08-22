import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/task.dart';

void main() {
  final created = DateTime(2026, 1, 7, 9, 30);

  Task fullTask() => Task(
        id: 't1',
        title: 'title',
        content: 'note',
        dueTime: DateTime(2026, 1, 9, 18),
        priority: 3,
        isCompleted: true,
        createdAt: created,
        recurrence: const RecurrenceRule(
            type: RecurrenceType.weekly, weekdays: [1, 5]),
        linkedTargetId: 'target1',
        linkedGoalId: 'goal1',
        parentTaskId: 'parent1',
        sortOrder: 3000,
        completedDates: const ['2026-01-09'],
      );

  group('JSON round-trip', () {
    test('preserves every field', () {
      final original = fullTask();
      final restored = Task.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      expect(restored.dueTime, original.dueTime);
      expect(restored.priority, original.priority);
      expect(restored.isCompleted, original.isCompleted);
      expect(restored.createdAt, original.createdAt);
      expect(restored.linkedTargetId, original.linkedTargetId);
      expect(restored.linkedGoalId, original.linkedGoalId);
      expect(restored.parentTaskId, original.parentTaskId);
      expect(restored.sortOrder, original.sortOrder);
      expect(restored.completedDates, original.completedDates);
      expect(restored.recurrence!.type, RecurrenceType.weekly);
      expect(restored.recurrence!.weekdays, [1, 5]);
    });

    test('round-trips monthly days including the last-day sentinel', () {
      final task = Task(
        id: 't2',
        title: 'monthly',
        createdAt: created,
        recurrence: const RecurrenceRule(
            type: RecurrenceType.monthly, monthDays: [1, kLastDayOfMonth]),
      );
      final restored = Task.fromJson(task.toJson());
      expect(restored.recurrence!.monthDays, [1, kLastDayOfMonth]);
    });

    test('omits recurrence_month_days when unused', () {
      // The column may not exist yet; PostgREST rejects the whole row if an
      // unknown key is present, so the key must be absent when empty
      final task = Task(id: 't3', title: 'plain', createdAt: created);
      expect(task.toJson().containsKey('recurrence_month_days'), isFalse);
    });

    test('a null recurrence survives the trip', () {
      final task = Task(id: 't4', title: 'plain', createdAt: created);
      expect(Task.fromJson(task.toJson()).recurrence, isNull);
    });
  });

  group('copyWith', () {
    test('leaves untouched fields alone', () {
      final original = fullTask();
      final copy = original.copyWith(title: 'renamed');

      expect(copy.title, 'renamed');
      expect(copy.content, original.content);
      expect(copy.parentTaskId, original.parentTaskId);
      expect(copy.sortOrder, original.sortOrder);
      expect(copy.completedDates, original.completedDates);
      expect(copy.recurrence, original.recurrence);
    });

    test('can clear content to null', () {
      // Regression: content used to be a plain String? with ??, so passing
      // null was indistinguishable from omitting it and could never clear
      final copy = fullTask().copyWith(content: null);
      expect(copy.content, isNull);
    });

    test('can clear the nullable link fields to null', () {
      final copy = fullTask()
          .copyWith(linkedTargetId: null, linkedGoalId: null, parentTaskId: null);
      expect(copy.linkedTargetId, isNull);
      expect(copy.linkedGoalId, isNull);
      expect(copy.parentTaskId, isNull);
    });

    test('omitting a nullable field keeps the existing value', () {
      final copy = fullTask().copyWith(title: 'x');
      expect(copy.linkedTargetId, 'target1');
      expect(copy.dueTime, isNotNull);
    });
  });

  group('isCompletedOn', () {
    test('non-recurring tasks use the isCompleted flag', () {
      final task = Task(
          id: 'a',
          title: 'a',
          createdAt: created,
          isCompleted: true);
      expect(task.isCompletedOn(DateTime(2026, 3, 1)), isTrue);
    });

    test('recurring tasks look at completedDates for that day', () {
      final task = Task(
        id: 'b',
        title: 'b',
        createdAt: created,
        isCompleted: true, // must be ignored for recurring tasks
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
        completedDates: const ['2026-01-09'],
      );
      expect(task.isCompletedOn(DateTime(2026, 1, 9)), isTrue);
      expect(task.isCompletedOn(DateTime(2026, 1, 10)), isFalse);
    });
  });
}
