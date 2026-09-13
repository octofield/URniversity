import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/notification_payload.dart';
import 'package:urniversity/models/task.dart';

// The "mark as done" action runs in a background isolate with no providers and
// no UI, so everything it depends on is kept pure and pinned here.
void main() {
  Task task({
    RecurrenceRule? recurrence,
    bool isCompleted = false,
    List<String> completedDates = const [],
  }) =>
      Task(
        id: 't1',
        title: 'Task',
        recurrence: recurrence,
        isCompleted: isCompleted,
        completedDates: completedDates,
        createdAt: DateTime(2026, 9, 1),
      );

  group('Task.toggledOn', () {
    final day = DateTime(2026, 9, 14);

    test('flips a plain task', () {
      expect(task().toggledOn(day).isCompleted, isTrue);
      expect(task(isCompleted: true).toggledOn(day).isCompleted, isFalse);
    });

    test('a recurring task records the one day, not the series', () {
      final result = task(
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      ).toggledOn(day);

      expect(result.completedDates, ['2026-09-14']);
      // The series itself stays open, so tomorrow still reminds
      expect(result.isCompleted, isFalse);
    });

    test('toggling the same recurring day again clears it', () {
      final result = task(
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
        completedDates: const ['2026-09-14'],
      ).toggledOn(day);

      expect(result.completedDates, isEmpty);
    });

    test('other completed days are left alone', () {
      final result = task(
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
        completedDates: const ['2026-09-13'],
      ).toggledOn(day);

      expect(result.completedDates, containsAll(['2026-09-13', '2026-09-14']));
    });

    test('it is the exact inverse of isCompletedOn', () {
      for (final original in [
        task(),
        task(isCompleted: true),
        task(recurrence: const RecurrenceRule(type: RecurrenceType.daily)),
        task(
          recurrence: const RecurrenceRule(type: RecurrenceType.daily),
          completedDates: const ['2026-09-14'],
        ),
      ]) {
        expect(
          original.toggledOn(day).isCompletedOn(day),
          !original.isCompletedOn(day),
        );
      }
    });

    test('a single digit month and day are zero padded', () {
      final result = task(
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      ).toggledOn(DateTime(2026, 1, 5));
      // Must match the key isCompletedOn builds, or the tick is invisible
      expect(result.completedDates, ['2026-01-05']);
      expect(result.isCompletedOn(DateTime(2026, 1, 5)), isTrue);
    });
  });

  group('TaskNotificationPayload', () {
    test('encodes id and day', () {
      final payload = TaskNotificationPayload(
        taskId: '1757000000000_42',
        date: DateTime(2026, 1, 5),
      );
      expect(payload.encode(), '1757000000000_42|2026-01-05');
    });

    test('decodes what it encoded', () {
      final original = TaskNotificationPayload(
        taskId: '1757000000000_42',
        date: DateTime(2026, 9, 14),
      );
      final decoded = TaskNotificationPayload.decode(original.encode())!;
      expect(decoded.taskId, original.taskId);
      expect(decoded.date, original.date);
    });

    test('a malformed payload decodes to null instead of throwing', () {
      // Nothing can catch an exception in the background isolate
      for (final bad in [null, '', 'no-separator', '|2026-09-14', 'id|nope']) {
        expect(TaskNotificationPayload.decode(bad), isNull, reason: '$bad');
      }
    });
  });

  group('NotificationActionRecord', () {
    test('a success carries no error', () {
      const record = NotificationActionRecord(taskId: 't1');
      expect(record.failed, isFalse);
      final back = NotificationActionRecord.decodeList(
          NotificationActionRecord.encodeList([record]));
      expect(back.single.taskId, 't1');
      expect(back.single.failed, isFalse);
    });

    test('a failure keeps the reason so the UI can show it later', () {
      const record =
          NotificationActionRecord(taskId: 't1', error: 'SocketException');
      final back = NotificationActionRecord.decodeList(
          NotificationActionRecord.encodeList([record]));
      expect(back.single.failed, isTrue);
      expect(back.single.error, 'SocketException');
    });

    test('several actions accumulate', () {
      final encoded = NotificationActionRecord.encodeList(const [
        NotificationActionRecord(taskId: 'a'),
        NotificationActionRecord(taskId: 'b', error: 'boom'),
      ]);
      final back = NotificationActionRecord.decodeList(encoded);
      expect(back, hasLength(2));
      expect(back.where((r) => r.failed), hasLength(1));
    });

    test('an unreadable log is dropped, not thrown', () {
      // Losing the reload hint is survivable; failing to start is not
      expect(NotificationActionRecord.decodeList('not json'), isEmpty);
      expect(NotificationActionRecord.decodeList(null), isEmpty);
      expect(NotificationActionRecord.decodeList(''), isEmpty);
    });
  });
}
