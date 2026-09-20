import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import '../helpers/pump_app.dart';

// The sort button next to the filter one, and what picking a sort does to the
// list — including switching dragging off, since a drag would write an order
// the list is not showing.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  testWidgets('picking A-Z reorders the list and stops the dragging',
      (tester) async {
    final c = await pumpApp(tester);
    final tasks = c.read(tasksProvider.notifier);
    tasks.add('乙 second');
    tasks.add('甲 first');
    await tester.pumpAndSettle();

    // Newest first while the order is manual
    expect(
      tester.getRect(find.text('甲 first')).top,
      lessThan(tester.getRect(find.text('乙 second')).top),
    );
    expect(find.byType(LongPressDraggable<String>), findsNWidgets(2));

    await tester.tap(find.byTooltip(zh.sortBy));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.sortTitle));
    await tester.pumpAndSettle();

    expect(c.read(taskSortProvider), TaskSort.title);
    expect(
      tester.getRect(find.text('乙 second')).top,
      lessThan(tester.getRect(find.text('甲 first')).top),
      reason: '乙 sorts before 甲 by code unit',
    );
    expect(find.byType(LongPressDraggable<String>), findsNothing,
        reason: 'dragging is off outside the manual order');
  });

  testWidgets('going back to manual brings the dragging back', (tester) async {
    final c = await pumpApp(tester);
    c.read(tasksProvider.notifier).add('一件事');
    await c.read(taskSortProvider.notifier).set(TaskSort.due);
    await tester.pumpAndSettle();
    expect(find.byType(LongPressDraggable<String>), findsNothing);

    await tester.tap(find.byTooltip(zh.sortBy));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.sortManual));
    await tester.pumpAndSettle();

    expect(c.read(taskSortProvider), TaskSort.manual);
    expect(find.byType(LongPressDraggable<String>), findsOneWidget);
  });
}
