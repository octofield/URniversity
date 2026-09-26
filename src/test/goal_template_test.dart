import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/goal_templates.dart';
import 'package:urniversity/core/input_limits.dart';
import 'package:urniversity/l10n/app_strings.dart';
import 'package:urniversity/l10n/strings_en.dart';
import 'package:urniversity/l10n/strings_jp.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
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
  });

  testWidgets('each template makes one vision and links only its top-level goals',
      (tester) async {
    for (final template in kGoalTemplates) {
      final scope = await apply(tester, [template]);
      final visions = scope.read(futureGoalsProvider);
      final goals = scope.read(semesterGoalsProvider);

      expect(visions.single.title, template.vision.title(zh), reason: template.id);
      expect(visions.single.startSemester, semester);
      // Rule 7: a milestone takes its vision from its parent, never directly
      for (final g in goals) {
        expect(g.futureGoalId, g.parentId == null ? visions.single.id : isNull,
            reason: '${template.id}: ${g.title}');
      }
    }
  });

  testWidgets('a goal with no category of its own takes the vision\'s',
      (tester) async {
    final grad = kGoalTemplates.firstWhere((t) => t.id == 'grad');
    final cert = kGoalTemplates.firstWhere((t) => t.id == 'cert');
    final scope = await apply(tester, [grad, cert]);
    final goals = scope.read(semesterGoalsProvider);

    List<String> categoriesOf(String title) =>
        goals.firstWhere((g) => g.title == title).categories;
    expect(categoriesOf(zh.tplGradG1), ['other']);
    expect(categoriesOf(zh.tplGradG1M1), ['other']);
    // One that names its own keeps it
    expect(categoriesOf(zh.tplCertG2), ['competition']);
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

  test('every title fits the title cap in every language', () {
    for (final s in const <AppStrings>[StringsZhTw(), StringsEn(), StringsJp()]) {
      for (final template in kGoalTemplates) {
        final titles = [
          template.vision.title(s),
          for (final g in template.goals) ...[
            g.title(s),
            for (final m in g.milestones) ...[m.title(s), for (final t in m.tasks) t(s)],
          ],
        ];
        for (final title in titles) {
          expect(title, isNotEmpty, reason: template.id);
          expect(title.length, lessThanOrEqualTo(InputLimits.title), reason: title);
        }
      }
    }
  });
}
