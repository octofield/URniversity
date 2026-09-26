import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/goal_templates.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import 'sheet_body.dart';

// Writes a template into the user's own data, one ordinary addGoal()/add() call
// per row. The vision comes first and only the top-level goals link to it —
// milestones never carry a future_goal_id (CLAUDE.md §9 rule 7). A goal with no
// category of its own takes the vision's, as linking by hand does, and its
// milestones carry the goal's.
//
// addGoal() mints its own id per call, so a template with repeated rows cannot
// collide the way a bare timestamp id once did
void applyGoalTemplate(
  WidgetRef ref,
  GoalTemplate template,
  AppStrings s,
  String semester,
) {
  final goals = ref.read(semesterGoalsProvider.notifier);
  final tasks = ref.read(tasksProvider.notifier);

  final visionId = ref.read(futureGoalsProvider.notifier).addGoal(
        title: template.vision.title(s),
        categories: template.vision.categories,
        startSemester: semester,
      );

  for (final goal in template.goals) {
    final categories = goal.categories.isEmpty ? template.vision.categories : goal.categories;
    final goalId = goals.addGoal(
      goal.title(s),
      semester,
      categories: categories,
      futureGoalId: visionId,
    );
    for (final milestone in goal.milestones) {
      final milestoneId = goals.addGoal(
        milestone.title(s),
        semester,
        parentId: goalId,
        categories: categories,
      );
      for (final task in milestone.tasks) {
        tasks.add(task(s), linkedTargetId: milestoneId);
      }
    }
  }
}

void showGoalTemplateSheet(BuildContext context, WidgetRef ref) {
  final s = ref.read(stringsProvider);
  final semester = ref.read(selectedSemesterProvider);

  showAppSheet(
    context,
    builder: (sheetCtx) => SheetBody(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.goalTemplates, style: Theme.of(sheetCtx).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          for (final template in kGoalTemplates) ...[
            _TemplateCard(
              template: template,
              s: s,
              onApply: () {
                applyGoalTemplate(ref, template, s, semester);
                Navigator.pop(sheetCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      s.templateApplied(template.goalCount, template.taskCount),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    ),
  );
}

class _TemplateCard extends StatelessWidget {
  final GoalTemplate template;
  final AppStrings s;
  final VoidCallback onApply;

  const _TemplateCard({
    required this.template,
    required this.s,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(template.name(s), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            template.description(s),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.templateContents(template.goalCount, template.taskCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ),
              FilledButton(onPressed: onApply, child: Text(s.applyTemplate)),
            ],
          ),
        ],
      ),
    );
  }
}
