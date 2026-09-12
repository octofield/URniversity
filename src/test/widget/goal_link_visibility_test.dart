import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/screens/future_goal_detail_screen.dart';
import 'package:urniversity/screens/semester_goal_detail_screen.dart';

import '../helpers/pump_app.dart';

// Only top-level semester goals carry a future_goal_id (CLAUDE.md §9 rule 7).
// The rule shows up in three places and each used to disagree with the others.
// Retires cases 20-25 and 28 of docs/test-plans/2026-08-23-known-issues.md.
void main() {
  const zh = StringsZhTw();
  const semester = '114-1';

  setUp(() => setUpTestSupabase());

  // showSemesterGoalSheet needs a context under a Scaffold and a ref, so it is
  // opened the way the real screens open it rather than called directly
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

  SemesterGoal seedGoal(ProviderContainer c, {String? parentId}) {
    c.read(semesterGoalsProvider.notifier).addGoal(
          parentId == null ? '頂層目標' : '子目標',
          semester,
          parentId: parentId,
        );
    return c.read(semesterGoalsProvider).last;
  }

  group('the sheet shows the vision link only for top-level goals', () {
    testWidgets('adding a top-level goal', (tester) async {
      final c = testContainer();
      await openSheet(tester, c, (ctx, ref) => showSemesterGoalSheet(ctx, ref));
      expect(find.text(zh.linkedFutureGoal), findsOneWidget);
    });

    testWidgets('adding a milestone', (tester) async {
      final c = testContainer();
      final parent = seedGoal(c);
      await openSheet(tester, c,
          (ctx, ref) => showSemesterGoalSheet(ctx, ref, parentId: parent.id));
      expect(find.text(zh.linkedFutureGoal), findsNothing);
    });

    testWidgets('editing a top-level goal also gets the semester dropdown',
        (tester) async {
      final c = testContainer();
      final goal = seedGoal(c);
      await openSheet(tester, c,
          (ctx, ref) => showSemesterGoalSheet(ctx, ref, existing: goal));
      expect(find.text(zh.linkedFutureGoal), findsOneWidget);
      expect(find.text(zh.semester), findsOneWidget);
    });

    testWidgets('editing a milestone gets neither', (tester) async {
      final c = testContainer();
      final parent = seedGoal(c);
      final child = seedGoal(c, parentId: parent.id);
      await openSheet(tester, c,
          (ctx, ref) => showSemesterGoalSheet(ctx, ref, existing: child));
      expect(find.text(zh.linkedFutureGoal), findsNothing);
      expect(find.text(zh.semester), findsNothing);
    });
  });

  group('the detail screen shows the vision section only for top-level goals',
      () {
    testWidgets('top-level goal', (tester) async {
      final c = testContainer();
      final goal = seedGoal(c);
      await pumpScreen(tester, SemesterGoalDetailScreen(goalId: goal.id),
          container: c);
      expect(find.text(zh.linkedFutureGoal), findsOneWidget);
    });

    testWidgets('milestone', (tester) async {
      final c = testContainer();
      final parent = seedGoal(c);
      final child = seedGoal(c, parentId: parent.id);
      await pumpScreen(tester, SemesterGoalDetailScreen(goalId: child.id),
          container: c);
      expect(find.text(zh.linkedFutureGoal), findsNothing);
    });
  });

  testWidgets('the vision detail screen only offers top-level goals to link',
      (tester) async {
    final c = testContainer();
    c.read(futureGoalsProvider.notifier).addGoal(title: '願景');
    final vision = c.read(futureGoalsProvider).first;
    final parent = seedGoal(c);
    seedGoal(c, parentId: parent.id);

    await pumpScreen(tester, FutureGoalDetailScreen(goalId: vision.id),
        container: c);
    await tester.tap(find.text(zh.addLinkedTarget));
    await tester.pumpAndSettle();

    expect(find.text('頂層目標'), findsOneWidget);
    expect(find.text('子目標'), findsNothing);
  });
}
