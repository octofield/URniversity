import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import '../helpers/pump_app.dart';

// "Postpone a day" left of delete on an overdue task (2026-10-03)
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  testWidgets('an overdue task moves to tomorrow at its own time', (tester) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = 0;
    final now = DateTime.now();
    c.read(tasksProvider.notifier)
      ..add('交報告', dueTime: DateTime(now.year, now.month, now.day - 3, 14, 30))
      ..add('還沒到', dueTime: now.add(const Duration(days: 2)))
      ..add('每週運動', dueTime: DateTime(now.year, now.month, now.day - 3, 7),
          recurrence: const RecurrenceRule(type: RecurrenceType.weekly));
    await tester.pumpAndSettle();

    // Only the one-off, overdue task offers it
    expect(find.byTooltip(zh.postponeOneDay), findsOneWidget);
    final overdue = DateTime(now.year, now.month, now.day - 3, 14, 30);
    Task report() => c.read(tasksProvider).firstWhere((t) => t.title == '交報告');

    // Asked first: cancelling leaves it where it was (2026-10-04)
    await tester.tap(find.byTooltip(zh.postponeOneDay));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, MaterialLocalizations.of(tester.element(find.byType(AlertDialog))).cancelButtonLabel));
    await tester.pumpAndSettle();
    expect(report().dueTime, overdue);

    await tester.tap(find.byTooltip(zh.postponeOneDay));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, zh.postponeOneDay));
    await tester.pumpAndSettle();
    expect(report().dueTime, DateTime(now.year, now.month, now.day + 1, 14, 30));
    expect(find.byTooltip(zh.postponeOneDay), findsNothing, reason: 'no longer overdue');
  });
}
