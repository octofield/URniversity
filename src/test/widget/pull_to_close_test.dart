import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/screens/task_history_screen.dart';
import 'package:urniversity/screens/timetable_screen.dart';

import '../helpers/pump_app.dart';

// Pulling a page down to close it (system_design.md §3-Q, 2026-10-03): a pull
// that came back up stays, a close slides away before the page goes, and the
// history closes the same way (the backend's own: admin_test.dart)
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  Future<void> openFromAPage(WidgetTester tester, Widget page) async {
    await pumpScreen(
      tester,
      Builder(builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
            child: const Text('open'),
          ),
        ),
      )),
      container: testContainer(),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a pull that comes back up before letting go stays', (tester) async {
    await openFromAPage(tester, const TimetableScreen());
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView).first));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    // Back up most of the way, then let go
    for (var i = 0; i < 7; i++) {
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsOneWidget);
  });

  testWidgets('a pull that comes back a little, then holds still, stays too', (tester) async {
    await openFromAPage(tester, const TimetableScreen());
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView).first));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    // Still past the threshold, but the last movement was up; holding still
    // first leaves no flick to read either way
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsOneWidget);
  });

  testWidgets('a close slides the page away before it goes', (tester) async {
    await openFromAPage(tester, const TimetableScreen());
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // Mid-way: still there, lower down and fading
    expect(find.byType(TimetableScreen), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(TimetableScreen), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsNothing);
  });

  testWidgets('the history swipes between day, week and month, and pulls down to close', (tester) async {
    await openFromAPage(tester, const TaskHistoryScreen());
    // Swiped over the switch: the chart below scrolls sideways itself
    SegmentedButton<int> range() => tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>));
    expect(range().selected, {0});

    await tester.fling(find.byType(SegmentedButton<int>), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(range().selected, {1});
    await tester.fling(find.byType(SegmentedButton<int>), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(range().selected, {2});
    await tester.fling(find.byType(SegmentedButton<int>), const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    expect(range().selected, {1});

    await tester.drag(find.text(zh.historyMonthly), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(TaskHistoryScreen), findsNothing);
  });

}
