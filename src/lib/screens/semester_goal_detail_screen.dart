import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import 'future_goal_detail_screen.dart';

class SemesterGoalDetailScreen extends ConsumerWidget {
  final String goalId;
  const SemesterGoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final goal = ref.watch(semesterGoalsProvider)
        .where((g) => g.id == goalId)
        .firstOrNull;

    if (goal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.pop(context);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final children = ref.watch(semesterGoalsProvider)
        .where((g) => g.parentId == goalId)
        .toList();
    final linkedTasks = ref.watch(tasksProvider)
        .where((t) => t.linkedTargetId == goalId)
        .toList();
    final linkedGoal = goal.futureGoalId != null
        ? ref.watch(futureGoalsProvider)
            .where((g) => g.id == goal.futureGoalId)
            .firstOrNull
        : null;

    final primaryCat = goal.categories.isNotEmpty ? goal.categories.first : 'other';
    final catC = catColor(primaryCat);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: s.editTarget,
            onPressed: () => showEditSemesterGoalSheet(context, ref, goal),
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
                    const SizedBox(height: 4),
                    if (goal.categories.length > 1)
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final cat in goal.categories)
                            _CategoryBadge(cat: cat, s: s),
                        ],
                      )
                    else
                      Text(goal.semester,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.primary)),
                    if (goal.categories.length <= 1)
                      const SizedBox.shrink()
                    else
                      Text(goal.semester,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.primary)),
                    if (goal.notes != null) ...[
                      const SizedBox(height: 4),
                      Text(goal.notes!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary)),
                    ],
                    if (total > 0) ...[
                      const SizedBox(height: 8),
                      Text(s.goalProgress(done, total),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
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
              child: Text('—',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textTertiary)),
            ),
          SemMilestoneSubtreeView(parentId: goalId),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add, color: AppColors.primary),
            title: Text(s.addMilestone,
                style: const TextStyle(color: AppColors.primary)),
            onTap: () => showAddSemesterGoalSheet(context, ref, parentId: goalId),
          ),

          const Divider(),

          // Linked tasks
          _SectionHeader(label: s.linkedTasks),
          if (linkedTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('—',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textTertiary)),
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
              title: Text(task.title,
                  style: TextStyle(
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                    color: task.isCompleted ? AppColors.textTertiary : null,
                  )),
              subtitle: task.content != null
                  ? Text(task.content!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.link_off, size: 18),
                color: AppColors.textTertiary,
                onPressed: () => ref.read(tasksProvider.notifier).update(
                  task.copyWith(linkedTargetId: null),
                ),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_link, color: AppColors.primary),
            title: Text(s.addLinkedTask,
                style: const TextStyle(color: AppColors.primary)),
            onTap: () => _showTaskSelectorForTarget(context, ref, goalId),
          ),

          const Divider(),

          // Linked future goal
          _SectionHeader(label: s.linkedFutureGoal),
          if (linkedGoal == null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('—',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textTertiary)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_link, color: AppColors.primary),
              title: Text(s.addLinkedGoal,
                  style: const TextStyle(color: AppColors.primary)),
              onTap: () => _showGoalSelectorForTarget(context, ref, goalId),
            ),
          ] else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.stars,
                  color: catColor(linkedGoal.categories.isNotEmpty
                      ? linkedGoal.categories.first
                      : FutureCategories.other)),
              title: Text(linkedGoal.title),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.link_off, size: 18),
                    color: AppColors.textTertiary,
                    onPressed: () => ref
                        .read(semesterGoalsProvider.notifier)
                        .linkFutureGoal(goalId, null),
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 12, color: AppColors.textTertiary),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FutureGoalDetailScreen(goalId: linkedGoal.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Recursive milestone tree ─────────────────────────────────────────────────

class SemMilestoneSubtreeView extends ConsumerWidget {
  final String parentId;
  final int depth;
  const SemMilestoneSubtreeView({
    super.key,
    required this.parentId,
    this.depth = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(semesterGoalsProvider)
        .where((g) => g.parentId == parentId)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final child in children)
          _SemMilestoneTile(milestone: child, depth: depth),
      ],
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
    final children = allGoals.where((g) => g.parentId == milestone.id).toList();
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final primaryCat =
        milestone.categories.isNotEmpty ? milestone.categories.first : 'other';
    final catC = catColor(primaryCat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: (depth + 1) * 20.0,
            bottom: AppSpacing.xs,
          ),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SemesterGoalDetailScreen(goalId: milestone.id),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => ref
                        .read(semesterGoalsProvider.notifier)
                        .toggleDone(milestone.id),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: catC.withValues(
                            alpha: milestone.isDone ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        milestone.isDone ? Icons.check : catIcon(primaryCat),
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: milestone.isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: milestone.isDone
                                ? AppColors.textTertiary
                                : null,
                          ),
                        ),
                        if (milestone.notes != null)
                          Text(
                            milestone.notes!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (total > 0) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(s.goalProgress(done, total),
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
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
                        onPressed: () =>
                            showEditSemesterGoalSheet(context, ref, milestone),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          if (await _confirmDelete(context, s)) {
                            ref
                                .read(trashProvider.notifier)
                                .addSemesterGoal(milestone);
                            ref
                                .read(semesterGoalsProvider.notifier)
                                .remove(milestone.id);
                          }
                        },
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          size: 12, color: AppColors.textTertiary),
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

class _CategoryBadge extends StatelessWidget {
  final String cat;
  final dynamic s;
  const _CategoryBadge({required this.cat, required this.s});

  @override
  Widget build(BuildContext context) {
    final color = catColor(cat);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(catIcon(cat), size: 11, color: color),
          const SizedBox(width: 3),
          Text(catLabel(cat, s), style: TextStyle(fontSize: 11, color: color)),
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
      child: Text(label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          )),
    );
  }
}

