import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/future_goal.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../utils/category_helpers.dart';
import 'future_screen.dart';

class FutureGoalDetailScreen extends ConsumerWidget {
  final String goalId;
  const FutureGoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final goal = ref.watch(futureGoalsProvider)
        .where((g) => g.id == goalId)
        .firstOrNull;

    if (goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final linkedTasks = ref.watch(tasksProvider)
        .where((t) => t.linkedGoalId == goalId)
        .toList();
    final linkedTargets = ref.watch(semesterGoalsProvider)
        .where((g) => g.futureGoalId == goalId && g.parentId == null)
        .toList();

    final primaryCat = goal.categories.isNotEmpty
        ? goal.categories.first
        : FutureCategories.other;
    final catC = catColor(primaryCat);

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: s.editGoal,
            onPressed: () => showEditFutureGoalSheet(context, ref, goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, AppSpacing.md,
          AppSpacing.pageHorizontal, 80,
        ),
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: catC.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(catIcon(primaryCat), color: catC, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final cat in goal.categories)
                          _CategoryBadge(cat: cat, s: s),
                      ],
                    ),
                    if (goal.startSemester != null ||
                        goal.endSemester != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          [
                            if (goal.startSemester != null)
                              goal.startSemester!,
                            if (goal.startSemester != null &&
                                goal.endSemester != null)
                              '→',
                            if (goal.endSemester != null) goal.endSemester!,
                          ].join(' '),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),
                    if (goal.notes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(goal.notes!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(),

          // Sub-goals section (tree view)
          _SectionHeader(label: s.subgoals),
          GoalSubtreeView(parentId: goalId),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.add, color: AppColors.primary),
            title: Text(s.addSubgoal,
                style: const TextStyle(color: AppColors.primary)),
            onTap: () =>
                showAddFutureGoalSheet(context, ref, parentId: goalId),
          ),

          const Divider(),

          // Linked tasks section
          _SectionHeader(label: s.linkedTasks),
          if (linkedTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('—',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  )),
            ),
          for (final task in linkedTasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                task.isCompleted
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                color: task.isCompleted
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted ? AppColors.textTertiary : null,
                ),
              ),
              subtitle: task.content != null
                  ? Text(task.content!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                  : null,
            ),

          const Divider(),

          // Linked semester targets section
          _SectionHeader(label: s.linkedTargets),
          if (linkedTargets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('—',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  )),
            ),
          for (final target in linkedTargets)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                target.isDone
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: target.isDone
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              title: Text(
                target.title,
                style: TextStyle(
                  decoration:
                      target.isDone ? TextDecoration.lineThrough : null,
                  color: target.isDone ? AppColors.textTertiary : null,
                ),
              ),
              subtitle: Text(target.semester,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

// Reusable recursive sub-goal tree — used in FutureGoalDetailScreen and _GoalCard
class GoalSubtreeView extends ConsumerWidget {
  final String parentId;
  final int depth;

  const GoalSubtreeView({
    super.key,
    required this.parentId,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allGoals = ref.watch(futureGoalsProvider);
    final children = allGoals.where((g) => g.parentId == parentId).toList();

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in children)
          _GoalTreeTile(goal: child, depth: depth),
      ],
    );
  }
}

class _GoalTreeTile extends ConsumerWidget {
  final FutureGoal goal;
  final int depth;

  const _GoalTreeTile({required this.goal, required this.depth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allGoals = ref.watch(futureGoalsProvider);
    final children = allGoals.where((g) => g.parentId == goal.id).toList();
    final doneCount = children.where((c) => c.isDone).length;
    // Each depth level adds 16px left indent; minimum base indent is also 16px
    final leftPad = AppSpacing.md + depth * AppSpacing.md;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Toggle completion
            GestureDetector(
              onTap: () =>
                  ref.read(futureGoalsProvider.notifier).toggleDone(goal.id),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(
                    left: leftPad, top: 10, bottom: 10, right: 6),
                child: Icon(
                  goal.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: goal.isDone
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            // Content + navigate
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FutureGoalDetailScreen(goalId: goal.id),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: TextStyle(
                          fontSize: 14,
                          decoration: goal.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: goal.isDone
                              ? AppColors.textTertiary
                              : null,
                        ),
                      ),
                      if (goal.notes != null)
                        Text(
                          goal.notes!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppColors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (children.isNotEmpty)
                        Text(
                          s.goalProgress(doneCount, children.length),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: Icon(Icons.arrow_forward_ios,
                  size: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
        // Children (recursive)
        GoalSubtreeView(parentId: goal.id, depth: depth + 1),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          )),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String cat;
  final dynamic s;
  const _CategoryBadge({required this.cat, required this.s});

  @override
  Widget build(BuildContext context) {
    final color = catColor(cat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(catIcon(cat), size: 12, color: color),
          const SizedBox(width: 4),
          Text(catLabel(cat, s),
              style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
