import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/notification_action_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import '../helpers/pump_app.dart';

// "Reschedule" has to land the user on the right task's edit sheet, and on a
// cold start the notification is handled long before the rows have loaded.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  testWidgets('opens the edit sheet for the task named by the notification',
      (tester) async {
    final c = await pumpApp(tester);
    c.read(tasksProvider.notifier).add('要改時間的任務');
    await tester.pumpAndSettle();
    final task = c.read(tasksProvider).single;

    c.read(pendingTaskEditProvider.notifier).state = task.id;
    await tester.pumpAndSettle();

    expect(find.text(zh.editTask), findsOneWidget);
    expect(find.text('要改時間的任務'), findsWidgets);
  });

  testWidgets('waits for the task to load instead of giving up', (tester) async {
    final c = await pumpApp(tester);

    // A cold start: the notification is handled before any row has arrived
    c.read(pendingTaskEditProvider.notifier).state = 'not-loaded-yet';
    await tester.pumpAndSettle();
    expect(find.text(zh.editTask), findsNothing);
    expect(c.read(pendingTaskEditProvider), 'not-loaded-yet',
        reason: 'the request must survive until the rows arrive');
  });

  testWidgets('the request is cleared once it has been acted on',
      (tester) async {
    final c = await pumpApp(tester);
    c.read(tasksProvider.notifier).add('任務');
    await tester.pumpAndSettle();

    c.read(pendingTaskEditProvider.notifier).state =
        c.read(tasksProvider).single.id;
    await tester.pumpAndSettle();

    // Otherwise the sheet reopens on every later rebuild
    expect(c.read(pendingTaskEditProvider), isNull);
  });
}
