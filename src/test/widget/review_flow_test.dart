import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/review.dart';
import 'package:urniversity/providers/reviews_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/review_screen.dart';
import 'package:urniversity/screens/reviews_screen.dart';
import 'package:urniversity/screens/settings_screen.dart';

import '../helpers/pump_app.dart';

// The guided review end to end (UC19): the card on the task page, the three
// steps, what gets stored, and what it leaves behind — tasks moved on, and the
// targets picked showing as "this week's focus".
void main() {
  const zh = StringsZhTw();
  // Sunday 27 Sep 2026, 20:00 — the week of 21–27 Sep is up for review
  final sundayEvening = DateTime(2026, 9, 27, 20);

  setUp(() => setUpTestSupabase());

  Future<ProviderContainer> pumpAt(WidgetTester tester, DateTime now) {
    final scope = testContainer(overrides: [reviewNowProvider.overrideWithValue(now)]);
    return pumpApp(tester, container: scope);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('Sunday evening puts the weekly review on the task page', (tester) async {
    await pumpAt(tester, sundayEvening);

    expect(find.text(zh.reviewWeekTitle), findsOneWidget);
    expect(find.text(zh.reviewStart), findsOneWidget);
  });

  testWidgets('a Wednesday has no review card', (tester) async {
    await pumpAt(tester, DateTime(2026, 9, 30, 20));

    expect(find.text(zh.reviewStart), findsNothing);
  });

  testWidgets('three steps, then the review is stored and the card goes', (tester) async {
    final scope = await pumpAt(tester, sundayEvening);

    await tapAndSettle(tester, find.text(zh.reviewStart));
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(find.text(zh.reviewHeatmapTitle), findsOneWidget);

    await tapAndSettle(tester, find.text(zh.reviewNext));
    await tester.enterText(
      find.descendant(of: find.widgetWithText(Column, zh.reviewWentWell).first, matching: find.byType(TextField)).first,
      '把多益模考寫完',
    );
    await tapAndSettle(tester, find.text(zh.reviewNext));
    await tapAndSettle(tester, find.text(zh.reviewFinish));

    final stored = scope.read(reviewsProvider);
    expect(stored.single.period, ReviewPeriod.week);
    expect(stored.single.periodStart, DateTime(2026, 9, 21));
    expect(stored.single.wentWell, '把多益模考寫完');
    expect(find.byType(ReviewScreen), findsNothing);
    expect(find.text(zh.reviewSaved), findsOneWidget);
    expect(find.text(zh.reviewStart), findsNothing);
  });

  testWidgets('open tasks due that week can be pushed back a week', (tester) async {
    final scope = await pumpAt(tester, sundayEvening);
    scope.read(tasksProvider.notifier).add('交報告', dueTime: DateTime(2026, 9, 24, 14));
    scope.read(tasksProvider.notifier).add('已完成', dueTime: DateTime(2026, 9, 25, 9));
    final doneId = scope.read(tasksProvider).firstWhere((t) => t.title == '已完成').id;
    scope.read(tasksProvider.notifier).toggleOnDate(doneId, DateTime(2026, 9, 25));
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text(zh.reviewStart));
    await tapAndSettle(tester, find.text(zh.reviewNext));
    await tapAndSettle(tester, find.text(zh.reviewNext));

    expect(find.text('交報告'), findsOneWidget);
    expect(find.text('已完成'), findsNothing);
    await tapAndSettle(tester, find.text(zh.reviewCarryAction(1)));

    final moved = scope.read(tasksProvider).firstWhere((t) => t.title == '交報告');
    expect(moved.dueTime, DateTime(2026, 10, 1, 14));
    expect(find.text(zh.reviewCarryDone(1)), findsOneWidget);
  });

  testWidgets('targets picked for focus show on the task page and filter it', (tester) async {
    final scope = await pumpAt(tester, sundayEvening);
    final id = scope.read(semesterGoalsProvider.notifier).addGoal('多益 800', '115-1');
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text(zh.reviewStart));
    await tapAndSettle(tester, find.text(zh.reviewNext));
    await tapAndSettle(tester, find.text(zh.reviewNext));
    await tapAndSettle(tester, find.widgetWithText(FilterChip, '多益 800'));
    await tapAndSettle(tester, find.text(zh.reviewFinish));

    expect(find.text(zh.reviewFocusThisWeek), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(FilterChip, '多益 800'));
    expect(scope.read(taskTargetFilterProvider), {id});
  });

  testWidgets('focus is capped at three targets', (tester) async {
    final scope = await pumpAt(tester, sundayEvening);
    for (final title in ['A', 'B', 'C', 'D']) {
      scope.read(semesterGoalsProvider.notifier).addGoal(title, '115-1');
    }
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text(zh.reviewStart));
    await tapAndSettle(tester, find.text(zh.reviewNext));
    await tapAndSettle(tester, find.text(zh.reviewNext));
    for (final title in ['A', 'B', 'C', 'D']) {
      await tester.tap(find.widgetWithText(FilterChip, title), warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await tapAndSettle(tester, find.text(zh.reviewFinish));

    final stored = scope.read(reviewsProvider).single;
    expect(stored.focusTargetIds, hasLength(3));
  });

  testWidgets('doing the same week again updates it rather than adding one', (tester) async {
    final scope = await pumpAt(tester, sundayEvening);
    final notifier = scope.read(reviewsProvider.notifier);
    Review week(String text) => Review(
          id: text,
          period: ReviewPeriod.week,
          periodStart: DateTime(2026, 9, 21),
          periodEnd: DateTime(2026, 9, 27),
          wentWell: text,
          stats: const ReviewStats(done: 0, total: 0, streak: 0, journals: 0),
          createdAt: sundayEvening,
        );

    notifier.save(week('first'));
    notifier.save(week('second'));

    final stored = scope.read(reviewsProvider);
    expect(stored, hasLength(1));
    expect(stored.single.wentWell, 'second');
    expect(stored.single.id, 'first');
  });

  testWidgets('developer mode opens a review that is not due', (tester) async {
    final wednesday = DateTime(2026, 9, 30, 10);
    final scope = testContainer(overrides: [reviewNowProvider.overrideWithValue(wednesday)]);
    scope.read(devModeProvider.notifier).enable();
    await pumpScreen(tester, const SettingsScreen(), container: scope);

    await tester.scrollUntilVisible(find.text(zh.devOpenReview), 200);
    await tapAndSettle(tester, find.text(zh.devOpenReview));
    await tapAndSettle(tester, find.text(zh.reviewWeekTitle));

    final screen = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
    expect(screen.window.start, DateTime(2026, 9, 28));
    expect(screen.window.end, DateTime(2026, 10, 4));
  });

  testWidgets('past reviews are listed and can be deleted', (tester) async {
    final scope = await pumpAt(tester, sundayEvening);
    scope.read(reviewsProvider.notifier).save(Review(
          id: 'r1',
          period: ReviewPeriod.week,
          periodStart: DateTime(2026, 9, 14),
          periodEnd: DateTime(2026, 9, 20),
          nextFocus: '寫完第三章',
          stats: const ReviewStats(done: 3, total: 4, rate: 0.75, streak: 1, journals: 0),
          createdAt: DateTime(2026, 9, 20, 21),
        ));

    await pumpScreen(tester, const ReviewsScreen(), container: scope);
    await tapAndSettle(tester, find.text(zh.reviewWeekTitle));
    expect(find.text('寫完第三章'), findsOneWidget);

    await tapAndSettle(tester, find.byIcon(Icons.delete_outline));
    await tapAndSettle(tester, find.text(zh.delete));
    expect(scope.read(reviewsProvider), isEmpty);
  });
}
