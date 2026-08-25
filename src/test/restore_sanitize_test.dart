import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';

// Deleting a goal removes its whole subtree, and every removed goal is
// snapshotted to the trash. That makes it possible to restore a child while its
// parent is still gone — parent_id would then point at a row the real foreign
// key (semester_goals_parent_id_fkey) can no longer resolve, so the write is
// rejected and the restored goal never syncs.
//
// sanitizeForRestore puts such a goal back at the top level instead, which is
// what system_design.md UC6 has always claimed happened.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  group('SemesterGoalsNotifier.sanitizeForRestore', () {
    SemesterGoalsNotifier notifier() =>
        container.read(semesterGoalsProvider.notifier);

    test('a goal whose parent is gone comes back at the top level', () {
      final orphan = const SemesterGoal(
        id: 'child', parentId: 'deleted-parent', title: 'Milestone',
        semester: '114-1',
      );
      expect(notifier().sanitizeForRestore(orphan).parentId, isNull);
    });

    test('a goal whose parent is still present keeps its parent', () {
      notifier().addGoal('Parent', '114-1');
      final parentId = container.read(semesterGoalsProvider).single.id;
      final child = SemesterGoal(
        id: 'child', parentId: parentId, title: 'Milestone', semester: '114-1',
      );
      expect(notifier().sanitizeForRestore(child).parentId, parentId);
    });

    test('a top-level goal is returned untouched', () {
      final top = const SemesterGoal(id: 'top', title: 'Goal', semester: '114-1');
      expect(identical(notifier().sanitizeForRestore(top), top), isTrue);
    });

    test('restore() puts an orphan into state without its parent', () {
      final orphan = const SemesterGoal(
        id: 'child', parentId: 'deleted-parent', title: 'Milestone',
        semester: '114-1',
      );
      notifier().restore(orphan);
      final stored = container.read(semesterGoalsProvider).single;
      expect(stored.id, 'child');
      expect(stored.parentId, isNull, reason: 'would violate the FK otherwise');
    });

    test('every other field survives the reattach', () {
      final orphan = const SemesterGoal(
        id: 'child', parentId: 'gone', title: 'Milestone', semester: '114-2',
        categories: ['intern'], notes: 'keep me', isDone: true, sortOrder: 3000,
      );
      final fixed = notifier().sanitizeForRestore(orphan);
      expect(fixed.title, 'Milestone');
      expect(fixed.semester, '114-2');
      expect(fixed.categories, ['intern']);
      expect(fixed.notes, 'keep me');
      expect(fixed.isDone, isTrue);
      expect(fixed.sortOrder, 3000);
    });
  });

  group('FutureGoalsNotifier.sanitizeForRestore', () {
    test('an orphaned vision comes back at the top level', () {
      final orphan = const FutureGoal(id: 'child', parentId: 'gone', title: 'Sub');
      final fixed = container
          .read(futureGoalsProvider.notifier)
          .sanitizeForRestore(orphan);
      expect(fixed.parentId, isNull);
      expect(fixed.title, 'Sub');
    });
  });

  // A trashed row keeps the ids it held when it was deleted. ON DELETE SET NULL
  // only rewrites rows that still exist, so a goal deleted AFTER the task was
  // trashed leaves the snapshot pointing at nothing. These are real foreign
  // keys (tasks_linked_target_id_fkey, semester_goals_future_goal_id_fkey), so
  // restoring without clearing them is rejected with 23503.
  group('dangling cross-table links', () {
    test('a task keeps a link whose target still exists', () {
      container.read(semesterGoalsProvider.notifier).addGoal('Target', '114-1');
      final goalId = container.read(semesterGoalsProvider).single.id;
      final task = Task(
        id: 't1', title: 'Task', createdAt: DateTime(2026, 8, 25),
        linkedTargetId: goalId,
      );
      final clean = container.read(tasksProvider.notifier).sanitizeForRestore(task);
      expect(clean.linkedTargetId, goalId);
    });

    test('a task drops a link whose target is gone', () {
      final task = Task(
        id: 't1', title: 'Task', createdAt: DateTime(2026, 8, 25),
        linkedTargetId: 'deleted-goal',
      );
      final clean = container.read(tasksProvider.notifier).sanitizeForRestore(task);
      expect(clean.linkedTargetId, isNull);
      expect(clean.title, 'Task', reason: 'other fields untouched');
    });

    test('a task drops a vision link whose vision is gone', () {
      final task = Task(
        id: 't1', title: 'Task', createdAt: DateTime(2026, 8, 25),
        linkedGoalId: 'deleted-vision',
      );
      expect(
        container.read(tasksProvider.notifier).sanitizeForRestore(task).linkedGoalId,
        isNull,
      );
    });

    test('a task with nothing dangling is returned untouched', () {
      final task = Task(id: 't1', title: 'Task', createdAt: DateTime(2026, 8, 25));
      final notifier = container.read(tasksProvider.notifier);
      expect(identical(notifier.sanitizeForRestore(task), task), isTrue);
    });

    test('a semester goal drops a vision link whose vision is gone', () {
      final goal = const SemesterGoal(
        id: 'g1', title: 'Goal', semester: '114-1', futureGoalId: 'deleted-vision',
      );
      final clean = container
          .read(semesterGoalsProvider.notifier)
          .sanitizeForRestore(goal);
      expect(clean.futureGoalId, isNull);
      expect(clean.title, 'Goal');
    });

    test('a semester goal keeps a vision link that still resolves', () {
      container.read(futureGoalsProvider.notifier).addGoal(title: 'Vision');
      final visionId = container.read(futureGoalsProvider).single.id;
      final goal = SemesterGoal(
        id: 'g1', title: 'Goal', semester: '114-1', futureGoalId: visionId,
      );
      expect(
        container.read(semesterGoalsProvider.notifier).sanitizeForRestore(goal).futureGoalId,
        visionId,
      );
    });
  });
}
