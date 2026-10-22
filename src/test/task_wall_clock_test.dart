import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/notification_schedule.dart';
import 'package:urniversity/l10n/strings_en.dart';
import 'package:urniversity/models/notification_settings.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/settings_provider.dart';

// Times read back from Supabase (data_dictionary.md D1, 2026-10-22). The app
// writes the local clock with no zone; the columns are timestamptz, so they
// keep that clock as UTC and hand it back as "…+00:00". Parsed as it comes,
// the time was a UTC moment: right on the clock face, but hours off against
// "now" — reminders, due colours and "overdue" all moved by the zone offset
void main() {
  Map<String, dynamic> row(String due) => {
        'id': 't1',
        'title': '交報告',
        'is_completed': false,
        'created_at': '2026-10-20T09:15:00+00:00',
        'due_time': due,
      };

  test('a time back from the server is the local clock it was written as', () {
    final task = Task.fromJson(row('2026-10-23T07:00:00+00:00'));
    expect(task.dueTime, DateTime(2026, 10, 23, 7));
    expect(task.dueTime!.isUtc, isFalse);
    expect(task.createdAt, DateTime(2026, 10, 20, 9, 15));
  });

  test('written out and read back, it does not move', () {
    final local = Task(id: 't1', title: '交報告', createdAt: DateTime(2026, 10, 20, 9, 15), dueTime: DateTime(2026, 10, 23, 7));
    expect(Task.fromJson(local.toJson()).dueTime, local.dueTime);
    // And as the server returns what was written
    final fromServer = Task.fromJson({...local.toJson(), 'due_time': '2026-10-23T07:00:00+00:00'});
    expect(Task.fromJson(fromServer.toJson()).dueTime, local.dueTime);
  });

  test('a reminder for such a task fires at the local time, its lead before', () {
    final task = Task.fromJson(row('2026-10-23T07:00:00+00:00'));
    final scheduled = buildNotificationSchedule(
      tasks: [task],
      goals: const [],
      settings: const NotificationSettings(enabled: true, dailySummaryEnabled: false, goalDeadlineEnabled: false, weeklyReviewEnabled: false),
      semesterSettings: SemesterSettings.defaultSettings,
      s: const StringsEn(),
      now: DateTime(2026, 10, 22, 12),
    );
    expect(scheduled.single.when, DateTime(2026, 10, 23, 6, 30));
  });
}
