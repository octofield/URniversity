import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/theme/app_colors.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/today_screen.dart' show showTaskSheet;

import '../helpers/pump_app.dart';

// A repeating task's due time is the time of each occurrence (2026-10-04):
// "⟳ 每週四 07:00", no date, no due colour; days left unpicked come from the
// date the task was given
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  group('anchoredTo', () {
    // 2026-10-08 is a Thursday
    final thursday = DateTime(2026, 10, 8, 7);

    test('weekly with no day picked takes the date\'s weekday', () {
      const weekly = RecurrenceRule(type: RecurrenceType.weekly);
      expect(weekly.anchoredTo(thursday).weekdays, [DateTime.thursday]);
    });

    test('monthly with no day picked takes the date\'s day of month', () {
      const monthly = RecurrenceRule(type: RecurrenceType.monthly);
      expect(monthly.anchoredTo(thursday).monthDays, [8]);
    });

    test('days already picked, other types, or no date: unchanged', () {
      const picked = RecurrenceRule(type: RecurrenceType.weekly, weekdays: [1, 3]);
      expect(picked.anchoredTo(thursday).weekdays, [1, 3]);
      const daily = RecurrenceRule(type: RecurrenceType.daily);
      expect(identical(daily.anchoredTo(thursday), daily), isTrue);
      const weekly = RecurrenceRule(type: RecurrenceType.weekly);
      expect(weekly.anchoredTo(null).weekdays, isEmpty);
    });
  });

  // The row shows the occurrence it is about and the rule (2026-10-22):
  // "⏰ 10/23（四）07:00 · ⟳ 每週四", the time coloured as a one-off's would be
  String occurrence(DateTime day, [String? time]) {
    final date = zh.dateWithWeekday(
      '${day.month.toString().padLeft(2, '0')}/${day.day.toString().padLeft(2, '0')}',
      zh.weekdayShort(day.weekday),
    );
    return time == null ? date : '$date $time';
  }

  Color? colourOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('the day view shows that day\'s time and the rule, not the stored date', (tester) async {
    final c = await pumpApp(tester, width: 360);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    c.read(tasksProvider.notifier).add('晨跑',
        dueTime: DateTime(2026, 1, 1, 23, 59),
        recurrence: RecurrenceRule(type: RecurrenceType.weekly, weekdays: [today.weekday]));
    c.read(taskViewProvider.notifier).state = 1;
    await tester.pumpAndSettle();

    expect(find.text(occurrence(day, '23:59')), findsOneWidget);
    expect(find.text(zh.repeatWeeklyOn(zh.weekdayShort(today.weekday))), findsOneWidget);
    expect(find.textContaining('01/01'), findsNothing);
    expect(find.byTooltip(zh.postponeOneDay), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an occurrence two days gone is red; one with no time is plain', (tester) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = 0;
    final now = DateTime.now();
    final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
    // Weekly on that day: in the all-tasks view its current occurrence is then
    final weekly = RecurrenceRule(type: RecurrenceType.weekly, weekdays: [twoDaysAgo.weekday]);
    // Set up long ago, so the rule has come round before today
    c.read(tasksProvider.notifier).state = [
      Task(id: 'run', title: '晨跑', createdAt: DateTime(2026, 1, 1), dueTime: DateTime(2026, 1, 1, 7), recurrence: weekly),
      Task(id: 'stretch', title: '伸展', createdAt: DateTime(2026, 1, 1), recurrence: weekly),
    ];
    await tester.pumpAndSettle();

    expect(colourOf(tester, occurrence(twoDaysAgo, '07:00')), AppColors.error);
    // No time of day: its date alone, no clock, no colour
    expect(colourOf(tester, occurrence(twoDaysAgo)), AppColors.textSecondary);
    expect(find.byIcon(Icons.access_time), findsOneWidget, reason: 'only the timed one has a clock');
  });

  testWidgets('once that occurrence is done, it is no longer coloured', (tester) async {
    final c = await pumpApp(tester);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    c.read(tasksProvider.notifier).add('晨跑',
        dueTime: DateTime(2026, 1, 1, 0, 1),
        recurrence: const RecurrenceRule(type: RecurrenceType.daily));
    c.read(taskViewProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    expect(colourOf(tester, occurrence(day, '00:01')), AppColors.warning, reason: 'just gone: orange');

    c.read(tasksProvider.notifier).toggleOnDate(c.read(tasksProvider).single.id, day);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(zh.completedTasks));
    await tester.pumpAndSettle();
    expect(colourOf(tester, occurrence(day, '00:01')), AppColors.textSecondary);
  });

  testWidgets('in the sheet: a time, not a date, and no "minutes from now"', (tester) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = 0;
    c.read(tasksProvider.notifier).add('晨跑',
        dueTime: DateTime(2026, 10, 8, 7),
        recurrence: const RecurrenceRule(type: RecurrenceType.daily));
    await tester.pumpAndSettle();
    await tester.tap(find.text('晨跑'));
    await tester.pumpAndSettle();

    expect(find.text('07:00'), findsOneWidget);
    expect(find.textContaining('10/08'), findsNothing);
    expect(find.text(zh.minutesLater(5)), findsNothing);
  });

  testWidgets('a new task due Thursday 7:00, set weekly, repeats on Thursdays', (tester) async {
    final c = testContainer();
    await pumpScreen(
      tester,
      Consumer(builder: (context, ref, _) => Scaffold(
        body: TextButton(
          onPressed: () => showTaskSheet(context, ref, due: DateTime(2026, 10, 8, 7)),
          child: const Text('open'),
        ),
      )),
      container: c,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, zh.titleField), '晨跑');
    await tester.tap(find.text(zh.repeatNone));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, zh.repeatWeekly));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, MaterialLocalizations.of(tester.element(find.byType(AlertDialog))).okButtonLabel));
    await tester.pumpAndSettle();
    // The sheet already says which day it will be, and the time alone
    expect(find.text(zh.repeatWeeklyOn(zh.weekdayShort(DateTime.thursday))), findsOneWidget);
    expect(find.text('07:00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, zh.add));
    await tester.pumpAndSettle();
    expect(c.read(tasksProvider).single.recurrence!.weekdays, [DateTime.thursday]);
  });

  testWidgets('saving a task whose rule and time were left alone keeps its rule', (tester) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = 0;
    // From before this change: weekly with no day picked, a date on another
    // weekday than its creation. Renaming it must not move it
    final created = DateTime.now();
    final otherDay = created.add(const Duration(days: 2));
    c.read(tasksProvider.notifier).add('週會',
        dueTime: otherDay, recurrence: const RecurrenceRule(type: RecurrenceType.weekly));
    await tester.pumpAndSettle();
    await tester.tap(find.text('週會'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '週會'), '週會（改名）');
    await tester.tap(find.widgetWithText(FilledButton, zh.save));
    await tester.pumpAndSettle();

    final task = c.read(tasksProvider).single;
    expect(task.title, '週會（改名）');
    expect(task.recurrence!.weekdays, isEmpty);
  });
}
