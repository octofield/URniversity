import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/notification_cancel.dart';
import 'package:urniversity/core/notification_payload.dart';
import 'package:urniversity/models/task.dart';

// A reminder now stays in the shade until its task is done, so something has to
// decide which of the notifications on screen belong to the task just ticked
// off — from the app, from the notification's own button, or from the home
// screen widget's tick box.
void main() {
  ({int? id, String? payload}) shown(int? id, String? payload) =>
      (id: id, payload: payload);

  String payloadFor(String taskId, DateTime date) =>
      TaskNotificationPayload(taskId: taskId, date: date).encode();

  final today = DateTime(2026, 9, 20);

  test('only the ticked task is taken down', () {
    final ids = notificationIdsForTask([
      shown(1, payloadFor('task-a', today)),
      shown(2, payloadFor('task-b', today)),
      shown(3, payloadFor('task-a', DateTime(2026, 9, 21))),
    ], 'task-a');

    expect(ids, [1, 3]);
  });

  test('a summary or a goal deadline has no payload and is left alone', () {
    final ids = notificationIdsForTask([
      shown(10, null),
      shown(11, ''),
      shown(12, 'not a payload'),
      shown(13, payloadFor('task-a', today)),
    ], 'task-a');

    expect(ids, [13]);
  });

  test('an entry with no id cannot be cancelled and is skipped', () {
    final ids = notificationIdsForTask([
      shown(null, payloadFor('task-a', today)),
    ], 'task-a');

    expect(ids, isEmpty);
  });

  test('nothing on screen means nothing to cancel', () {
    expect(notificationIdsForTask(const [], 'task-a'), isEmpty);
  });

  // Finished or deleted elsewhere (2026-10-22): the list changes through sync,
  // and the reminders on this device for what is now done have to go too
  group('reminders for what is done or gone', () {
    Task task(String id, {List<String> doneDates = const [], bool done = false, RecurrenceRule? repeat}) => Task(
          id: id,
          title: id,
          createdAt: DateTime(2026, 9, 1),
          isCompleted: done,
          completedDates: doneDates,
          recurrence: repeat,
        );
    const daily = RecurrenceRule(type: RecurrenceType.daily);

    test('done goes, still to do stays, gone goes, a summary stays', () {
      final ids = notificationIdsToDismiss([
        shown(1, payloadFor('done', today)),
        shown(2, payloadFor('open', today)),
        shown(3, payloadFor('deleted', today)),
        shown(4, null),
      ], [task('done', done: true), task('open')]);
      expect(ids, [1, 3]);
    });

    test('a repeating task: only the day that was done', () {
      final ids = notificationIdsToDismiss([
        shown(1, payloadFor('run', today)),
        shown(2, payloadFor('run', DateTime(2026, 9, 21))),
      ], [task('run', repeat: daily, doneDates: ['2026-09-20'])]);
      expect(ids, [1]);
    });

    test('before the tasks have loaded, nothing counts as deleted', () {
      expect(notificationIdsToDismiss([shown(1, payloadFor('a', today))], const []), isEmpty);
    });
  });
}

