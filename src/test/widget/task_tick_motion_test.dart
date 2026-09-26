import 'dart:ui' show AccessibilityFeatures;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/theme/app_motion.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/widgets/animated_strike.dart';

import '../helpers/pump_app.dart';

// The tick, end to end (system_design.md §3-Q): the row is struck through,
// stays long enough for that to be seen, then folds away and turns up in the
// completed section. Unticking walks it back
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  Future<void> addTask(WidgetTester tester, String title) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = 0;
    c.read(tasksProvider.notifier).add(title);
    await tester.pumpAndSettle();
  }

  testWidgets('a ticked row is struck through and held before it leaves', (tester) async {
    await addTask(tester, '交報告');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('交報告'), findsOneWidget, reason: 'still on screen');
    final strike = tester.widget<AnimatedStrikeText>(find.byType(AnimatedStrikeText));
    expect(strike.struck, isTrue);
    final painter = tester
        .widget<CustomPaint>(find.descendant(
          of: find.byType(AnimatedStrikeText),
          matching: find.byType(CustomPaint),
        ))
        .foregroundPainter;
    expect(painter, isNotNull, reason: 'the line is being drawn');

    // Near the end of the hold — past the time a fold alone would take — the
    // row is still there at full height
    await tester.pump(AppMotion.hold - const Duration(milliseconds: 130));
    final row = find.ancestor(of: find.text('交報告'), matching: find.byType(SizeTransition)).first;
    expect(tester.widget<SizeTransition>(row).sizeFactor.value, 1, reason: 'held, not yet folding');

    await tester.pumpAndSettle();
    // Gone from the open list (the completed section starts collapsed), and
    // the list says so
    expect(find.text('交報告'), findsNothing);
    expect(find.text(zh.tasksWithCount(0)), findsOneWidget);
    expect(find.text(zh.completedTasksWithCount(1)), findsOneWidget);
    expect(find.text(zh.noTasks), findsOneWidget);
  });

  testWidgets('the empty state waits for the last row to leave', (tester) async {
    await addTask(tester, '最後一件');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(AppMotion.hold ~/ 2);
    expect(find.text('最後一件'), findsOneWidget);
    // In the list already, but folded shut while the row is still held
    final empty = find.byKey(const ValueKey('_empty')).first;
    expect(tester.getSize(empty).height, 0);

    await tester.pumpAndSettle();
    expect(tester.getSize(empty).height, greaterThan(0));
    expect(find.text('最後一件'), findsNothing);
  });

  testWidgets('unticking from the completed section brings it back', (tester) async {
    await addTask(tester, '改天再做');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.tap(find.text(zh.completedTasksWithCount(1)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text(zh.tasksWithCount(1)), findsOneWidget);
    expect(find.text('改天再做'), findsOneWidget);
    expect(find.textContaining(zh.completedTasks), findsNothing);
  });

  testWidgets('with the system asking for no motion the row goes at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const _NoMotion();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await addTask(tester, '馬上消失');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump();
    expect(find.text('馬上消失'), findsNothing);
  });
}

class _NoMotion implements AccessibilityFeatures {
  const _NoMotion();

  @override
  bool get disableAnimations => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
