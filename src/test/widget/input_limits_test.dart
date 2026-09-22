import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/input_limits.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/semester_goal_detail_screen.dart';
import 'package:urniversity/screens/today_screen.dart';
import 'package:urniversity/widgets/sheet_fields.dart';

import '../helpers/pump_app.dart';

// 2026-09 batch 11: titles show in full instead of stopping at two lines, every
// field the user types into has a cap (core/input_limits.dart), and a new
// milestone starts with its parent's categories.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

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

  Finder sheetField(String label) => find.descendant(
        of: find.widgetWithText(SheetTextField, label),
        matching: find.byType(EditableText),
      );

  testWidgets('a task title stops at the cap', (tester) async {
    final c = testContainer();
    await pumpScreen(tester, sheetHost((ctx, ref) => showTaskSheet(ctx, ref)),
        container: c);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(sheetField(zh.titleField), 'x' * 150);
    await tester.pump();

    final field = tester.widget<EditableText>(sheetField(zh.titleField));
    expect(field.controller.text.length, InputLimits.title);
    // Near the cap the counter appears, explaining why typing stopped
    expect(find.text('${InputLimits.title}/${InputLimits.title}'), findsOneWidget);
  });

  testWidgets('the counter stays hidden well below the cap', (tester) async {
    final c = testContainer();
    await pumpScreen(tester, sheetHost((ctx, ref) => showTaskSheet(ctx, ref)),
        container: c);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(sheetField(zh.titleField), '短標題');
    await tester.pump();

    expect(find.text('3/${InputLimits.title}'), findsNothing);
  });

  testWidgets('a long task title shows in full', (tester) async {
    final c = await pumpApp(tester);
    final long = '很長的任務標題' * 10;
    c.read(tasksProvider.notifier).add(long);
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text(long));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('a new milestone starts with its parent categories',
      (tester) async {
    final c = testContainer();
    final parentId = c.read(semesterGoalsProvider.notifier).addGoal(
          '父目標',
          '114-1',
          categories: const [FutureCategories.exchange],
        );
    await pumpScreen(
      tester,
      sheetHost(
          (ctx, ref) => showSemesterGoalSheet(ctx, ref, parentId: parentId)),
      container: c,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(sheetField(zh.titleField), '子目標');
    await tester.tap(find.widgetWithText(FilledButton, zh.add));
    await tester.pumpAndSettle();

    final child =
        c.read(semesterGoalsProvider).firstWhere((g) => g.parentId == parentId);
    expect(child.categories, [FutureCategories.exchange]);
  });
}
