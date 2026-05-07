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
import '../providers/trash_provider.dart';
import '../utils/category_helpers.dart';
import 'settings_screen.dart';

class SemesterScreen extends ConsumerWidget {
  const SemesterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final selectedSem = ref.watch(selectedSemesterProvider);
    final goals = ref.watch(semesterGoalsProvider)
        .where((g) => g.semester == selectedSem && g.parentId == null)
        .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal, AppSpacing.pageTop,
              AppSpacing.pageHorizontal, AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.appName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
          const _SemesterPicker(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: goals.isEmpty
                ? Center(
                    child: Text(s.noTargets,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textTertiary,
                        )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal, 0,
                      AppSpacing.pageHorizontal, 80,
                    ),
                    itemCount: goals.length,
                    itemBuilder: (ctx, i) => _GoalCard(goal: goals[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SemesterPicker extends ConsumerStatefulWidget {
  const _SemesterPicker();

  @override
  ConsumerState<_SemesterPicker> createState() => _SemesterPickerState();
}

class _SemesterPickerState extends ConsumerState<_SemesterPicker> {
  late final PageController _ctrl;
  List<String> _semesters = [];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(semesterSettingsProvider);
    _semesters = generateSemesters(settings);
    final cur = ref.read(selectedSemesterProvider);
    final idx = _semesters.indexOf(cur);
    _ctrl = PageController(
      viewportFraction: 0.28,
      initialPage: idx >= 0 ? idx : _semesters.length ~/ 2,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _jumpTo(String sem) {
    final idx = _semesters.indexOf(sem);
    if (idx >= 0) {
      _ctrl.animateToPage(idx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
    }
    ref.read(selectedSemesterProvider.notifier).state = sem;
  }

  void _pickSemester(BuildContext ctx) {
    final s = ref.read(stringsProvider);
    final currentSem = ref.read(selectedSemesterProvider);
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: Text(s.semester),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _semesters.length,
            itemBuilder: (_, i) {
              final sem = _semesters[i];
              return ListTile(
                title: Text(sem),
                selected: sem == currentSem,
                selectedColor: AppColors.primary,
                onTap: () {
                  _jumpTo(sem);
                  Navigator.pop(dlgCtx);
                },
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(semesterSettingsProvider);
    _semesters = generateSemesters(settings);
    final selected = ref.watch(selectedSemesterProvider);
    final curSem = currentSemester(settings);
    final s = ref.watch(stringsProvider);
    final isOnCurrentSem = selected == curSem;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: _semesters.length,
            onPageChanged: (i) =>
                ref.read(selectedSemesterProvider.notifier).state = _semesters[i],
            itemBuilder: (ctx, i) {
              final sem = _semesters[i];
              final isSelected = sem == selected;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isSelected ? () => _pickSemester(ctx) : () => _jumpTo(sem),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontSize: isSelected ? 17 : 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                        child: Text(sem),
                      ),
                      if (isSelected)
                        const Icon(Icons.arrow_drop_down,
                            size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!isOnCurrentSem)
          TextButton(
            onPressed: () => _jumpTo(curSem),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: Text(s.backToCurrentSem),
          ),
      ],
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final SemesterGoal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final allGoals = ref.watch(semesterGoalsProvider);
    final children = allGoals.where((g) => g.parentId == goal.id).toList();
    final notifier = ref.read(semesterGoalsProvider.notifier);
    final done = children.where((c) => c.isDone).length;
    final total = children.length;
    final progress = total > 0 ? done / total : 0.0;
    final catC = catColor(goal.category);

    final futureGoals = ref.watch(futureGoalsProvider);
    final linked = goal.futureGoalId != null
        ? futureGoals.where((g) => g.id == goal.futureGoalId).firstOrNull
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs,
        ),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: catC.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(catIcon(goal.category), color: catC, size: 20),
        ),
        title: Text(goal.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (linked != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '→ ${linked.title}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (goal.notes != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  goal.notes!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (total > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(s.goalProgress(done, total),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: catC,
                  backgroundColor: AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => _showEditGoalSheet(context, ref, goal),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () {
                ref.read(trashProvider.notifier).addSemesterGoal(goal);
                notifier.remove(goal.id);
              },
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12,
              ),
              child: Text(
                s.milestones,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          for (final child in children)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 12, right: 4),
              leading: GestureDetector(
                onTap: () => notifier.toggleDone(child.id),
                child: Icon(
                  child.isDone
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: child.isDone
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  size: 20,
                ),
              ),
              title: Text(
                child.title,
                style: TextStyle(
                  decoration:
                      child.isDone ? TextDecoration.lineThrough : null,
                  color: child.isDone ? AppColors.textTertiary : null,
                  fontSize: 14,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _showEditGoalSheet(context, ref, child),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ref
                          .read(trashProvider.notifier)
                          .addSemesterGoal(child);
                      notifier.remove(child.id);
                    },
                  ),
                ],
              ),
            ),
          ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            leading:
                const Icon(Icons.add, size: 20, color: AppColors.primary),
            title: Text(
              s.addMilestone,
              style: const TextStyle(color: AppColors.primary, fontSize: 14),
            ),
            onTap: () => showAddSemesterGoalSheet(context, ref,
                parentId: goal.id),
          ),
        ],
      ),
    );
  }
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

Widget _categoryChips(
  BuildContext context,
  AppStrings s,
  String selected,
  void Function(String) onSelect,
) {
  return Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final cat in FutureCategories.builtIns)
        FilterChip(
          label: Text(catLabel(cat, s)),
          selected: selected == cat,
          onSelected: (_) => onSelect(cat),
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
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
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

void showAddSemesterGoalSheet(BuildContext context, WidgetRef ref,
    {String? parentId}) {
  final semester = ref.read(selectedSemesterProvider);
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final s = ref.read(stringsProvider);
  var selectedCategory = FutureCategories.other;
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
          ref.read(semesterGoalsProvider.notifier).addGoal(
            titleCtrl.text.trim(),
            semester,
            parentId: parentId,
            category: selectedCategory,
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
                _categoryChips(sheetCtx, s, selectedCategory,
                    (cat) => setState(() => selectedCategory = cat)),
                if (parentId == null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _goalLinkTile(
                    sheetCtx, s, linked,
                    () => _showFutureGoalSelector(
                        context, ref, selectedFutureGoalId,
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

void _showEditGoalSheet(
    BuildContext context, WidgetRef ref, SemesterGoal goal) {
  final titleCtrl = TextEditingController(text: goal.title);
  final notesCtrl = TextEditingController(text: goal.notes ?? '');
  final s = ref.read(stringsProvider);
  var selectedCategory = goal.category;
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
          ref.read(semesterGoalsProvider.notifier).updateGoal(
            goal.id,
            title: titleCtrl.text.trim(),
            category: selectedCategory,
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
                _categoryChips(sheetCtx, s, selectedCategory,
                    (cat) => setState(() => selectedCategory = cat)),
                const SizedBox(height: AppSpacing.md),
                _goalLinkTile(
                  sheetCtx, s, linked,
                  () => _showFutureGoalSelector(
                      context, ref, selectedFutureGoalId,
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

void _showFutureGoalSelector(
  BuildContext context,
  WidgetRef ref,
  String? currentId,
  ValueChanged<String?> onSelect,
) {
  final s = ref.read(stringsProvider);
  final goals = ref.read(futureGoalsProvider);

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
