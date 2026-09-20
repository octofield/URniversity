import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/overview_graph_screen.dart';
import 'package:urniversity/screens/task_history_screen.dart';

import '../helpers/pump_app.dart';

// The two pages redesigned on 2026-09-20 (canvas direction A): the completion
// history became a dashboard, and the graph stopped being something you pass
// through on the way to a detail page.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  group('completion history', () {
    testWidgets('shows the summary, the categories and what is overdue',
        (tester) async {
      final c = testContainer();
      final sem = currentSemester(c.read(semesterSettingsProvider));
      final goals = c.read(semesterGoalsProvider.notifier);
      final targetId = goals.addGoal('多益 850', sem, categories: const ['cert']);

      final now = DateTime.now();
      final tasks = c.read(tasksProvider.notifier);
      tasks.add('昨天就該做的', linkedTargetId: targetId,
          dueTime: now.subtract(const Duration(days: 3)));
      tasks.add('今天的', linkedTargetId: targetId,
          dueTime: DateTime(now.year, now.month, now.day, 23));

      await pumpScreen(tester, const TaskHistoryScreen(), container: c);
      await tester.pumpAndSettle();

      expect(find.text(zh.historyAverageLabel), findsOneWidget);
      expect(find.text(zh.historyStreak), findsOneWidget);
      expect(find.text(zh.historyByCategory), findsOneWidget);
      expect(find.text(zh.historyStale), findsOneWidget);
      // Three days late, and it is the only thing waiting
      expect(find.text(zh.historyOverdue(3)), findsOneWidget);
      expect(find.text('昨天就該做的'), findsOneWidget);
    });

    testWidgets('the last card clears the system navigation bar', (tester) async {
      // A three-button navigation bar covered the bottom card on Android
      tester.view.viewPadding = const FakeViewPadding(bottom: 96);
      addTearDown(tester.view.reset);

      await pumpScreen(tester, const TaskHistoryScreen());
      await tester.pumpAndSettle();

      final scroller = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first);
      expect(
        (scroller.padding as EdgeInsets).bottom,
        greaterThanOrEqualTo(96),
        reason: 'the inset has to be added to the page padding',
      );
    });

    testWidgets('an empty history says nothing is overdue', (tester) async {
      await pumpScreen(tester, const TaskHistoryScreen());
      await tester.pumpAndSettle();

      expect(find.text(zh.historyNothingStale), findsOneWidget);
      expect(find.text(zh.historyByCategory), findsNothing);
    });
  });

  group('overview graph', () {
    testWidgets('a tapped node opens its summary instead of leaving the page',
        (tester) async {
      final c = testContainer();
      c.read(futureGoalsProvider.notifier).addGoal(title: '出國交換一學期');
      final visionId = c.read(futureGoalsProvider).single.id;
      final sem = currentSemester(c.read(semesterSettingsProvider));
      final goals = c.read(semesterGoalsProvider.notifier);
      final targetId = goals.addGoal('交換學生申請', sem, categories: const ['exchange']);
      goals.linkFutureGoal(targetId, visionId);
      c.read(tasksProvider.notifier).add('書面審查', linkedTargetId: targetId);

      await pumpScreen(tester, const OverviewGraphScreen(),
          container: c, width: 900, settle: false);

      // The legend and the filters are there before anything is tapped
      expect(find.text(zh.graphLegend), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, zh.graphFilterUnfinished), findsOneWidget);
      expect(find.text(zh.graphNextDue), findsNothing);

      await tester.tap(find.text('交換學生申請'));
      await tester.pump(const Duration(milliseconds: 100));

      // Still on the graph, with the summary open under it
      expect(find.byType(OverviewGraphScreen), findsOneWidget);
      expect(find.text(zh.graphNextDue), findsOneWidget);
      expect(find.widgetWithText(FilledButton, zh.graphOpen), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, zh.graphViewTasks(1)), findsOneWidget);
    });

    testWidgets('the unlinked filter keeps only what hangs off nothing',
        (tester) async {
      final c = testContainer();
      c.read(futureGoalsProvider.notifier).addGoal(title: '出國交換一學期');
      final visionId = c.read(futureGoalsProvider).single.id;
      final sem = currentSemester(c.read(semesterSettingsProvider));
      final goals = c.read(semesterGoalsProvider.notifier);
      final linkedId = goals.addGoal('交換學生申請', sem);
      goals.linkFutureGoal(linkedId, visionId);
      goals.addGoal('還沒想好要連哪裡', sem);

      await pumpScreen(tester, const OverviewGraphScreen(),
          container: c, width: 900, settle: false);
      expect(find.text('交換學生申請'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, zh.unlinked));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('還沒想好要連哪裡'), findsOneWidget);
      expect(find.text('交換學生申請'), findsNothing);
      expect(find.text('出國交換一學期'), findsNothing);
    });
  });
}
