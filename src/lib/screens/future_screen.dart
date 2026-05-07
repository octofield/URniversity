import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/future_goal.dart';
import '../providers/custom_categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/category_helpers.dart';
import 'settings_screen.dart';

class FutureScreen extends ConsumerStatefulWidget {
  const FutureScreen({super.key});

  @override
  ConsumerState<FutureScreen> createState() => _FutureScreenState();
}

class _FutureScreenState extends ConsumerState<FutureScreen> {
  String? _catFilter;
  String? _semFilter;

  List<String> _semesterChips(SemesterSettings settings) {
    final all = generateSemesters(settings);
    final cur = currentSemester(settings);
    final idx = all.indexOf(cur);
    return idx >= 0 ? all.sublist(idx) : all;
  }

  void _showMoreSemesters(BuildContext context, SemesterSettings settings) {
    final s = ref.read(stringsProvider);
    final all = generateSemesters(settings);

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(s.semester),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(s.catAll),
                selected: _semFilter == null,
                selectedColor: AppColors.primary,
                onTap: () {
                  setState(() => _semFilter = null);
                  Navigator.pop(dlgCtx);
                },
              ),
              for (final sem in all)
                ListTile(
                  title: Text(sem),
                  selected: sem == _semFilter,
                  selectedColor: AppColors.primary,
                  onTap: () {
                    setState(() => _semFilter = sem);
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

  void _showMoreCategories(BuildContext context) {
    final s = ref.read(stringsProvider);
    final addCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) {
          final customCats = ref.read(customCategoriesProvider);

          return AlertDialog(
            title: Text(s.category),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.select_all,
                              color: AppColors.textTertiary),
                          title: Text(s.catAll),
                          selected: _catFilter == null,
                          selectedColor: AppColors.primary,
                          onTap: () {
                            setState(() => _catFilter = null);
                            Navigator.pop(dlgCtx);
                          },
                        ),
                        for (final cat in FutureCategories.builtIns)
                          ListTile(
                            leading: Icon(catIcon(cat), color: catColor(cat)),
                            title: Text(catLabel(cat, s)),
                            selected: _catFilter == cat,
                            selectedColor: AppColors.primary,
                            onTap: () {
                              setState(() =>
                                  _catFilter = _catFilter == cat ? null : cat);
                              Navigator.pop(dlgCtx);
                            },
                          ),
                        for (final cat in customCats)
                          ListTile(
                            leading: const Icon(Icons.label_outline,
                                color: AppColors.categoryOther),
                            title: Text(cat),
                            selected: _catFilter == cat,
                            selectedColor: AppColors.primary,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () {
                                ref
                                    .read(customCategoriesProvider.notifier)
                                    .remove(cat);
                                if (_catFilter == cat) {
                                  setState(() => _catFilter = null);
                                }
                                setDlgState(() {});
                              },
                            ),
                            onTap: () {
                              setState(() =>
                                  _catFilter = _catFilter == cat ? null : cat);
                              Navigator.pop(dlgCtx);
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addCtrl,
                          decoration: InputDecoration(hintText: s.categoryName),
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) {
                            final name = addCtrl.text.trim();
                            if (name.isEmpty) return;
                            ref.read(customCategoriesProvider.notifier).add(name);
                            addCtrl.clear();
                            setDlgState(() {});
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, color: AppColors.primary),
                        onPressed: () {
                          final name = addCtrl.text.trim();
                          if (name.isEmpty) return;
                          ref.read(customCategoriesProvider.notifier).add(name);
                          addCtrl.clear();
                          setDlgState(() {});
                        },
                      ),
                    ],
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(semesterSettingsProvider);
    final goals = ref.watch(futureGoalsProvider);
    final semChips = _semesterChips(settings);
    final customCats = ref.watch(customCategoriesProvider);
    final allCats = [...FutureCategories.builtIns, ...customCats];

