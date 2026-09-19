import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/future_goal.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/responsive_body.dart';
import 'future_screen.dart';
import 'semester_goal_detail_screen.dart';

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

    final linkedTargets = ref.watch(semesterGoalsProvider)
        .where((g) => g.futureGoalId == goalId && g.parentId == null)
        .toList();

    final cats = ref.watch(categoriesProvider);
    final semSettings = ref.watch(semesterSettingsProvider);
    final primaryCat = primaryCategoryOf(goal.categories);
    final catC = resolveCatColor(cats, primaryCat);

    // Layout follows screen width, not platform, so narrow web windows get the mobile UI

    final content = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageHorizontal, AppSpacing.md,
          AppSpacing.pageHorizontal, 80,
        ),
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    ref.read(futureGoalsProvider.notifier).toggleDone(goalId),
                behavior: HitTestBehavior.opaque,
                child: Tooltip(
                  message: goal.isDone ? s.markUndone : s.markDone,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: catC.withValues(alpha: goal.isDone ? 0.25 : 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                        goal.isDone
                            ? Icons.check
                            : resolveCatIcon(cats, primaryCat),
                        color: catC,
                        size: 26),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                          decoration:
                              goal.isDone ? TextDecoration.lineThrough : null,
                          color: goal.isDone ? AppColors.textTertiary : null,
                        )),
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
                              formatSemester(goal.startSemester!, semSettings, s),
                            if (goal.startSemester != null &&
                                goal.endSemester != null)
                              kArrow,
                            if (goal.endSemester != null)
                              formatSemester(goal.endSemester!, semSettings, s),
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
                showFutureGoalSheet(context, ref, parentId: goalId),
          ),

          const Divider(),

          // Linked semester targets section
          _SectionHeader(label: s.linkedTargets),
          if (linkedTargets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(kEmptyValue,
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
              subtitle: Text(formatSemester(target.semester, semSettings, s),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.link_off, size: 18),
                    color: AppColors.textTertiary,
                    onPressed: () => ref
                        .read(semesterGoalsProvider.notifier)
                        .linkFutureGoal(target.id, null),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: AppColors.textTertiary),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SemesterGoalDetailScreen(goalId: target.id),
                ),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_link, color: AppColors.primary),
            title: Text(s.addLinkedTarget,
                style: const TextStyle(color: AppColors.primary)),
            onTap: () => _showTargetSelectorForGoal(context, ref, goalId),
          ),
        ],
      );

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: s.editGoal,
            onPressed: () => showFutureGoalSheet(context, ref, existing: goal),
          ),
        ],
      ),
      body: ResponsiveBody(child: content),
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
    // Sorted here because the provider's state keeps insertion order, which
    // would show a brand-new child at the bottom until the next reload
    final children = allGoals.where((g) => g.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

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
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => showFutureGoalSheet(context, ref, existing: goal),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () async {
                if (await confirmDelete(context, s)) {
                  // Snapshot the whole subtree, not just the root
                  final removed =
                      ref.read(futureGoalsProvider.notifier).remove(goal.id);
                  final trash = ref.read(trashProvider.notifier);
                  for (final g in removed) {
                    trash.addFutureGoal(g);
                  }
                }
              },
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

class _CategoryBadge extends ConsumerWidget {
  final String cat;
  final AppStrings s;
  const _CategoryBadge({required this.cat, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final color = resolveCatColor(cats, cat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolveCatIcon(cats, cat), size: 12, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(catLabel(cat, s),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

void _showTargetSelectorForGoal(
    BuildContext context, WidgetRef ref, String goalId) {
  final s = ref.read(stringsProvider);
  final semSettings = ref.read(semesterSettingsProvider);
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectTarget),
      content: SizedBox(
        width: 400,
        child: Consumer(
          builder: (_, dlgRef, _) {
            final targets = dlgRef
                .watch(semesterGoalsProvider)
                .where((g) => g.parentId == null)
                .toList();
            if (targets.isEmpty) {
              return Text(s.noTargets,
                  style: const TextStyle(color: AppColors.textTertiary));
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final target in targets)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      target.futureGoalId == goalId
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: target.futureGoalId == goalId
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    title: Text(target.title,
                        style: TextStyle(
                          color: target.futureGoalId == goalId
                              ? AppColors.textTertiary
                              : null,
                        )),
                    subtitle: Text(formatSemester(target.semester, semSettings, s),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary)),
                    enabled: target.futureGoalId != goalId,
                    onTap: target.futureGoalId == goalId
                        ? null
                        : () {
                            dlgRef
                                .read(semesterGoalsProvider.notifier)
                                .linkFutureGoal(target.id, goalId);
                            Navigator.pop(dlgCtx);
                          },
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlgCtx),
          child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
        ),
      ],
    ),
  );
}
