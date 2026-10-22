import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/notification_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import '../helpers/pump_app.dart';

// A task finished on another device arrives as a change to the list; the
// reminder for it on this device is taken down then (system_design.md §3-K,
// 2026-10-22)
void main() {
  setUp(() => setUpTestSupabase());

  test('every change to the task list asks for finished reminders to go', () async {
    final seen = <List<Task>>[];
    final real = dismissFinishedReminders;
    dismissFinishedReminders = (tasks) async => seen.add(tasks);
    addTearDown(() => dismissFinishedReminders = real);

    final c = testContainer(overrides: [notificationScheduleProvider.overrideWithValue(const [])]);
    c.read(notificationSyncProvider);
    final task = Task(id: 't1', title: '交報告', createdAt: DateTime(2026, 10, 1));
    // As a push from another device lands: the row comes back done
    c.read(tasksProvider.notifier).state = [task];
    c.read(tasksProvider.notifier).state = [task.copyWith(isCompleted: true)];
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(2));
    expect(seen.last.single.isCompleted, isTrue);
  });
}
