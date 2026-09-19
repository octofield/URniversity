import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/widgets/swipe_switcher.dart';

import '../helpers/pump_app.dart';

// Switching views or semesters meant reaching for a control at the top of the
// page. A fling across the body does it now — but only a fling, so a vertical
// scroll that wanders sideways still scrolls.
void main() {
  setUp(() => setUpTestSupabase());

  testWidgets('flinging the task list moves between the three views',
      (tester) async {
    final c = await pumpApp(tester);
    expect(c.read(taskViewProvider), 0);

    // Only the page on screen is hit-testable, so this is the visible one
    final body = find.byType(SwipeSwitcher);

    await tester.fling(body, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(c.read(taskViewProvider), 1, reason: 'left goes forward');

    await tester.fling(body, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(c.read(taskViewProvider), 0, reason: 'right goes back');

    // Already at the first view, so there is nowhere further back
    await tester.fling(body, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(c.read(taskViewProvider), 0);
  });

  testWidgets('a slow sideways drag is not a switch', (tester) async {
    final c = await pumpApp(tester);

    await tester.fling(find.byType(SwipeSwitcher), const Offset(-300, 0), 60);
    await tester.pumpAndSettle();

    expect(c.read(taskViewProvider), 0);
  });

  testWidgets('flinging the target list moves between semesters', (tester) async {
    final c = await pumpApp(tester);
    final settings = c.read(semesterSettingsProvider);
    final semesters = generateSemesters(settings);
    final start = currentSemester(settings);
    c.read(semesterGoalsProvider.notifier).addGoal('本學期目標', start);

    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(SwipeSwitcher), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(
      c.read(selectedSemesterProvider),
      semesters[semesters.indexOf(start) + 1],
    );
  });
}
