import '../l10n/app_strings.dart';
import '../models/notification_settings.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart' show taskAppliesTo;
import '../utils/semester_helpers.dart';
import 'notification_constants.dart';
import 'notification_payload.dart';

// One pending notification, already resolved to a wall-clock time and the text
// the user will read. Deliberately free of any plugin type so the whole
// decision of "what fires, and when" is a pure function that tests can check
// without a platform channel
class ScheduledNotification {
  final int id;
  final NotificationKind kind;
  final DateTime when;
  final String title;
  // Task reminders have none: the title is the task name and the space below it
  // is taken by the action buttons
  final String? body;
  // Only task reminders carry one, because only they have something to act on
  final String? payload;

  const ScheduledNotification({
    required this.id,
    required this.kind,
    required this.when,
    required this.title,
    this.body,
    this.payload,
  });
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Everything the device should be told about, from now to the scheduling
// horizon. The caller cancels all pending notifications and re-registers this
// list, so it is always the complete picture rather than a delta
List<ScheduledNotification> buildNotificationSchedule({
  required List<Task> tasks,
  required List<SemesterGoal> goals,
  required NotificationSettings settings,
  required SemesterSettings semesterSettings,
  required AppStrings s,
  required DateTime now,
}) {
  // The master switch is not checked here: NotificationSettings.isOn() folds it
  // into every kind, so there is one place that decides rather than two that
  // can disagree
  final out = <ScheduledNotification>[];
  final horizon =
      now.add(const Duration(days: NotificationConstants.scheduleHorizonDays));

  if (settings.isOn(NotificationKind.taskDue)) {
    out.addAll(_taskReminders(tasks, settings, s, now, horizon));
  }
  if (settings.isOn(NotificationKind.dailySummary)) {
    out.addAll(_dailySummaries(tasks, settings, s, now, horizon));
  }
  if (settings.isOn(NotificationKind.goalDeadline)) {
    out.addAll(_goalDeadlines(goals, settings, semesterSettings, s, now, horizon));
  }

  out.sort((a, b) => a.when.compareTo(b.when));

  // Ids are handed out after sorting rather than derived from the row id: the
  // caller always cancels everything first, so sequential ids cannot collide,
  // and hashing a row id into an int range could
  final capped = out.take(NotificationConstants.maxScheduled).toList();
  return [
    for (var i = 0; i < capped.length; i++)
      ScheduledNotification(
        id: _baseFor(capped[i].kind) + i,
        kind: capped[i].kind,
        when: capped[i].when,
        title: capped[i].title,
        body: capped[i].body,
        payload: capped[i].payload,
      ),
  ];
}

int _baseFor(NotificationKind kind) => switch (kind) {
      NotificationKind.taskDue => NotificationConstants.taskIdBase,
      NotificationKind.dailySummary => NotificationConstants.summaryIdBase,
      NotificationKind.goalDeadline => NotificationConstants.goalIdBase,
    };

// A one-off task with no due time has no moment to remind about — the daily
// summary is what covers those. A repeating one without a time still fires, at
// the user's chosen time of day, because a habit with no reminder is easy to
// forget in a way a one-off entry on the list is not
Iterable<ScheduledNotification> _taskReminders(
  List<Task> tasks,
  NotificationSettings settings,
  AppStrings s,
  DateTime now,
  DateTime horizon,
) sync* {
  final lead = Duration(minutes: settings.taskLeadMinutes);

  for (final task in tasks) {
    final isRecurring = task.recurrence != null && !task.recurrence!.isNone;
    if (task.dueTime == null) {
      if (isRecurring) {
        yield* _untimedRecurringReminders(task, settings, now, horizon);
      }
      continue;
    }

    if (!isRecurring) {
      if (task.isCompleted) continue;
      final fireAt = task.dueTime!.subtract(lead);
      if (fireAt.isAfter(now) && fireAt.isBefore(horizon)) {
        yield ScheduledNotification(
          id: 0,
          kind: NotificationKind.taskDue,
          when: fireAt,
          title: task.title,
          payload: TaskNotificationPayload(
            taskId: task.id,
            date: _dateOnly(task.dueTime!),
          ).encode(),
        );
      }
      continue;
    }

    // A recurring task's dueTime carries a meaningful time of day but a
    // meaningless date — the rule decides which days it lands on
    for (var day = _dateOnly(now);
        day.isBefore(horizon);
        day = day.add(const Duration(days: 1))) {
      if (!taskAppliesTo(task, day)) continue;
      if (task.isCompletedOn(day)) continue;

      final dueThatDay = DateTime(
        day.year,
        day.month,
        day.day,
        task.dueTime!.hour,
        task.dueTime!.minute,
      );
      final fireAt = dueThatDay.subtract(lead);
      if (fireAt.isAfter(now) && fireAt.isBefore(horizon)) {
        yield ScheduledNotification(
          id: 0,
          kind: NotificationKind.taskDue,
          when: fireAt,
          title: task.title,
          // The day, not the series: ticking one occurrence must not complete
          // every future one
          payload: TaskNotificationPayload(taskId: task.id, date: day).encode(),
        );
      }
    }
  }
}

// No lead time: the lead is "how long before it is due", and a task with no due
// time is not due at any moment — the chosen time is the reminder itself
Iterable<ScheduledNotification> _untimedRecurringReminders(
  Task task,
  NotificationSettings settings,
  DateTime now,
  DateTime horizon,
) sync* {
  for (var day = _dateOnly(now);
      day.isBefore(horizon);
      day = day.add(const Duration(days: 1))) {
    if (!taskAppliesTo(task, day)) continue;
    if (task.isCompletedOn(day)) continue;

    final fireAt = day.add(Duration(minutes: settings.recurringMinuteOfDay));
    if (!fireAt.isAfter(now) || !fireAt.isBefore(horizon)) continue;

    yield ScheduledNotification(
      id: 0,
      kind: NotificationKind.taskDue,
      when: fireAt,
      title: task.title,
      payload: TaskNotificationPayload(taskId: task.id, date: day).encode(),
    );
  }
}

// Skips days with nothing on them. A summary that says "nothing planned" every
// morning trains the user to swipe the channel away, and then the days that do
// matter are gone too
Iterable<ScheduledNotification> _dailySummaries(
  List<Task> tasks,
  NotificationSettings settings,
  AppStrings s,
  DateTime now,
  DateTime horizon,
) sync* {
  for (var day = _dateOnly(now);
      day.isBefore(horizon);
      day = day.add(const Duration(days: 1))) {
    final fireAt = day.add(Duration(minutes: settings.summaryMinuteOfDay));
    if (!fireAt.isAfter(now) || !fireAt.isBefore(horizon)) continue;

    final count = tasks
        .where((t) => taskAppliesTo(t, day) && !t.isCompletedOn(day))
        .length;
    if (count == 0) continue;

    yield ScheduledNotification(
      id: 0,
      kind: NotificationKind.dailySummary,
      when: fireAt,
      title: s.notifSummaryTitle,
      body: s.notifSummaryBody(count),
    );
  }
}

// One notification per semester that is running out, not one per goal: a
// student with eight unfinished targets does not need eight buzzes
Iterable<ScheduledNotification> _goalDeadlines(
  List<SemesterGoal> goals,
  NotificationSettings settings,
  SemesterSettings semesterSettings,
  AppStrings s,
  DateTime now,
  DateTime horizon,
) sync* {
  final pending = <String, int>{};
  for (final goal in goals) {
    // Milestones inherit their parent's semester, so counting them as well
    // would double-count the same work
    if (goal.parentId != null || goal.isDone) continue;
    pending.update(goal.semester, (n) => n + 1, ifAbsent: () => 1);
  }

  for (final entry in pending.entries) {
    final end = semesterEnd(entry.key, semesterSettings);
    final fireAt = end
        .subtract(Duration(days: settings.goalLeadDays))
        .add(Duration(minutes: settings.summaryMinuteOfDay));
    if (!fireAt.isAfter(now) || !fireAt.isBefore(horizon)) continue;

    yield ScheduledNotification(
      id: 0,
      kind: NotificationKind.goalDeadline,
      when: fireAt,
      title: s.notifGoalTitle,
      body: s.notifGoalBody(entry.key, entry.value),
    );
  }
}
