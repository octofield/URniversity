import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/ui_symbols.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import '../helpers/pump_app.dart';

// A task row used to be IntrinsicHeight + Row, and ListTile measures its
// intrinsic height against the full width. A title that only wraps at the real
// width therefore reported one line's worth of height and the link line under
// it was cut off by the next row — what 2026-09-20 reported as "沒有適應雙行".
void main() {
  setUp(() => setUpTestSupabase());

  testWidgets('a two-line title does not push the link line into the next row',
      (tester) async {
    final c = await pumpApp(tester);
    final goals = c.read(semesterGoalsProvider.notifier);
    goals.addGoal('URniversity', currentSemester(c.read(semesterSettingsProvider)));
    final target = c.read(semesterGoalsProvider).single;

    final tasks = c.read(tasksProvider.notifier);
    // Newest first, so the long one is added last and sits on top of the other
    tasks.add('第二筆任務');
    tasks.add('篩選目標時加入如連結時的分類器與排序', linkedTargetId: target.id);
    await tester.pumpAndSettle();

    final link = find.text('$kArrow ${target.title}');
    expect(link, findsOneWidget);

    // The title has to wrap at the row's real width while still fitting on one
    // line at the tile's full width — that gap is exactly what the old
    // intrinsic-height measurement got wrong
    expect(
      tester.getSize(find.text('篩選目標時加入如連結時的分類器與排序')).height,
      greaterThan(30),
      reason: 'the title has to wrap for this case to mean anything',
    );
    expect(
      tester.getRect(link).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('第二筆任務')).top),
      reason: 'the link line is inside its own row, not under the next one',
    );
  });
}