// ─── Selectors ────────────────────────────────────────────────────────────────

void _showTaskSelectorForTarget(
    BuildContext context, WidgetRef ref, String targetId) {
  final s = ref.read(stringsProvider);
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectTask),
      content: SizedBox(
        width: double.maxFinite,
        child: Consumer(
          builder: (_, dlgRef, _) {
            final tasks = dlgRef.watch(tasksProvider);
            if (tasks.isEmpty) {
              return Text(s.noTasks,
                  style: const TextStyle(color: AppColors.textTertiary));
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
                    title: Text(task.title,
                        style: TextStyle(
                          color: task.linkedTargetId == targetId
                              ? AppColors.textTertiary
                              : null,
                        )),
                    enabled: task.linkedTargetId != targetId,
                    onTap: task.linkedTargetId == targetId
                        ? null
                        : () {
                            dlgRef.read(tasksProvider.notifier).update(
                              task.copyWith(linkedTargetId: targetId),
                            );
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

void _showGoalSelectorForTarget(
    BuildContext context, WidgetRef ref, String semGoalId) {
  final s = ref.read(stringsProvider);
  final current =
      ref.read(semesterGoalsProvider).where((g) => g.id == semGoalId).firstOrNull;
  final goals = ref.read(futureGoalsProvider)
      .where((g) => g.parentId == null)
      .toList();

  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectFutureGoal),
      content: SizedBox(
        width: double.maxFinite,
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
                title: Text(goal.title,
                    style: TextStyle(
                      color: current?.futureGoalId == goal.id
                          ? AppColors.textTertiary
                          : null,
                    )),
                enabled: current?.futureGoalId != goal.id,
                onTap: current?.futureGoalId == goal.id
                    ? null
                    : () {
                        ref
                            .read(semesterGoalsProvider.notifier)
                            .linkFutureGoal(semGoalId, goal.id);
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

Future<bool> _confirmDelete(BuildContext context, AppStrings s) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text('${s.delete}？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: Text(s.delete),
        ),
      ],
    ),
  ) ?? false;
}

Widget _sheetDragHandle() => Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
    );

Widget _categoryChipsMulti(
  BuildContext context,
  AppStrings s,
  Set<String> selected,
  void Function(String) onToggle,
) {
  return Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final cat in FutureCategories.builtIns)
        FilterChip(
          label: Text(catLabel(cat, s)),
          selected: selected.contains(cat),
          onSelected: (_) => onToggle(cat),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 2),
        ),
    ],
  );
}

