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
    await tester.tap(find.byTooltip(zh.postponeOneDay));
    await tester.pumpAndSettle();

    final report = c.read(tasksProvider).firstWhere((t) => t.title == '交報告');
    expect(report.dueTime, DateTime(now.year, now.month, now.day + 1, 14, 30));
    expect(find.byTooltip(zh.postponeOneDay), findsNothing, reason: 'no longer overdue');
  });
}
