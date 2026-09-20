import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/screens/today_screen.dart';

import '../helpers/pump_app.dart';

// The drag handle was the only thing that could close a sheet, because the
// scroll view underneath wins every vertical drag. With the keyboard up the
// sheet fills the screen and that handle is a 36px strip at the very top —
// nowhere near a thumb. Pulling the content down closes it now.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  Future<void> openTaskSheet(WidgetTester tester) async {
    await pumpScreen(
      tester,
      Consumer(
        builder: (ctx, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showTaskSheet(ctx, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('pulling the content down closes the sheet', (tester) async {
    await openTaskSheet(tester);
    expect(find.text(zh.addTask), findsOneWidget);

    await tester.drag(find.text(zh.addTask), const Offset(0, 250));
    await tester.pumpAndSettle();

    expect(find.text(zh.addTask), findsNothing);
  });

  testWidgets('a flick of the thumb is enough', (tester) async {
    await openTaskSheet(tester);

    // 60px: the threshold came down from 90 to 40 on 2026-09-21
    await tester.drag(find.text(zh.addTask), const Offset(0, 60));
    await tester.pumpAndSettle();

    expect(find.text(zh.addTask), findsNothing);
  });

  testWidgets('a nudge leaves it open', (tester) async {
    await openTaskSheet(tester);

    await tester.drag(find.text(zh.addTask), const Offset(0, 15));
    await tester.pumpAndSettle();

    expect(find.text(zh.addTask), findsOneWidget);
  });
}
