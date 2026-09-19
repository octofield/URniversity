import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';

// Deleting a parent used to drop its children from state while trashing only
// the parent, so the children were gone with nothing to restore. remove() now
// returns the whole subtree and every caller snapshots each row it gets back.
// Retires the logic half of cases 13, 15-19 of
// docs/test-plans/2026-08-23-known-issues.md; "still there after a restart"
// stays manual because it depends on Supabase.
void main() {
  late ProviderContainer c;

  setUp(() {
    c = ProviderContainer();
    addTearDown(c.dispose);
  });

  group('semester goals', () {
    // No user id is set, so upsert/deleteRow return before touching Supabase
    String addGoal({String? parentId, String title = 'g'}) {
      c.read(semesterGoalsProvider.notifier).addGoal(title, '114-1',
          parentId: parentId);
      return c.read(semesterGoalsProvider).last.id;
    }

    test('removing a parent returns the parent and its children', () {
      final parent = addGoal(title: 'parent');
      final childA = addGoal(parentId: parent, title: 'a');
      final childB = addGoal(parentId: parent, title: 'b');

      final removed = c.read(semesterGoalsProvider.notifier).remove(parent);

      expect(removed.map((g) => g.id), containsAll([parent, childA, childB]));
      expect(removed, hasLength(3));
      expect(c.read(semesterGoalsProvider), isEmpty);
    });

    test('a three-level tree comes back whole', () {
      final root = addGoal(title: 'root');
      final mid = addGoal(parentId: root, title: 'mid');
      final leaf = addGoal(parentId: mid, title: 'leaf');

      final removed = c.read(semesterGoalsProvider.notifier).remove(root);

      expect(removed.map((g) => g.id), containsAll([root, mid, leaf]));
      expect(removed, hasLength(3));
    });

    test('removing a middle node leaves its ancestors alone', () {
      final root = addGoal(title: 'root');
      final mid = addGoal(parentId: root, title: 'mid');
      final leaf = addGoal(parentId: mid, title: 'leaf');

      final removed = c.read(semesterGoalsProvider.notifier).remove(mid);

      expect(removed.map((g) => g.id), containsAll([mid, leaf]));
      expect(removed, hasLength(2));
      expect(c.read(semesterGoalsProvider).single.id, root);
    });

    test('a leaf is returned once, not twice', () {
      final only = addGoal(title: 'only');
      final removed = c.read(semesterGoalsProvider.notifier).remove(only);
      expect(removed, hasLength(1));
      expect(removed.single.id, only);
    });

    test('an unknown id removes nothing', () {
      addGoal(title: 'kept');
      expect(c.read(semesterGoalsProvider.notifier).remove('nope'), isEmpty);
      expect(c.read(semesterGoalsProvider), hasLength(1));
    });

    test('every removed row can be restored', () {
      final parent = addGoal(title: 'parent');
      addGoal(parentId: parent, title: 'child');

      final notifier = c.read(semesterGoalsProvider.notifier);
      final removed = notifier.remove(parent);
      for (final g in removed) {
        notifier.restore(g);
      }

      final back = c.read(semesterGoalsProvider);
      expect(back, hasLength(2));
      expect(back.where((g) => g.parentId == parent), hasLength(1));
    });
  });

  group('future goals', () {
    String addGoal({String? parentId, String title = 'g'}) {
      c.read(futureGoalsProvider.notifier)
          .addGoal(title: title, parentId: parentId);
      return c.read(futureGoalsProvider).last.id;
    }

    test('removing a vision returns its whole subtree', () {
      final root = addGoal(title: 'root');
      final mid = addGoal(parentId: root, title: 'mid');
      final leaf = addGoal(parentId: mid, title: 'leaf');

      final removed = c.read(futureGoalsProvider.notifier).remove(root);

      expect(removed.map((g) => g.id), containsAll([root, mid, leaf]));
      expect(removed, hasLength(3));
      expect(c.read(futureGoalsProvider), isEmpty);
    });

    test('a childless vision is returned once', () {
      final only = addGoal(title: 'only');
      expect(c.read(futureGoalsProvider.notifier).remove(only), hasLength(1));
    });
  });

  group('tasks', () {
    test('removing a task returns only itself', () {
      final notifier = c.read(tasksProvider.notifier);
      notifier.add('alone');
      final id = c.read(tasksProvider).single.id;
      expect(notifier.remove(id), hasLength(1));
    });
  });
}
