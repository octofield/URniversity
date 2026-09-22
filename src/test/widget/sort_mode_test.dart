import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/future_screen.dart';
import 'package:urniversity/screens/semester_screen.dart';

import '../helpers/pump_app.dart';

// Rearranging by hand (2026-09 batch 11): the sort sheet's last row shows a
// handle on every row that drags at once, with no long press, and the header's
// sort button becomes "done". The targets and visions pages gained the same
// sort sheet the task list has.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  Future<void> openRearrange(WidgetTester tester) async {
    await tester.tap(find.byTooltip(zh.sortBy));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.sortRearrange));
    await tester.pumpAndSettle();
  }

  group('tasks', () {
    testWidgets('rearranging shows handles that drag without a long press',
        (tester) async {
      final c = await pumpApp(tester);
      c.read(tasksProvider.notifier).add('第一件');
      c.read(tasksProvider.notifier).add('第二件');
      await tester.pumpAndSettle();
      expect(find.byType(LongPressDraggable<String>), findsNWidgets(2));

      await openRearrange(tester);

      expect(c.read(taskSortModeProvider), isTrue);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      expect(find.byType(LongPressDraggable<String>), findsNothing);
      // The handle is a plain Draggable: it starts on the first move
      expect(find.byType(Draggable<String>), findsNWidgets(2));
    });

    testWidgets('a row does not open while rearranging', (tester) async {
      final c = await pumpApp(tester);
      c.read(tasksProvider.notifier).add('不會打開');
      await tester.pumpAndSettle();
      await openRearrange(tester);

      await tester.tap(find.text('不會打開'));
      await tester.pumpAndSettle();

      expect(find.text(zh.editTask), findsNothing);
    });

    testWidgets('rearranging from another sort switches to manual first',
        (tester) async {
      final c = await pumpApp(tester);
      c.read(tasksProvider.notifier).add('一件事');
      await c.read(taskSortProvider.notifier).set(TaskSort.title);
      await tester.pumpAndSettle();

      await openRearrange(tester);

      expect(c.read(taskSortProvider), TaskSort.manual);
      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets('done puts the long-press dragging back', (tester) async {
      final c = await pumpApp(tester);
      c.read(tasksProvider.notifier).add('一件事');
      await tester.pumpAndSettle();
      await openRearrange(tester);

      await tester.tap(find.text(zh.done));
      await tester.pumpAndSettle();

      expect(c.read(taskSortModeProvider), isFalse);
      expect(find.byIcon(Icons.drag_handle), findsNothing);
      expect(find.byType(LongPressDraggable<String>), findsOneWidget);
    });
  });

  group('targets', () {
    Future<ProviderContainer> pumpTargets(WidgetTester tester) async {
      final c = testContainer();
      final sem = currentSemester(c.read(semesterSettingsProvider));
      final notifier = c.read(semesterGoalsProvider.notifier);
      // Added in this order, so the newer one is on top while manual
      notifier.addGoal('Alpha target', sem);
      notifier.addGoal('Beta target', sem);
      await pumpScreen(tester, const Scaffold(body: SemesterScreen()),
          container: c, width: 420);
      return c;
    }

    testWidgets('A-Z reorders the cards and stops the dragging',
        (tester) async {
      final c = await pumpTargets(tester);
      expect(
        tester.getRect(find.text('Beta target')).top,
        lessThan(tester.getRect(find.text('Alpha target')).top),
      );

      await tester.tap(find.byTooltip(zh.sortBy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zh.sortTitle));
      await tester.pumpAndSettle();

      expect(c.read(targetSortProvider), TargetSort.title);
      expect(
        tester.getRect(find.text('Alpha target')).top,
        lessThan(tester.getRect(find.text('Beta target')).top),
      );
      expect(find.byType(LongPressDraggable<String>), findsNothing);
    });

    testWidgets('rearranging shows a handle on every card', (tester) async {
      final c = await pumpTargets(tester);

      await openRearrange(tester);

      expect(c.read(targetSortModeProvider), isTrue);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
      expect(find.byType(LongPressDraggable<String>), findsNothing);
      expect(find.text(zh.done), findsOneWidget);
    });
  });

  group('visions', () {
    testWidgets('A-Z reorders the cards and rearranging shows handles',
        (tester) async {
      final c = testContainer();
      final notifier = c.read(futureGoalsProvider.notifier);
      notifier.addGoal(title: 'Alpha vision');
      notifier.addGoal(title: 'Beta vision');
      await pumpScreen(tester, const Scaffold(body: FutureScreen()),
          container: c, width: 420);
      // Newest first while manual
      expect(
        tester.getRect(find.text('Beta vision')).top,
        lessThan(tester.getRect(find.text('Alpha vision')).top),
      );

      await tester.tap(find.byTooltip(zh.sortBy));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zh.sortTitle));
      await tester.pumpAndSettle();

      expect(c.read(visionSortProvider), VisionSort.title);
      expect(
        tester.getRect(find.text('Alpha vision')).top,
        lessThan(tester.getRect(find.text('Beta vision')).top),
      );

      await openRearrange(tester);

      expect(c.read(visionSortProvider), VisionSort.manual);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    });
  });
}
