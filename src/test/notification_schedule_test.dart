import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/notification_constants.dart';
import 'package:urniversity/core/notification_payload.dart';
import 'package:urniversity/core/notification_schedule.dart';
import 'package:urniversity/l10n/strings_en.dart';
import 'package:urniversity/models/notification_settings.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/settings_provider.dart';

// buildNotificationSchedule decides what fires and when. It is kept free of any
// plugin type precisely so these cases can run without a platform channel.
void main() {
  const s = StringsEn();
  const semSettings = SemesterSettings(count: 2, startMonths: [8, 2]);
  // A Monday, mid-morning
  final now = DateTime(2026, 9, 14, 10, 0);

  const allOn = NotificationSettings(enabled: true);

  Task task({
    String id = 't1',
    String title = 'Task',
    DateTime? dueTime,
    bool isCompleted = false,
    RecurrenceRule? recurrence,
    String? parentTaskId,
    DateTime? createdAt,
    List<String> completedDates = const [],
  }) =>
      Task(
        id: id,
        title: title,
        dueTime: dueTime,
        isCompleted: isCompleted,
        recurrence: recurrence,
        parentTaskId: parentTaskId,
        completedDates: completedDates,
        createdAt: createdAt ?? DateTime(2026, 9, 1),
      );

  SemesterGoal goal({
    String id = 'g1',
    String semester = '115-1',
    String? parentId,
    bool isDone = false,
  }) =>
      SemesterGoal(
        id: id,
        title: 'Goal',
        semester: semester,
        categories: const ['other'],
        parentId: parentId,
        isDone: isDone,
      );

  List<ScheduledNotification> build({
    List<Task> tasks = const [],
    List<SemesterGoal> goals = const [],
    NotificationSettings settings = allOn,
    DateTime? at,
  }) =>
      buildNotificationSchedule(
        tasks: tasks,
        goals: goals,
        settings: settings,
        semesterSettings: semSettings,
        s: s,
        now: at ?? now,
      );

  group('the master switch', () {
    test('nothing is scheduled while notifications are off', () {
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))],
        settings: const NotificationSettings(),
      );
      expect(scheduled, isEmpty);
    });

    test('it overrides the individual switches', () {
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))],
        settings: const NotificationSettings(taskDueEnabled: true),
      );
      expect(scheduled, isEmpty);
    });
  });

  group('task reminders', () {
    test('fire the configured lead time before the due time', () {
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))],
        settings: allOn.copyWith(
          dailySummaryEnabled: false,
          goalDeadlineEnabled: false,
          taskLeadMinutes: 30,
        ),
      );
      expect(scheduled, hasLength(1));
      expect(scheduled.single.when, DateTime(2026, 9, 14, 14, 30));
      expect(scheduled.single.title, 'Task');
      // The body is gone on purpose: the action buttons occupy that space
      expect(scheduled.single.body, isNull);
    });

    test('a lead of zero fires at the due time itself', () {
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))],
        settings: allOn.copyWith(
          dailySummaryEnabled: false,
          goalDeadlineEnabled: false,
          taskLeadMinutes: 0,
        ),
      );
      expect(scheduled.single.when, DateTime(2026, 9, 14, 15, 0));
    });

    test('a reminder already in the past is not scheduled', () {
      // 09:00 today, with now at 10:00
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 14, 9, 0))],
        settings: allOn.copyWith(
            dailySummaryEnabled: false, goalDeadlineEnabled: false),
      );
      expect(scheduled, isEmpty);
    });

    test('a completed task is not scheduled', () {
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0), isCompleted: true)],
        settings: allOn.copyWith(
            dailySummaryEnabled: false, goalDeadlineEnabled: false),
      );
      expect(scheduled, isEmpty);
    });

    test('a task with no due time has no moment to remind about', () {
      final scheduled = build(
        tasks: [task()],
        settings: allOn.copyWith(
            dailySummaryEnabled: false, goalDeadlineEnabled: false),
      );
      expect(scheduled, isEmpty);
    });

    test('a daily task is scheduled once per day in the horizon', () {
      final scheduled = build(
        tasks: [
          task(
            dueTime: DateTime(2026, 9, 1, 21, 0),
            recurrence: const RecurrenceRule(type: RecurrenceType.daily),
          ),
        ],
        settings: allOn.copyWith(
            dailySummaryEnabled: false,
            goalDeadlineEnabled: false,
            taskLeadMinutes: 0),
      );
      // Today's 21:00 is still ahead, so every day of the horizon counts
      expect(scheduled, hasLength(NotificationConstants.scheduleHorizonDays));
      expect(scheduled.first.when, DateTime(2026, 9, 14, 21, 0));
    });

    test('a weekly task only lands on its chosen weekdays', () {
      final scheduled = build(
        tasks: [
          task(
            dueTime: DateTime(2026, 9, 1, 21, 0),
            // Tuesday and Thursday
            recurrence: const RecurrenceRule(
                type: RecurrenceType.weekly, weekdays: [2, 4]),
          ),
        ],
        settings: allOn.copyWith(
            dailySummaryEnabled: false, goalDeadlineEnabled: false),
      );
      expect(scheduled, hasLength(4));
      for (final n in scheduled) {
        expect([2, 4], contains(n.when.weekday));
      }
    });

    test('a recurring day already completed is skipped', () {
      final scheduled = build(
        tasks: [
          task(
            dueTime: DateTime(2026, 9, 1, 21, 0),
            recurrence: const RecurrenceRule(type: RecurrenceType.daily),
            completedDates: const ['2026-09-14', '2026-09-15'],
          ),
        ],
        settings: allOn.copyWith(
            dailySummaryEnabled: false, goalDeadlineEnabled: false),
      );
      expect(scheduled, hasLength(NotificationConstants.scheduleHorizonDays - 2));
    });
  });

  group('daily summary', () {
    test('counts the tasks that apply to that day', () {
      final scheduled = build(
        tasks: [
          task(id: 'a', dueTime: DateTime(2026, 9, 15, 9, 0)),
          task(id: 'b', dueTime: DateTime(2026, 9, 15, 11, 0)),
        ],
        settings: allOn.copyWith(
            taskDueEnabled: false,
            goalDeadlineEnabled: false,
            summaryMinuteOfDay: 8 * 60),
      );
      expect(scheduled, hasLength(1));
      expect(scheduled.single.when, DateTime(2026, 9, 15, 8, 0));
      expect(scheduled.single.body, s.notifSummaryBody(2));
    });

    test('an empty day gets no summary at all', () {
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 15, 9, 0))],
        settings: allOn.copyWith(
            taskDueEnabled: false, goalDeadlineEnabled: false),
      );
      // Only the 15th has anything on it
      expect(scheduled, hasLength(1));
    });

    test("today's summary is skipped once its time has passed", () {
      final scheduled = build(
        // now is 10:00, summary time is 08:00
        tasks: [task(dueTime: DateTime(2026, 9, 14, 23, 0))],
        settings: allOn.copyWith(
            taskDueEnabled: false, goalDeadlineEnabled: false),
      );
      expect(scheduled, isEmpty);
    });
  });

  group('semester goal deadlines', () {
    // A 2-semester year starting in August: 115-1 runs to the day before
    // 115-2 starts, i.e. 2027-01-31
    test('one notification per semester, not one per goal', () {
      final scheduled = build(
        goals: [goal(id: 'a'), goal(id: 'b'), goal(id: 'c')],
        settings: allOn.copyWith(
            taskDueEnabled: false,
            dailySummaryEnabled: false,
            goalLeadDays: 7),
        at: DateTime(2027, 1, 20, 10, 0),
      );
      expect(scheduled, hasLength(1));
      expect(scheduled.single.body, s.notifGoalBody('115-1', 3));
      expect(scheduled.single.when, DateTime(2027, 1, 24, 8, 0));
    });

    test('milestones are not counted twice', () {
      final scheduled = build(
        goals: [goal(id: 'a'), goal(id: 'b', parentId: 'a')],
        settings: allOn.copyWith(
            taskDueEnabled: false, dailySummaryEnabled: false),
        at: DateTime(2027, 1, 20, 10, 0),
      );
      expect(scheduled.single.body, s.notifGoalBody('115-1', 1));
    });

    test('a semester with everything done is not mentioned', () {
      final scheduled = build(
        goals: [goal(id: 'a', isDone: true)],
        settings: allOn.copyWith(
            taskDueEnabled: false, dailySummaryEnabled: false),
        at: DateTime(2027, 1, 20, 10, 0),
      );
      expect(scheduled, isEmpty);
    });

    test('a deadline beyond the horizon waits', () {
      final scheduled = build(
        goals: [goal()],
        settings: allOn.copyWith(
            taskDueEnabled: false, dailySummaryEnabled: false),
        at: DateTime(2026, 9, 14, 10, 0),
      );
      expect(scheduled, isEmpty);
    });
  });

  group('the action payload', () {
    test('a task reminder names the task and the day it is for', () {
      final scheduled = build(
        tasks: [task(id: 'abc', dueTime: DateTime(2026, 9, 15, 9, 0))],
        settings: allOn.copyWith(
            dailySummaryEnabled: false, goalDeadlineEnabled: false),
      );
      final payload = TaskNotificationPayload.decode(scheduled.single.payload)!;
      expect(payload.taskId, 'abc');
      expect(payload.date, DateTime(2026, 9, 15));
    });

    test('each occurrence of a recurring task names its own day', () {
      final scheduled = build(
        tasks: [
          task(
            id: 'abc',
            dueTime: DateTime(2026, 9, 1, 21, 0),
            recurrence: const RecurrenceRule(type: RecurrenceType.daily),
          ),
        ],
        settings: allOn.copyWith(
            dailySummaryEnabled: false, goalDeadlineEnabled: false),
      );
      // Ticking one day must not complete the whole series, so every
      // notification has to carry the day it belongs to
      final days = scheduled
          .map((n) => TaskNotificationPayload.decode(n.payload)!.date)
          .toSet();
      expect(days, hasLength(scheduled.length));
    });

    test('summary and goal reminders carry none', () {
      final scheduled = build(
        tasks: [task(dueTime: DateTime(2026, 9, 15, 9, 0))],
        goals: [goal()],
        settings: allOn.copyWith(taskDueEnabled: false),
      );
      expect(scheduled, isNotEmpty);
      for (final n in scheduled) {
        expect(n.payload, isNull, reason: '${n.kind} has nothing to act on');
      }
    });
  });

  group('the whole schedule', () {
    test('is ordered by time and capped', () {
      final scheduled = build(
        tasks: [
          for (var i = 0; i < 20; i++)
            task(
              id: 'r$i',
              dueTime: DateTime(2026, 9, 1, 21, 0),
              recurrence: const RecurrenceRule(type: RecurrenceType.daily),
            ),
        ],
      );
      expect(scheduled.length, NotificationConstants.maxScheduled);
      for (var i = 1; i < scheduled.length; i++) {
        expect(scheduled[i].when.isBefore(scheduled[i - 1].when), isFalse);
      }
    });

    test('ids are unique and sit in their own kind range', () {
      final scheduled = build(
        tasks: [
          task(dueTime: DateTime(2026, 9, 15, 9, 0)),
          task(id: 't2', dueTime: DateTime(2026, 9, 16, 9, 0)),
        ],
      );
      expect(scheduled.map((n) => n.id).toSet(), hasLength(scheduled.length));
      for (final n in scheduled) {
        final base = switch (n.kind) {
          NotificationKind.taskDue => NotificationConstants.taskIdBase,
          NotificationKind.dailySummary => NotificationConstants.summaryIdBase,
          NotificationKind.goalDeadline => NotificationConstants.goalIdBase,
        };
        expect(n.id, greaterThanOrEqualTo(base));
        expect(n.id, lessThan(base + NotificationConstants.maxScheduled));
      }
    });
  });
}
