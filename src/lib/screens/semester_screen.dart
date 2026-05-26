import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/semester_goal.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trash_provider.dart';
import '../l10n/app_strings.dart';
import '../utils/category_helpers.dart';
import 'semester_goal_detail_screen.dart';
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
    final primaryCat = goal.categories.isNotEmpty ? goal.categories.first : 'other';
    final catC = catColor(primaryCat);
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
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SemesterGoalDetailScreen(goalId: goal.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: catC.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(catIcon(primaryCat), color: catC, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (linked != null)
                      Text(
                        '→ ${linked.title}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (goal.notes != null)
                      Text(
                        goal.notes!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (total > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(s.goalProgress(done, total),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: done / total,
                          minHeight: 4,
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
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () =>
                        showEditSemesterGoalSheet(context, ref, goal),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      final s = ref.read(stringsProvider);
                      if (await _confirmDelete(context, s)) {
                        ref.read(trashProvider.notifier).addSemesterGoal(goal);
                        notifier.remove(goal.id);
                      }
                    },
                  ),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.textTertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
