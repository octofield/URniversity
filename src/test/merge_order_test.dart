import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/synced_list_notifier.dart';
import 'package:urniversity/providers/tasks_provider.dart';

// Guest data is merged one row at a time, and parent_id is a REAL foreign key
// (semester_goals_parent_id_fkey). A child sent before its parent is rejected
// with 23503 and that row is lost for good, so mergeOrder() has to hand back
// parents first.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  int indexOfId(List<String> orderedIds, String id) => orderedIds.indexOf(id);

  group('SemesterGoalsNotifier.mergeOrder', () {
    test('a parent is ordered before its child', () {
      final n = container.read(semesterGoalsProvider.notifier);
      n.addGoal('Parent', '114-1');
      final parentId = container.read(semesterGoalsProvider).single.id;
      n.addGoal('Child', '114-1', parentId: parentId);

      final ordered = [for (final g in n.mergeOrder()) g.id];
      final childId =
          container.read(semesterGoalsProvider).firstWhere((g) => g.parentId != null).id;
      expect(indexOfId(ordered, parentId), lessThan(indexOfId(ordered, childId)));
    });

    test('every goal survives the ordering', () {
      final n = container.read(semesterGoalsProvider.notifier);
      n.addGoal('A', '114-1');
      final a = container.read(semesterGoalsProvider).single.id;
      n.addGoal('B', '114-1', parentId: a);
      final b = container.read(semesterGoalsProvider).firstWhere((g) => g.title == 'B').id;
      n.addGoal('C', '114-1', parentId: b);

      final raw = n.mergeOrder();
      final ordered = [for (final g in raw) g.id];
      expect(ordered.length, 3, reason: 'nothing dropped');
      expect(indexOfId(ordered, a), lessThan(indexOfId(ordered, b)));
      expect(indexOfId(ordered, b), lessThan(indexOfId(ordered, raw.last.id)));
    });

    test('a goal whose parent is missing is still merged', () {
      // Restored-from-trash rows can carry a parent id that no longer exists.
      // Dropping them would be worse than letting the database decide
      final n = container.read(semesterGoalsProvider.notifier);
      n.addGoal('Orphan', '114-1', parentId: 'never-existed');
      expect(n.mergeOrder().length, 1);
    });

    test('an empty list orders to nothing', () {
      expect(container.read(semesterGoalsProvider.notifier).mergeOrder(), isEmpty);
    });
  });

  // Tasks have no parents of their own any more, so ordering them is only about
  // keeping every row
  group('TasksNotifier.mergeOrder', () {
    test('flat lists keep every task', () {
      final n = container.read(tasksProvider.notifier);
      n.add('One');
      n.add('Two');
      expect(n.mergeOrder().length, 2);
    });
  });

  // Row ids used to be a bare millisecond timestamp, so anything created in a
  // loop shared one id — and because id is the primary key, the second upsert
  // overwrote the first. Templates (one tap creating several goals) would have
  // hit this on day one.
  group('newRowId', () {
    test('a tight loop produces distinct ids', () {
      final ids = {for (var i = 0; i < 500; i++) newRowId()};
      expect(ids.length, 500);
    });

    test('ids stay roughly time-ordered', () {
      final first = newRowId().split('_').first;
      final second = newRowId().split('_').first;
      expect(int.parse(second), greaterThanOrEqualTo(int.parse(first)));
    });

    test('three goals created back to back keep three rows', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final n = container.read(semesterGoalsProvider.notifier);
      n.addGoal('A', '114-1');
      n.addGoal('B', '114-1');
      n.addGoal('C', '114-1');
      final ids = container.read(semesterGoalsProvider).map((g) => g.id).toSet();
      expect(ids.length, 3, reason: 'same-millisecond ids used to collapse');
    });
  });
}