    final filtered = goals.where((g) {
      final semOk = _semFilter == null || g.startSemester == _semFilter;
      final catOk = _catFilter == null || g.category == _catFilter;
      return semOk && catOk;
    }).toList();

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
          // Semester filter — adaptive (no scroll, 更多 pinned right)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal, vertical: 4),
            child: _AdaptiveChipRow(
              allChip: _FilterChip(
                label: s.catAll,
                selected: _semFilter == null,
                onTap: () => setState(() => _semFilter = null),
              ),
              chips: [
                for (final sem in semChips)
                  _FilterChip(
                    label: sem,
                    selected: _semFilter == sem,
                    onTap: () => setState(
                        () => _semFilter = _semFilter == sem ? null : sem),
                  ),
              ],
              trailing: ActionChip(
                avatar: const Icon(Icons.expand_more, size: 16),
                label: Text(s.more),
                onPressed: () => _showMoreSemesters(context, settings),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          // Category filter — adaptive
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal, vertical: 4),
            child: _AdaptiveChipRow(
              allChip: _FilterChip(
                label: s.catAll,
                selected: _catFilter == null,
                onTap: () => setState(() => _catFilter = null),
              ),
              chips: [
                for (final cat in allCats)
                  _FilterChip(
                    label: catLabel(cat, s),
                    selected: _catFilter == cat,
                    onTap: () => setState(
                        () => _catFilter = _catFilter == cat ? null : cat),
                  ),
              ],
              trailing: ActionChip(
                avatar: const Icon(Icons.tune, size: 16),
                label: Text(s.more),
                onPressed: () => _showMoreCategories(context),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(s.noGoals,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textTertiary,
                        )),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal, 0,
                      AppSpacing.pageHorizontal, 80,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _GoalCard(goal: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// Adaptive chip row: shows "all" chip + as many other chips as fit, then trailing
class _AdaptiveChipRow extends StatelessWidget {
  final Widget allChip;
  final List<Widget> chips;
  final Widget trailing;

  const _AdaptiveChipRow({
    required this.allChip,
    required this.chips,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        allChip,
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final chip in chips) ...[
                  chip,
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        trailing,
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _GoalCard extends ConsumerWidget {
  final FutureGoal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final notifier = ref.read(futureGoalsProvider.notifier);
    final total = goal.subgoals.length;
    final done = goal.completedCount;
    final progress = total > 0 ? done / total : 0.0;
    final catC = catColor(goal.category);

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
        title: Text(
          goal.title,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goal.startSemester != null || goal.endSemester != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Text(
                  [
                    if (goal.startSemester != null) goal.startSemester!,
                    if (goal.startSemester != null && goal.endSemester != null) '→',
                    if (goal.endSemester != null) goal.endSemester!,
                  ].join(' '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            if (goal.notes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
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
              const SizedBox(height: 2),
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
              onPressed: () => notifier.removeGoal(goal.id),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (goal.subgoals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12,
              ),
              child: Text(
                s.subgoals,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          for (final sg in goal.subgoals)
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              value: sg.isDone,
              onChanged: (_) => notifier.toggleSubgoal(goal.id, sg.id),
              title: Text(
                sg.title,
                style: TextStyle(
                  decoration: sg.isDone ? TextDecoration.lineThrough : null,
                  color: sg.isDone ? AppColors.textTertiary : null,
                ),
              ),
              secondary: IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => notifier.removeSubgoal(goal.id, sg.id),
              ),
            ),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            leading: const Icon(Icons.add, size: 20, color: AppColors.primary),
            title: Text(s.addSubgoal,
                style: const TextStyle(color: AppColors.primary, fontSize: 14)),
            onTap: () => _showAddSubgoalDialog(context, ref, goal.id),
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

// Semester dropdown that only shows semesters after (or equal to) a given start
Widget _semesterDropdown({
  required String? value,
  required List<String> semesters,
  required String label,
  required String? minSemester,
  required void Function(String?) onChanged,
}) {
  final valid = minSemester == null
      ? semesters
      : semesters.where((s) => compareSemesters(s, minSemester) >= 0).toList();

  return DropdownButtonFormField<String?>(
    initialValue: value,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: [
      const DropdownMenuItem(value: null, child: Text('—')),
      for (final sem in valid) DropdownMenuItem(value: sem, child: Text(sem)),
    ],
    onChanged: onChanged,
  );
}

// Public — called from HomeScreen FAB
void showAddFutureGoalSheet(BuildContext context, WidgetRef ref,
    {String? defaultSemester}) {
  final titleCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final s = ref.read(stringsProvider);
  final settings = ref.read(semesterSettingsProvider);
  final customCats = ref.read(customCategoriesProvider);
  final semesters = generateSemesters(settings);
  final allCats = [...FutureCategories.builtIns, ...customCats];

  var selectedCategory = FutureCategories.other;
  String? startSemester = defaultSemester ?? currentSemester(settings);
  String? endSemester;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetDragHandle(),
              const SizedBox(height: AppSpacing.lg),
              Text(s.addGoal, style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s.titleField),
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
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final cat in allCats)
                    FilterChip(
                      label: Text(catLabel(cat, s)),
                      selected: selectedCategory == cat,
                      onSelected: (_) => setState(() => selectedCategory = cat),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _semesterDropdown(
                      value: startSemester,
                      semesters: semesters,
                      label: s.startSemester,
                      minSemester: null,
                      onChanged: (v) => setState(() {
                        startSemester = v;
                        // Reset end if it's before new start
                        if (endSemester != null && startSemester != null &&
                            compareSemesters(endSemester!, startSemester!) < 0) {
                          endSemester = null;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _semesterDropdown(
                      value: endSemester,
                      semesters: semesters,
                      label: s.endSemester,
                      minSemester: startSemester,
                      onChanged: (v) => setState(() => endSemester = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    ref.read(futureGoalsProvider.notifier).addGoal(
                      title: titleCtrl.text.trim(),
                      category: selectedCategory,
                      startSemester: startSemester,
                      endSemester: endSemester,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(s.add),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showEditGoalSheet(BuildContext context, WidgetRef ref, FutureGoal goal) {
  final titleCtrl = TextEditingController(text: goal.title);
  final notesCtrl = TextEditingController(text: goal.notes ?? '');
  final s = ref.read(stringsProvider);
  final settings = ref.read(semesterSettingsProvider);
  final customCats = ref.read(customCategoriesProvider);
  final semesters = generateSemesters(settings);
  final allCats = [...FutureCategories.builtIns, ...customCats];

  var selectedCategory = goal.category;
  String? startSemester = goal.startSemester;
  String? endSemester = goal.endSemester;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setState) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSpacing.pageHorizontal,
            right: AppSpacing.pageHorizontal,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetDragHandle(),
              const SizedBox(height: AppSpacing.lg),
              Text(s.editGoal, style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: s.titleField),
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
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final cat in allCats)
                    FilterChip(
                      label: Text(catLabel(cat, s)),
                      selected: selectedCategory == cat,
                      onSelected: (_) => setState(() => selectedCategory = cat),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _semesterDropdown(
                      value: startSemester,
                      semesters: semesters,
                      label: s.startSemester,
                      minSemester: null,
                      onChanged: (v) => setState(() {
                        startSemester = v;
                        if (endSemester != null && startSemester != null &&
                            compareSemesters(endSemester!, startSemester!) < 0) {
                          endSemester = null;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _semesterDropdown(
                      value: endSemester,
                      semesters: semesters,
                      label: s.endSemester,
                      minSemester: startSemester,
                      onChanged: (v) => setState(() => endSemester = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    ref.read(futureGoalsProvider.notifier).updateGoal(
                      goal.id,
                      title: titleCtrl.text.trim(),
                      category: selectedCategory,
                      startSemester: startSemester,
                      endSemester: endSemester,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                    Navigator.pop(sheetCtx);
                  },
                  child: Text(s.save),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showAddSubgoalDialog(BuildContext context, WidgetRef ref, String goalId) {
  final ctrl = TextEditingController();
  final s = ref.read(stringsProvider);

  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.addSubgoal),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: s.titleField),
        onSubmitted: (_) {
          if (ctrl.text.trim().isEmpty) return;
          ref.read(futureGoalsProvider.notifier).addSubgoal(goalId, ctrl.text.trim());
          Navigator.pop(dlgCtx);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dlgCtx),
          child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (ctrl.text.trim().isEmpty) return;
            ref.read(futureGoalsProvider.notifier).addSubgoal(goalId, ctrl.text.trim());
            Navigator.pop(dlgCtx);
          },
          child: Text(s.add),
        ),
      ],
    ),
  );
}
