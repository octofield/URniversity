import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ui_symbols.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/recent_picks_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/responsive_body.dart';
import '../widgets/semester_grouped_picker.dart';
import '../widgets/sheet_body.dart';
import '../widgets/sheet_fields.dart';
import 'future_goal_detail_screen.dart';

class SemesterGoalDetailScreen extends ConsumerWidget {
  final String goalId;
  const SemesterGoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final goal = ref.watch(semesterGoalsProvider).where((g) => g.id == goalId).firstOrNull;

    if (goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final children = ref.watch(semesterGoalsProvider).where((g) => g.parentId == goalId).toList();
    final linkedTasks = ref.watch(tasksProvider).where((t) => t.linkedTargetId == goalId).toList();
    final linkedGoal = goal.futureGoalId != null
        ? ref.watch(futureGoalsProvider).where((g) => g.id == goal.futureGoalId).firstOrNull
        : null;

    final cats = ref.watch(categoriesProvider);
    final semSettings = ref.watch(semesterSettingsProvider);
    final primaryCat = primaryCategoryOf(goal.categories);
    final catC = resolveCatColor(cats, primaryCat);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;

    // Layout follows screen width, not platform, so narrow web windows get the mobile UI

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        80,
      ),
      children: [
        // Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => ref.read(semesterGoalsProvider.notifier).toggleDone(goalId),
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
                    goal.isDone ? Icons.check : resolveCatIcon(cats, primaryCat),
                    color: catC,
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      decoration: goal.isDone ? TextDecoration.lineThrough : null,
                      color: goal.isDone ? AppColors.textTertiary : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (goal.categories.length > 1)
                    Wrap(
                      spacing: 4,
                      children: [for (final cat in goal.categories) _CategoryBadge(cat: cat, s: s)],
                    )
                  else
                    Text(
                      formatSemester(goal.semester, semSettings, s),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
                    ),
                  if (goal.categories.length <= 1)
                    const SizedBox.shrink()
                  else
                    Text(
                      formatSemester(goal.semester, semSettings, s),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.primary),
                    ),
                  if (goal.notes != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      goal.notes!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                  if (total > 0) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(s.goalProgress(done, total), style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: done / total,
                        minHeight: 6,
                        color: catC,
                        backgroundColor: AppColors.surfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),
        const Divider(),

        // Milestones
        _SectionHeader(label: s.milestones),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              kEmptyValue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ),
        SemMilestoneSubtreeView(parentId: goalId),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add, color: AppColors.primary),
          title: Text(s.addMilestone, style: const TextStyle(color: AppColors.primary)),
          onTap: () => showSemesterGoalSheet(context, ref, parentId: goalId),
        ),

        const Divider(),

        // Linked tasks
        _SectionHeader(label: s.linkedTasks),
        if (linkedTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              kEmptyValue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ),
        for (final task in linkedTasks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              task.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
              color: task.isCompleted ? AppColors.primary : AppColors.textSecondary,
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? AppColors.textTertiary : null,
              ),
            ),
            subtitle: task.content != null
                ? Text(
                    task.content!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.link_off, size: 18),
              color: AppColors.textTertiary,
              onPressed: () =>
                  ref.read(tasksProvider.notifier).update(task.copyWith(linkedTargetId: null)),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.add_link, color: AppColors.primary),
          title: Text(s.addLinkedTask, style: const TextStyle(color: AppColors.primary)),
          onTap: () => _showTaskSelectorForTarget(context, ref, goalId),
        ),

        // A milestone takes its context from its parent, so only top-level
        // goals show the vision link (matches showSemesterGoalSheet)
        if (goal.parentId == null) ...[
          const Divider(),

          // Linked future goal
          _SectionHeader(label: s.linkedFutureGoal),
          if (linkedGoal == null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                kEmptyValue,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_link, color: AppColors.primary),
              title: Text(s.addLinkedGoal, style: const TextStyle(color: AppColors.primary)),
              onTap: () => _showGoalSelectorForTarget(context, ref, goalId),
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.stars,
                color: resolveCatColor(
                  cats,
                  primaryCategoryOf(linkedGoal.categories),
                ),
              ),
              title: Text(linkedGoal.title),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.link_off, size: 18),
                    color: AppColors.textTertiary,
                    onPressed: () =>
                        ref.read(semesterGoalsProvider.notifier).linkFutureGoal(goalId, null),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textTertiary),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FutureGoalDetailScreen(goalId: linkedGoal.id)),
              ),
            ),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: s.editTarget,
            onPressed: () => showSemesterGoalSheet(context, ref, existing: goal),
          ),
        ],
      ),
      body: ResponsiveBody(child: content),
    );
  }
}

