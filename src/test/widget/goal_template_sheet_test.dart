import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/goal_templates.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/screens/future_screen.dart';
import 'package:urniversity/screens/semester_screen.dart';

import '../helpers/pump_app.dart';

// The entry point has to survive too: the header icon is the only way in, and
// a template that creates rows the user cannot then edit would be worse than
// no template at all
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  testWidgets('the header icon opens the sheet and lists every template',
      (tester) async {
    await pumpScreen(tester, const Scaffold(body: SemesterScreen()), width: 420);

    await tester.tap(find.byTooltip(zh.goalTemplates));
    await tester.pumpAndSettle();

    for (final template in kGoalTemplates) {
      expect(find.text(template.name(zh)), findsOneWidget);
    }
    expect(find.text(zh.applyTemplate), findsNWidgets(kGoalTemplates.length));
  });

  testWidgets('applying writes the goals and reports how many', (tester) async {
    final scope = await pumpScreen(
        tester, const Scaffold(body: SemesterScreen()), width: 420);
    final template = kGoalTemplates.first;

    await tester.tap(find.byTooltip(zh.goalTemplates));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.applyTemplate).first);
    await tester.pumpAndSettle();

    expect(scope.read(semesterGoalsProvider).length, template.goalCount);
    expect(scope.read(tasksProvider).length, template.taskCount);
    expect(
      find.text(zh.templateApplied(template.goalCount, template.taskCount)),
      findsOneWidget,
    );
    // The sheet closed behind the snack bar
    expect(find.text(zh.goalTemplates), findsNothing);
  });

  testWidgets('an applied goal is ordinary data the user can delete',
      (tester) async {
    final scope = await pumpScreen(
        tester, const Scaffold(body: SemesterScreen()), width: 420);
    final template = kGoalTemplates.first;

    await tester.tap(find.byTooltip(zh.goalTemplates));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.applyTemplate).first);
    await tester.pumpAndSettle();

    final first = scope.read(semesterGoalsProvider).first;
    scope.read(semesterGoalsProvider.notifier).remove(first.id);
    await tester.pumpAndSettle();

    expect(
      scope.read(semesterGoalsProvider).any((g) => g.id == first.id),
      isFalse,
    );
    expect(find.text(template.goals.first.title(zh)), findsNothing);
  });

  testWidgets('the vision page opens the same sheet and the vision shows there',
      (tester) async {
    final scope = await pumpScreen(
        tester, const Scaffold(body: FutureScreen()), width: 420);
    final template = kGoalTemplates.first;

    await tester.tap(find.byTooltip(zh.goalTemplates));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.applyTemplate).first);
    await tester.pumpAndSettle();

    expect(scope.read(futureGoalsProvider).single.title, template.vision.title(zh));
    expect(find.text(template.vision.title(zh)), findsOneWidget);
  });
}
