import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/goal_templates.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/widgets/goal_template_sheet.dart';

import 'helpers/pump_app.dart';

// Applying a template is the batch-create path, which is exactly the shape that
// used to lose rows to colliding ids (Phase 0, test/row_id_test.dart). These
// cases pin the counts, the parent links, and the absence of collisions
void main() {
  const zh = StringsZhTw();
  const semester = '114-1';

  setUp(() => setUpTestSupabase());

  // applyGoalTemplate takes a WidgetRef, so it is driven through a widget the
  // way the sheet drives it rather than called with a bare container
  Future<ProviderContainer> apply(
    WidgetTester tester,
    List<GoalTemplate> templates,
  ) async {
    late WidgetRef capturedRef;
    final scope = await pumpScreen(
      tester,
      Consumer(
        builder: (context, ref, child) {
          capturedRef = ref;
          return const SizedBox.shrink();
        },
      ),
    );
    for (final template in templates) {
      applyGoalTemplate(capturedRef, template, zh, semester);
    }
    return scope;
  }

  testWidgets('every template creates exactly what it advertises',
      (tester) async {
    for (final template in kGoalTemplates) {
      final scope = await apply(tester, [template]);

      final goals = scope.read(semesterGoalsProvider);
      final tasks = scope.read(tasksProvider);

      expect(goals.length, template.goalCount, reason: template.id);
      expect(tasks.length, template.taskCount, reason: template.id);
    }
  });

  testWidgets('milestones hang off the goal they belong to', (tester) async {
    final scope = await apply(tester, [kGoalTemplates.first]);
    final goals = scope.read(semesterGoalsProvider);

    final roots = goals.where((g) => g.parentId == null).toList();
    final milestones = goals.where((g) => g.parentId != null).toList();
    final rootIds = roots.map((g) => g.id).toSet();

    expect(roots, isNotEmpty);
    expect(milestones, isNotEmpty);
    // Every milestone points at a root of this same template, not at nothing
    // and not at another milestone
    for (final milestone in milestones) {
      expect(rootIds, contains(milestone.parentId));
    }
    // Rule 7: only a goal linked by hand carries a vision
    expect(goals.every((g) => g.futureGoalId == null), isTrue);
  });

  testWidgets('tasks link to a milestone, and every row lands in the semester',
      (tester) async {
    final scope = await apply(tester, [kGoalTemplates.first]);
    final goals = scope.read(semesterGoalsProvider);
    final tasks = scope.read(tasksProvider);
    final milestoneIds =
        goals.where((g) => g.parentId != null).map((g) => g.id).toSet();

    expect(tasks, isNotEmpty);
    for (final task in tasks) {
      expect(milestoneIds, contains(task.linkedTargetId));
    }
    expect(goals.every((g) => g.semester == semester), isTrue);
  });

  testWidgets('milestones inherit the categories of their goal', (tester) async {
    final exchange = kGoalTemplates.firstWhere((t) => t.id == 'exchange');
    final scope = await apply(tester, [exchange]);

    final goals = scope.read(semesterGoalsProvider);
    expect(goals.every((g) => g.categories.contains('exchange')), isTrue);
  });

  testWidgets('applying every template twice collides no ids', (tester) async {
    final scope = await apply(tester, [...kGoalTemplates, ...kGoalTemplates]);

    final goalIds = scope.read(semesterGoalsProvider).map((g) => g.id).toList();
    final taskIds = scope.read(tasksProvider).map((t) => t.id).toList();
    final expectedGoals =
        kGoalTemplates.fold(0, (n, t) => n + t.goalCount) * 2;
    final expectedTasks =
        kGoalTemplates.fold(0, (n, t) => n + t.taskCount) * 2;

    expect(goalIds.length, expectedGoals);
    expect(taskIds.length, expectedTasks);
    expect(goalIds.toSet().length, goalIds.length);
    expect(taskIds.toSet().length, taskIds.length);
  });

  test('a template never declares a count it cannot produce', () {
    for (final template in kGoalTemplates) {
      expect(template.goals, isNotEmpty, reason: template.id);
      expect(template.goalCount, greaterThan(template.goals.length),
          reason: '${template.id} should carry milestones');
      expect(template.taskCount, greaterThan(0), reason: template.id);
      // Every text slot resolves; a missing override would throw here
      expect(template.name(zh), isNotEmpty);
      expect(template.description(zh), isNotEmpty);
    }
  });
}