// ─── Recursive milestone tree ─────────────────────────────────────────────────

class SemMilestoneSubtreeView extends ConsumerWidget {
  final String parentId;
  final int depth;
  const SemMilestoneSubtreeView({super.key, required this.parentId, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(semesterGoalsProvider).where((g) => g.parentId == parentId).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final child in children) _SemMilestoneTile(milestone: child, depth: depth)],
    );
  }
}

class _SemMilestoneTile extends ConsumerWidget {
  final SemesterGoal milestone;
  final int depth;
  const _SemMilestoneTile({required this.milestone, required this.depth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allGoals = ref.watch(semesterGoalsProvider);
    final cats = ref.watch(categoriesProvider);
    final children = allGoals.where((g) => g.parentId == milestone.id).toList();
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final primaryCat = primaryCategoryOf(milestone.categories);
    final catC = resolveCatColor(cats, primaryCat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(left: (depth + 1) * 20.0, bottom: AppSpacing.xs),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SemesterGoalDetailScreen(goalId: milestone.id)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => ref.read(semesterGoalsProvider.notifier).toggleDone(milestone.id),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: catC.withValues(alpha: milestone.isDone ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        milestone.isDone ? Icons.check : resolveCatIcon(cats, primaryCat),
                        color: catC,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone.title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration: milestone.isDone ? TextDecoration.lineThrough : null,
                            color: milestone.isDone ? AppColors.textTertiary : null,
                          ),
                        ),
                        if (milestone.notes != null)
                          Text(
                            milestone.notes!,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (total > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            s.goalProgress(done, total),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            child: LinearProgressIndicator(
                              value: done / total,
                              minHeight: 3,
                              color: catC,
                              backgroundColor: AppColors.surfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () => showSemesterGoalSheet(context, ref, existing: milestone),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          if (await confirmDelete(context, s)) {
                            // Snapshot the whole subtree, not just the root
                            final removed = ref
                                .read(semesterGoalsProvider.notifier)
                                .remove(milestone.id);
                            final trash = ref.read(trashProvider.notifier);
                            for (final g in removed) {
                              trash.addSemesterGoal(g);
                            }
                          }
                        },
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textTertiary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SemMilestoneSubtreeView(parentId: milestone.id, depth: depth + 1),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(resolveCatIcon(cats, cat), size: 11, color: color),
          const SizedBox(width: 3),
          Text(catLabel(cat, s),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Selectors ────────────────────────────────────────────────────────────────

void _showTaskSelectorForTarget(BuildContext context, WidgetRef ref, String targetId) {
  final s = ref.read(stringsProvider);
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectTask),
      content: SizedBox(
        width: 400,
        child: Consumer(
          builder: (_, dlgRef, _) {
            final tasks = dlgRef.watch(tasksProvider);
            if (tasks.isEmpty) {
              return Text(s.noTasks, style: const TextStyle(color: AppColors.textTertiary));
            }
            return ListView(
              shrinkWrap: true,
              children: [
                for (final task in tasks)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      task.linkedTargetId == targetId
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: task.linkedTargetId == targetId
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        color: task.linkedTargetId == targetId ? AppColors.textTertiary : null,
                      ),
                    ),
                    enabled: task.linkedTargetId != targetId,
                    onTap: task.linkedTargetId == targetId
                        ? null
                        : () {
                            dlgRef
                                .read(tasksProvider.notifier)
                                .update(task.copyWith(linkedTargetId: targetId));
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

void _showGoalSelectorForTarget(BuildContext context, WidgetRef ref, String semGoalId) {
  final s = ref.read(stringsProvider);
  final current = ref.read(semesterGoalsProvider).where((g) => g.id == semGoalId).firstOrNull;
  final goals = ref.read(futureGoalsProvider).where((g) => g.parentId == null).toList();

  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectFutureGoal),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final goal in goals)
              ListTile(
                dense: true,
                leading: Icon(
                  current?.futureGoalId == goal.id
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: current?.futureGoalId == goal.id
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                title: Text(
                  goal.title,
                  style: TextStyle(
                    color: current?.futureGoalId == goal.id ? AppColors.textTertiary : null,
                  ),
                ),
                enabled: current?.futureGoalId != goal.id,
                onTap: current?.futureGoalId == goal.id
                    ? null
                    : () {
                        ref.read(semesterGoalsProvider.notifier).linkFutureGoal(semGoalId, goal.id);
                        Navigator.pop(dlgCtx);
                      },
              ),
          ],
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

// ─── Sheet helpers ────────────────────────────────────────────────────────────

// Which semester a target belongs to. A dialog rather than a dropdown so it
// matches the other pickers in the sheet
void _showSemesterPicker(
  BuildContext context,
  AppStrings s,
  List<String> semesters,
  SemesterSettings settings,
  String current,
  ValueChanged<String> onSelect,
) {
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.semester),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final sem in semesters)
              ListTile(
                dense: true,
                title: Text(formatSemester(sem, settings, s)),
                selected: sem == current,
                selectedColor: AppColors.primary,
                onTap: () {
                  onSelect(sem);
                  Navigator.pop(dlgCtx);
                },
              ),
          ],
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

Widget _goalLinkTile(
  BuildContext context,
  AppStrings s,
  FutureGoal? linked,
  // The linked vision's own category colour, so the tile says which vision this
  // is rather than just that there is one
  Color linkedColor,
  VoidCallback onTap,
  VoidCallback onClear,
) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: linked != null ? AppColors.borderFocus : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.stars_outlined,
            color: linked != null ? linkedColor : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.linkedFutureGoal,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  linked?.title ?? s.noLink,
                  style: TextStyle(
                    color: linked != null ? linkedColor : AppColors.textTertiary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (linked != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 18, color: AppColors.textTertiary),
            ),
        ],
      ),
    ),
  );
}

void _showFutureGoalSelectorForSheet(
  BuildContext context,
  List<FutureGoal> goals,
  AppStrings s,
  SemesterSettings settings,
  String? currentId,
  ValueChanged<String?> onSelect,
) {
  showSemesterGroupedPicker(
    context: context,
    title: s.selectFutureGoal,
    items: [
      for (final g in goals)
        SemesterPickerItem(
          id: g.id,
          title: g.title,
          semester: g.startSemester,
          parentId: g.parentId,
          sortOrder: g.sortOrder,
        ),
    ],
    currentId: currentId,
    currentSemester: currentSemester(settings),
    settings: settings,
    s: s,
    onSelect: onSelect,
  );
}

// ─── Public sheet functions ───────────────────────────────────────────────────

// One sheet for both modes: [existing] null means add, non-null means edit.
//
// The semester picker is edit-only on purpose: adding always lands in the
// semester currently being viewed. The vision link follows the same rule in
// both modes — top-level goals only.
void showSemesterGoalSheet(
  BuildContext context,
  WidgetRef ref, {
  SemesterGoal? existing,
  String? parentId,
}) {
  final isEdit = existing != null;
  final isTopLevel = isEdit ? existing.parentId == null : parentId == null;
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  final s = ref.read(stringsProvider);
  final settings = ref.read(semesterSettingsProvider);
  final semesters = generateSemesters(settings);
  var selectedCategories =
      isEdit ? existing.categories.toSet() : <String>{};
  String? selectedFutureGoalId = existing?.futureGoalId;
  String selectedSemester = existing?.semester ?? ref.read(selectedSemesterProvider);

  showAppSheet(
    context,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) {
        final futureGoals = ref.read(futureGoalsProvider);
        final linked = selectedFutureGoalId != null
            ? futureGoals.where((g) => g.id == selectedFutureGoalId).firstOrNull
            : null;

        void submit() {
          if (titleCtrl.text.trim().isEmpty) return;
          // No category is a valid answer; nothing is defaulted to "other"
          final cats = selectedCategories.toList();
          final notifier = ref.read(semesterGoalsProvider.notifier);
          final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
          // Touching a goal counts as using it, so it shows up in the task
          // sheet's suggestions (D16)
          final recent = ref.read(recentPicksProvider.notifier);
          if (isEdit) {
            notifier.updateGoal(
              existing.id,
              title: titleCtrl.text.trim(),
              semester: selectedSemester,
              categories: cats,
              futureGoalId: isTopLevel ? selectedFutureGoalId : null,
              notes: notes,
            );
            recent.rememberTarget(existing.id);
          } else {
            final newId = notifier.addGoal(
              titleCtrl.text.trim(),
              selectedSemester,
              parentId: parentId,
              categories: cats,
              futureGoalId: parentId != null ? null : selectedFutureGoalId,
              notes: notes,
            );
            recent.rememberTarget(newId);
          }
          Navigator.pop(sheetCtx);
        }

        return SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit
                    ? s.editTarget
                    : (parentId != null ? s.addMilestone : s.addTarget),
                style: Theme.of(sheetCtx).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              SheetTextField(
                label: s.titleField,
                controller: titleCtrl,
                autofocus: true,
                onSubmitted: submit,
              ),
              const SizedBox(height: AppSpacing.sm),
              // One short line at rest, growing to three
              SheetTextField(
                label: s.goalNotes,
                controller: notesCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                s.category,
                style: Theme.of(
                  sheetCtx,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              SheetCategoryChips(
                categories: ref.read(categoriesProvider),
                selected: selectedCategories,
                s: s,
                onToggle: (cat) => setState(() {
                  if (selectedCategories.contains(cat)) {
                    selectedCategories.remove(cat);
                  } else {
                    selectedCategories.add(cat);
                  }
                }),
              ),
              // Milestones inherit their parent's semester, so only top-level
              // goals get the picker
              if (isTopLevel) ...[
                const SizedBox(height: AppSpacing.md),
                SheetPickerBox(
                  label: s.semester,
                  value: formatSemester(selectedSemester, settings, s),
                  onTap: () => _showSemesterPicker(
                    sheetCtx,
                    s,
                    semesters,
                    settings,
                    selectedSemester,
                    (sem) => setState(() => selectedSemester = sem),
                  ),
                ),
              ],
              // Only top-level goals carry a vision link, in both modes
              if (isTopLevel) ...[
                const SizedBox(height: AppSpacing.md),
                _goalLinkTile(
                  sheetCtx,
                  s,
                  linked,
                  linked == null
                      ? AppColors.primary
                      : resolveCatColor(
                          ref.read(categoriesProvider),
                          primaryCategoryOf(linked.categories)),
                  () => _showFutureGoalSelectorForSheet(
                    context,
                    futureGoals,
                    s,
                    settings,
                    selectedFutureGoalId,
                    (id) => setState(() => selectedFutureGoalId = id),
                  ),
                  () => setState(() => selectedFutureGoalId = null),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submit,
                  child: Text(isEdit ? s.save : s.add),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

