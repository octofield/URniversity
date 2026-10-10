import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/review_stats.dart' show termAt;
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/course.dart';
import 'package:urniversity/providers/courses_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/today_screen.dart' show TaskTile;
import 'package:urniversity/widgets/swipe_switcher.dart';

import '../helpers/pump_app.dart';

// The course view (system_design.md §2-B, 2026-10-10): after the day view,
// this semester's courses in the order they meet, each with its tasks
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  String semester(ProviderContainer c) => termAt(c.read(effectiveNowProvider), c.read(semesterSettingsProvider));

  testWidgets('sits between the day and the week, for the switch and for swiping', (tester) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    final labels = tester
        .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>).first)
        .segments
        .map((seg) => seg.value)
        .toList();
    expect(labels, kTaskViewOrder);
    expect(kTaskViewOrder, [0, 1, kCourseTaskView, 2]);

    await tester.fling(find.byType(SwipeSwitcher).first, const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(c.read(taskViewProvider), kCourseTaskView);
    await tester.fling(find.byType(SwipeSwitcher).first, const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(c.read(taskViewProvider), 2, reason: 'then the week');
  });

  testWidgets('courses in the order they meet, each with its tasks; done ones folded', (tester) async {
    final c = await pumpApp(tester);
    final courses = c.read(coursesProvider.notifier);
    final tuesday = courses.add(
      semester: semester(c),
      title: '普通物理',
      sessions: const [CourseSession(weekday: 2, startMinute: 620, endMinute: 730)],
    );
    courses.add(
      semester: semester(c),
      title: '微積分',
      sessions: const [CourseSession(weekday: 1, startMinute: 550, endMinute: 670)],
    );
    final tasks = c.read(tasksProvider.notifier);
    tasks.add('實驗報告', linkedCourseId: tuesday.id);
    tasks.add('上週的報告', linkedCourseId: tuesday.id);
    tasks.toggleOnDate(c.read(tasksProvider).firstWhere((t) => t.title == '上週的報告').id, DateTime.now());
    c.read(taskViewProvider.notifier).state = kCourseTaskView;
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('微積分').first).dy, lessThan(tester.getTopLeft(find.text('普通物理').first).dy),
        reason: 'Monday before Tuesday');
    expect(find.ancestor(of: find.text('實驗報告'), matching: find.byType(TaskTile)), findsOneWidget);
    expect(find.text(zh.noTasks), findsOneWidget, reason: 'calculus has none, and still shows');
    expect(find.text('上週的報告'), findsNothing, reason: 'done ones are folded');

    await tester.tap(find.text(zh.completedTasksWithCount(1)));
    await tester.pumpAndSettle();
    expect(find.text('上週的報告'), findsOneWidget);
  });

  testWidgets('"+" on a course starts a task linked to it', (tester) async {
    final c = await pumpApp(tester);
    c.read(coursesProvider.notifier).add(
          semester: semester(c),
          title: '微積分',
          sessions: const [CourseSession(weekday: 1, startMinute: 550, endMinute: 670)],
        );
    c.read(taskViewProvider.notifier).state = kCourseTaskView;
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(zh.addTask).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, zh.titleField), '第三章習題');
    await tester.tap(find.widgetWithText(FilledButton, zh.add));
    await tester.pumpAndSettle();
    final task = c.read(tasksProvider).single;
    expect(task.courseId, c.read(coursesProvider).single.id);
    expect(task.dueTime, isNotNull, reason: 'due at the next class');
  });

  testWidgets('with no courses this semester, it says where to add them', (tester) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = kCourseTaskView;
    await tester.pumpAndSettle();
    expect(find.text(zh.courseViewEmpty), findsOneWidget);
  });
}