Widget _goalLinkTile(
  BuildContext context,
  AppStrings s,
  FutureGoal? linked,
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
        border: Border.all(
          color: linked != null ? AppColors.borderFocus : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.stars_outlined,
            color: linked != null ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  s.linkedFutureGoal,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  linked?.title ?? s.noLink,
                  style: TextStyle(
                    color: linked != null
                        ? AppColors.primary
                        : AppColors.textTertiary,
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
              child: const Icon(Icons.close,
                  size: 18, color: AppColors.textTertiary),
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
  String? currentId,
  ValueChanged<String?> onSelect,
) {
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectFutureGoal),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(s.noLink),
              selected: currentId == null,
              selectedColor: AppColors.primary,
              onTap: () {
                onSelect(null);
                Navigator.pop(dlgCtx);
              },
            ),
            for (final g in goals)
              ListTile(
                title: Text(g.title),
                subtitle:
                    g.startSemester != null ? Text(g.startSemester!) : null,
                selected: g.id == currentId,
                selectedColor: AppColors.primary,
                onTap: () {
                  onSelect(g.id);
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

// ─── Public sheet functions ───────────────────────────────────────────────────

void showAddSemesterGoalSheet(BuildContext context, WidgetRef ref,
    {String? parentId}) {
  final semester = ref.read(selectedSemesterProvider);
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final s = ref.read(stringsProvider);
  var selectedCategories = <String>{};
  String? selectedFutureGoalId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) {
        final futureGoals = ref.read(futureGoalsProvider);
        final linked = selectedFutureGoalId != null
            ? futureGoals
                .where((g) => g.id == selectedFutureGoalId)
                .firstOrNull
            : null;

        void submit() {
          if (titleCtrl.text.trim().isEmpty) return;
          final cats = selectedCategories.isEmpty
              ? ['other']
              : selectedCategories.toList();
          ref.read(semesterGoalsProvider.notifier).addGoal(
            titleCtrl.text.trim(),
            semester,
            parentId: parentId,
            categories: cats,
            futureGoalId: parentId != null ? null : selectedFutureGoalId,
            notes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          );
          Navigator.pop(sheetCtx);
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.lg,
              bottom:
                  MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetDragHandle(),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  parentId != null ? s.addMilestone : s.addTarget,
                  style: Theme.of(sheetCtx).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: s.titleField),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: s.goalNotes,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(s.category,
                    style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    )),
                const SizedBox(height: AppSpacing.xs),
                _categoryChipsMulti(sheetCtx, s, selectedCategories,
                    (cat) => setState(() {
                      if (selectedCategories.contains(cat)) {
                        selectedCategories.remove(cat);
                      } else {
                        selectedCategories.add(cat);
                      }
                    })),
                if (parentId == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _goalLinkTile(
                    sheetCtx, s, linked,
                    () => _showFutureGoalSelectorForSheet(
                        context, futureGoals, s, selectedFutureGoalId,
                        (id) => setState(() => selectedFutureGoalId = id)),
                    () => setState(() => selectedFutureGoalId = null),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: submit,
                    child: Text(s.add),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void showEditSemesterGoalSheet(
    BuildContext context, WidgetRef ref, SemesterGoal goal) {
  final titleCtrl = TextEditingController(text: goal.title);
  final notesCtrl = TextEditingController(text: goal.notes ?? '');
  final s = ref.read(stringsProvider);
  var selectedCategories = goal.categories.toSet();
  String? selectedFutureGoalId = goal.futureGoalId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) {
        final futureGoals = ref.read(futureGoalsProvider);
        final linked = selectedFutureGoalId != null
            ? futureGoals
                .where((g) => g.id == selectedFutureGoalId)
                .firstOrNull
            : null;

        void submit() {
          if (titleCtrl.text.trim().isEmpty) return;
          final cats = selectedCategories.isEmpty
              ? ['other']
              : selectedCategories.toList();
          ref.read(semesterGoalsProvider.notifier).updateGoal(
            goal.id,
            title: titleCtrl.text.trim(),
            categories: cats,
            futureGoalId: selectedFutureGoalId,
            notes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          );
          Navigator.pop(sheetCtx);
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.lg,
              bottom:
                  MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sheetDragHandle(),
                const SizedBox(height: AppSpacing.lg),
                Text(s.editTarget,
                    style: Theme.of(sheetCtx).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: s.titleField),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: s.goalNotes,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(s.category,
                    style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    )),
                const SizedBox(height: AppSpacing.xs),
                _categoryChipsMulti(sheetCtx, s, selectedCategories,
                    (cat) => setState(() {
                      if (selectedCategories.contains(cat)) {
                        selectedCategories.remove(cat);
                      } else {
                        selectedCategories.add(cat);
                      }
                    })),
                const SizedBox(height: AppSpacing.md),
                _goalLinkTile(
                  sheetCtx, s, linked,
                  () => _showFutureGoalSelectorForSheet(
                      context, futureGoals, s, selectedFutureGoalId,
                      (id) => setState(() => selectedFutureGoalId = id)),
                  () => setState(() => selectedFutureGoalId = null),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: submit,
                    child: Text(s.save),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
