import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/inspirations_provider.dart';
import 'package:urniversity/providers/recent_picks_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/today_screen.dart';

import 'package:urniversity/widgets/sheet_fields.dart';

import '../helpers/pump_app.dart';

// today_screen.dart was split into three part files; showTaskSheet and
// showAddInspirationSheet are the cross-file exports the split could have
// broken. Retires cases 30, 31, 33, 34 and 35 of
// docs/test-plans/2026-08-23-known-issues.md. Case 32 (drag to reorder and to
// nest) stays manual — the drop zones need real pointer geometry.
// The sheets label their fields above the box now (SheetTextField), so the
// label is a sibling of the TextField rather than its decoration
Finder sheetField(String label) => find.descendant(
      of: find.widgetWithText(SheetTextField, label),
      matching: find.byType(TextField),
    );

void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  // The sheets are opened from a plain Scaffold rather than from TodayScreen,
  // which has no Scaffold of its own and reaches for Scaffold.of(context)
  Widget sheetHost(void Function(BuildContext, WidgetRef) open) => Consumer(
        builder: (ctx, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => open(ctx, ref),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Future<void> openSheet(
    WidgetTester tester,
    ProviderContainer c,
    void Function(BuildContext, WidgetRef) open,
  ) async {
    await pumpScreen(tester, sheetHost(open), container: c);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('task sheet', () {
    testWidgets('adds a task', (tester) async {
      final c = testContainer();
      await openSheet(tester, c, (ctx, ref) => showTaskSheet(ctx, ref));

      await tester.enterText(
          sheetField(zh.titleField), '寫測試');
      await tester.enterText(
          sheetField(zh.taskNotes), '備註');
      await tester.tap(find.widgetWithText(FilledButton, zh.add));
      await tester.pumpAndSettle();

      final tasks = c.read(tasksProvider);
      expect(tasks, hasLength(1));
      expect(tasks.single.title, '寫測試');
      expect(tasks.single.content, '備註');
    });

    testWidgets('ignores an empty title', (tester) async {
      final c = testContainer();
      await openSheet(tester, c, (ctx, ref) => showTaskSheet(ctx, ref));
      await tester.tap(find.widgetWithText(FilledButton, zh.add));
      await tester.pumpAndSettle();
      expect(c.read(tasksProvider), isEmpty);
    });

    testWidgets('edits a task and clears its notes', (tester) async {
      final c = testContainer();
      c.read(tasksProvider.notifier).add('原標題', content: '原備註');
      final task = c.read(tasksProvider).single;

      await openSheet(
          tester, c, (ctx, ref) => showTaskSheet(ctx, ref, existing: task));
      expect(find.text(zh.editTask), findsOneWidget);

      await tester.enterText(
          sheetField(zh.titleField), '新標題');
      await tester.enterText(
          sheetField(zh.taskNotes), '');
      await tester.tap(find.widgetWithText(FilledButton, zh.save));
      await tester.pumpAndSettle();

      final updated = c.read(tasksProvider).single;
      expect(updated.title, '新標題');
      expect(updated.content, isNull);
    });

    // A task links to a target and the target to a vision; priority was cut
    // for the same reason — one more field nobody filled in
    testWidgets('offers neither a vision link nor a priority', (tester) async {
      final c = testContainer();
      await openSheet(tester, c, (ctx, ref) => showTaskSheet(ctx, ref));

      expect(find.text(zh.linkedTarget), findsOneWidget);
      expect(find.text(zh.linkedGoal), findsNothing);
      expect(find.byType(SegmentedButton<int>), findsNothing);
    });

    // "In five minutes" is what a task being written down right now usually
    // means; the remembered clock times come after it
    testWidgets('offers the relative times before the remembered ones',
        (tester) async {
      final c = testContainer();
      await c.read(recentPicksProvider.notifier).rememberTime(
            DateTime(2026, 9, 20, 23, 59),
          );

      await openSheet(tester, c, (ctx, ref) => showTaskSheet(ctx, ref));

      final relative = tester.getRect(find.text(zh.minutesLater(5)));
      expect(find.text(zh.minutesLater(30)), findsOneWidget);
      expect(find.text(zh.hoursLater(1)), findsOneWidget);
      // Earlier in reading order: the chips wrap, so it can be the row above
      final remembered = tester.getRect(find.text('23:59'));
      expect(
        relative.top < remembered.top ||
            (relative.top == remembered.top && relative.left < remembered.left),
        isTrue,
        reason: 'the relative chips come first',
      );

      // Tapping it lands five minutes from now, not at some remembered clock
      final before = DateTime.now();
      await tester.tap(find.text(zh.minutesLater(5)));
      await tester.pumpAndSettle();
      await tester.enterText(sheetField(zh.titleField), '五分鐘後的事');
      await tester.tap(find.widgetWithText(FilledButton, zh.add));
      await tester.pumpAndSettle();

      final due = c.read(tasksProvider).single.dueTime!;
      expect(due.difference(before).inMinutes, inInclusiveRange(4, 6));
    });

    testWidgets('links a target through the semester picker', (tester) async {
      final c = testContainer();
      final goals = c.read(semesterGoalsProvider.notifier);
      goals.addGoal('舊目標', '100-1');
      goals.addGoal('本學期目標', currentSemester(c.read(semesterSettingsProvider)));

      await openSheet(tester, c, (ctx, ref) => showTaskSheet(ctx, ref));
      await tester.tap(find.text(zh.linkedTarget));
      await tester.pumpAndSettle();

      // Every semester is listed until one is picked from the chip row
      expect(find.widgetWithText(ChoiceChip, zh.catAll), findsOneWidget);
      expect(find.text('本學期目標'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, '100-1'));
      await tester.pumpAndSettle();
      expect(find.text('本學期目標'), findsNothing);

      await tester.tap(find.text('舊目標'));
      await tester.pumpAndSettle();
      await tester.enterText(
          sheetField(zh.titleField), '連結的任務');
      await tester.tap(find.widgetWithText(FilledButton, zh.add));
      await tester.pumpAndSettle();

      final old = c.read(semesterGoalsProvider).firstWhere((g) => g.title == '舊目標');
      expect(c.read(tasksProvider).single.linkedTargetId, old.id);
    });
  });

  testWidgets('inspiration sheet adds an inspiration', (tester) async {
    final c = testContainer();
    await openSheet(tester, c, (ctx, ref) => showAddInspirationSheet(ctx, ref));

    await tester.enterText(
        sheetField(zh.titleField), '一個點子');
    await tester.tap(find.widgetWithText(FilledButton, zh.add));
    await tester.pumpAndSettle();

    expect(c.read(inspirationsProvider).single.title, '一個點子');
  });

  group('today screen', () {
    testWidgets('switches between the three task views', (tester) async {
      await pumpApp(tester);

      for (final label in [zh.weeklyTasks, zh.dailyTasks, zh.allTasks]) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows and clears the filter banner', (tester) async {
      final c = await pumpApp(tester);
      expect(find.textContaining(zh.filters), findsNothing);

      c.read(semesterGoalsProvider.notifier).addGoal('目標', '114-1');
      c.read(taskTargetFilterProvider.notifier).state = {
        c.read(semesterGoalsProvider).single.id,
      };
      await tester.pumpAndSettle();
      expect(find.textContaining(zh.filters), findsOneWidget);

      // The banner's own clear button; the only tappable close icon on screen
      await tester.tap(find.widgetWithIcon(GestureDetector, Icons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining(zh.filters), findsNothing);
    });

    testWidgets('weekly view lists a task under its day and ticks it off', (tester) async {
      final c = await pumpApp(tester);
      c.read(taskViewProvider.notifier).state = 2;
      final now = DateTime.now();
      c.read(tasksProvider.notifier).add(
            '本週的事',
            dueTime: DateTime(now.year, now.month, now.day, 23, 0),
          );
      await tester.pumpAndSettle();

      // Today's date sits in the left column, and every day of the week has a row
      expect(find.text('${now.month}/${now.day}'), findsOneWidget);
      expect(find.text('本週的事'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(c.read(tasksProvider).single.isCompletedOn(now), isTrue);
    });

    testWidgets('lists completed tasks in their own section', (tester) async {
      final c = await pumpApp(tester);
      // The daily view only lists tasks that apply to the date, and a task with
      // no due time and no recurrence applies to none
      c.read(taskViewProvider.notifier).state = 0;
      c.read(tasksProvider.notifier).add('做完的事');
      await tester.pumpAndSettle();
      expect(find.textContaining(zh.completedTasks), findsNothing);
      expect(find.text(zh.tasksWithCount(1)), findsOneWidget);

      c.read(tasksProvider.notifier).toggle(c.read(tasksProvider).single.id);
      await tester.pumpAndSettle();
      // Both headers count the rows they list
      expect(find.text(zh.completedTasksWithCount(1)), findsOneWidget);
      expect(find.text(zh.tasksWithCount(0)), findsOneWidget);

      // Collapsed to begin with: the header is there, the finished task is not
      expect(find.text('做完的事'), findsNothing);
      await tester.tap(find.text(zh.completedTasksWithCount(1)));
      await tester.pumpAndSettle();
      expect(find.text('做完的事'), findsOneWidget);
    });
  });

  testWidgets('HomeScreen still hosts TodayScreen after the split',
      (tester) async {
    await pumpApp(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
  });
}
