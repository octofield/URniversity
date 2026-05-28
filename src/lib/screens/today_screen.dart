import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/date_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/future_goals_provider.dart';
import 'settings_screen.dart';

class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
  }

  DateTime _mondayOf(DateTime date) {
    final offset = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - offset);
  }

  void _prevWeek() => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
  void _nextWeek() => setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));

  bool get _isCurrentWeek {
    final today = DateTime.now();
    final monday = _mondayOf(today);
    return _weekStart.year == monday.year &&
        _weekStart.month == monday.month &&
        _weekStart.day == monday.day;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final taskView = ref.watch(taskViewProvider);
    final selectedDate = ref.watch(dateProvider);
    final dateFormat = ref.watch(settingsProvider);
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal, AppSpacing.pageTop,
              AppSpacing.pageHorizontal, 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0, AppSpacing.pageHorizontal, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ViewToggleLabel(label: s.allTasks, active: taskView == 0,
                    onTap: () => ref.read(taskViewProvider.notifier).state = 0),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('/', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                ),
                _ViewToggleLabel(label: s.dailyTasks, active: taskView == 1,
                    onTap: () => ref.read(taskViewProvider.notifier).state = 1),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('/', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                ),
                _ViewToggleLabel(label: s.weeklyTasks, active: taskView == 2,
                    onTap: () => ref.read(taskViewProvider.notifier).state = 2),
              ],
            ),
          ),
          if (taskView == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref.read(dateProvider.notifier).prev(),
                  ),
                  Text(
                    formatDate(selectedDate, dateFormat),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref.read(dateProvider.notifier).next(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        ref.read(dateProvider.notifier).setDate(picked);
                      }
                    },
                  ),
                  if (!isToday)
                    TextButton(
                      onPressed: () => ref.read(dateProvider.notifier).goToToday(),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      ),
                      child: Text(s.backToToday),
                    ),
                ],
              ),
            ),
          if (taskView == 2)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal - 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    visualDensity: VisualDensity.compact,
                    onPressed: _prevWeek,
                  ),
                  Expanded(
                    child: Text(
                      '${_weekStart.month}/${_weekStart.day} – ${weekEnd.month}/${weekEnd.day}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    visualDensity: VisualDensity.compact,
                    onPressed: _nextWeek,
                  ),
                  if (!_isCurrentWeek)
                    TextButton(
                      onPressed: () {
                        setState(() => _weekStart = _mondayOf(DateTime.now()));
                        ref.read(dateProvider.notifier).goToToday();
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      ),
                      child: Text(s.backToToday),
                    ),
                ],
              ),
            ),
          Expanded(
            child: taskView == 2
                ? _WeeklyGrid(weekStart: _weekStart)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal, 12,
                      AppSpacing.pageHorizontal, AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _SummaryCard(),
                        SizedBox(height: AppSpacing.lg),
                        _TasksSection(),
                        SizedBox(height: AppSpacing.lg),
                        _CompletedTasksSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleLabel extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggleLabel({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          color: active ? AppColors.primary : AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _WeeklyGrid extends ConsumerStatefulWidget {
  final DateTime weekStart;
  const _WeeklyGrid({required this.weekStart});

  @override
  ConsumerState<_WeeklyGrid> createState() => _WeeklyGridState();
}

class _WeeklyGridState extends ConsumerState<_WeeklyGrid> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToDay(int index) {
    if (!_scrollCtrl.hasClients) return;
    const colWidth = 130.0;
    const gap = 8.0;
    const hPad = AppSpacing.pageHorizontal;
    final viewportWidth = MediaQuery.of(context).size.width;
    final target = hPad + index * (colWidth + gap) + colWidth / 2 - viewportWidth / 2;
    _scrollCtrl.animateTo(
      target.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dateProvider, (_, next) {
      final dayIndex = next.difference(widget.weekStart).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToDay(dayIndex));
      }
    });

    return SingleChildScrollView(
      controller: _scrollCtrl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 8, AppSpacing.pageHorizontal, 80),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < 7; i++)
            _DayColumn(date: widget.weekStart.add(Duration(days: i))),
        ],
      ),
    );
  }
}

class _DayColumn extends ConsumerWidget {
  final DateTime date;
  const _DayColumn({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final normalDate = DateTime(date.year, date.month, date.day);
    final tasks = ref.watch(tasksForDateProvider(normalDate));
    final selectedDate = ref.watch(dateProvider);
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isFocused = date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day;
    final headerColor = isToday ? AppColors.primary : (isFocused ? AppColors.primary : AppColors.textTertiary);

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: (isToday || isFocused) ? AppColors.primary : AppColors.border,
          width: (isToday || isFocused) ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => ref.read(dateProvider.notifier).setDate(normalDate),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.weekdayShort(date.weekday),
                    style: TextStyle(fontSize: 11, color: headerColor),
                  ),
                  Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: (isToday || isFocused) ? FontWeight.bold : FontWeight.normal,
                      color: headerColor,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text('–', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              )
            else
              for (final task in tasks)
                _WeekTaskTile(task: task, date: normalDate),
          ],
        ),
      ),
    );
  }
}

class _WeekTaskTile extends ConsumerWidget {
  final Task task;
  final DateTime date;
  const _WeekTaskTile({required this.task, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = task.isCompletedOn(date);
    return InkWell(
      onTap: () => _showEditTaskSheet(context, ref, task),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isCompleted,
                onChanged: (_) => ref.read(tasksProvider.notifier).toggleOnDate(task.id, date),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 12,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? AppColors.textTertiary : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final tasks = ref.watch(filteredTasksProvider);
    final date = ref.watch(dateProvider);
    final completed = tasks.where((t) => t.isCompletedOn(date)).length;
    final total = tasks.length;
    final allDone = total > 0 && completed == total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone ? Icons.check_circle : Icons.check_circle_outline,
                color: allDone ? AppColors.primary : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                s.tasksCompleted(completed, total),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: completed / total,
                minHeight: 6,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final date = ref.watch(dateProvider);
    final taskView = ref.watch(taskViewProvider);
    final targetFilter = ref.watch(taskTargetFilterProvider);
    final goalFilter = ref.watch(taskGoalFilterProvider);
    final isFiltered = targetFilter.isNotEmpty || goalFilter.isNotEmpty;
    final expandedTargetFilter = _expandSemGoalIds(targetFilter, ref.watch(semesterGoalsProvider));
    final expandedGoalFilter = _expandFutureGoalIds(goalFilter, ref.watch(futureGoalsProvider));
    final tasks = ref.watch(filteredTasksProvider)
        .where((t) => !t.isCompletedOn(date) && _passesFilter(t, expandedTargetFilter, expandedGoalFilter))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(s.tasks, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (taskView == 0)
              IconButton(
                icon: Icon(
                  isFiltered ? Icons.filter_list : Icons.filter_list_outlined,
                  color: isFiltered ? AppColors.primary : AppColors.textTertiary,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => _showTaskFilterDialog(context, ref, s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: tasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 20,
                  ),
                  child: Text(
                    s.noTasks,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final task in tasks) ...[
                      _TaskTile(task: task),
                      const Divider(height: 1, indent: 56),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

bool _passesFilter(Task t, Set<String> targetIds, Set<String> goalIds) {
  if (targetIds.isEmpty && goalIds.isEmpty) return true;
  if (targetIds.isNotEmpty && t.linkedTargetId != null && targetIds.contains(t.linkedTargetId)) return true;
  if (goalIds.isNotEmpty && t.linkedGoalId != null && goalIds.contains(t.linkedGoalId)) return true;
  return false;
}

Set<String> _expandSemGoalIds(Set<String> selected, List<SemesterGoal> all) {
  if (selected.isEmpty) return selected;
  final expanded = Set<String>.from(selected);
  void collect(String parentId) {
    for (final g in all.where((g) => g.parentId == parentId)) {
      if (expanded.add(g.id)) collect(g.id);
    }
  }
  for (final id in List<String>.from(selected)) { collect(id); }
  return expanded;
}

Set<String> _expandFutureGoalIds(Set<String> selected, List<FutureGoal> all) {
  if (selected.isEmpty) return selected;
  final expanded = Set<String>.from(selected);
  void collect(String parentId) {
    for (final g in all.where((g) => g.parentId == parentId)) {
      if (expanded.add(g.id)) collect(g.id);
    }
  }
  for (final id in List<String>.from(selected)) { collect(id); }
  return expanded;
}

List<({SemesterGoal goal, int depth})> _buildTargetTree(List<SemesterGoal> all) {
  final result = <({SemesterGoal goal, int depth})>[];
  void add(String? parentId, int depth) {
    for (final g in all.where((g) => g.parentId == parentId)) {
      result.add((goal: g, depth: depth));
      add(g.id, depth + 1);
    }
  }
  add(null, 0);
  return result;
}

List<({FutureGoal goal, int depth})> _buildGoalTree(List<FutureGoal> all) {
  final result = <({FutureGoal goal, int depth})>[];
  void add(String? parentId, int depth) {
    for (final g in all.where((g) => g.parentId == parentId)) {
      result.add((goal: g, depth: depth));
      add(g.id, depth + 1);
    }
  }
  add(null, 0);
  return result;
}

void _showTaskFilterDialog(BuildContext context, WidgetRef ref, AppStrings s) {
  showDialog(
    context: context,
    builder: (dlgCtx) => DefaultTabController(
      length: 2,
      child: Consumer(
        builder: (_, dlgRef, _) {
          final allTargets = dlgRef.watch(semesterGoalsProvider);
          final allGoals = dlgRef.watch(futureGoalsProvider);
          final targetTree = _buildTargetTree(allTargets);
          final goalTree = _buildGoalTree(allGoals);
          final targetFilter = dlgRef.watch(taskTargetFilterProvider);
          final goalFilter = dlgRef.watch(taskGoalFilterProvider);

          return AlertDialog(
            titlePadding: EdgeInsets.zero,
            title: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [Tab(text: s.targets), Tab(text: s.goals)],
            ),
            content: SizedBox(
              height: 320,
              width: double.maxFinite,
              child: TabBarView(
                children: [
                  // Targets tab
                  targetTree.isEmpty
                      ? Center(
                          child: Text(s.noTargets,
                              style: const TextStyle(color: AppColors.textTertiary)),
                        )
                      : ListView(
                          children: [
                            for (final item in targetTree)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.only(
                                  left: 8.0 + item.depth * 20.0,
                                ),
                                value: targetFilter.contains(item.goal.id),
                                title: Text(item.goal.title),
                                subtitle: Text(item.goal.semester,
                                    style: const TextStyle(fontSize: 12)),
                                onChanged: (v) {
                                  final next = Set<String>.from(
                                      dlgRef.read(taskTargetFilterProvider));
                                  if (v == true) {
                                    next.add(item.goal.id);
                                    void addDesc(String pid) {
                                      for (final g in allTargets.where((g) => g.parentId == pid)) {
                                        next.add(g.id);
                                        addDesc(g.id);
                                      }
                                    }
                                    addDesc(item.goal.id);
                                  } else {
                                    next.remove(item.goal.id);
                                    void removeDesc(String pid) {
                                      for (final g in allTargets.where((g) => g.parentId == pid)) {
                                        next.remove(g.id);
                                        removeDesc(g.id);
                                      }
                                    }
                                    removeDesc(item.goal.id);
                                    String? pid = item.goal.parentId;
                                    while (pid != null) {
                                      next.remove(pid);
                                      pid = allTargets.where((g) => g.id == pid).firstOrNull?.parentId;
                                    }
                                  }
                                  dlgRef
                                      .read(taskTargetFilterProvider.notifier)
                                      .state = next;
                                },
                              ),
                          ],
                        ),
                  // Goals tab
                  goalTree.isEmpty
                      ? Center(
                          child: Text(s.noGoals,
                              style: const TextStyle(color: AppColors.textTertiary)),
                        )
                      : ListView(
                          children: [
                            for (final item in goalTree)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.only(
                                  left: 8.0 + item.depth * 20.0,
                                ),
                                value: goalFilter.contains(item.goal.id),
                                title: Text(item.goal.title),
                                subtitle: item.goal.startSemester != null
                                    ? Text(item.goal.startSemester!,
                                        style: const TextStyle(fontSize: 12))
                                    : null,
                                onChanged: (v) {
                                  final next = Set<String>.from(
                                      dlgRef.read(taskGoalFilterProvider));
                                  if (v == true) {
                                    next.add(item.goal.id);
                                    void addDesc(String pid) {
                                      for (final g in allGoals.where((g) => g.parentId == pid)) {
                                        next.add(g.id);
                                        addDesc(g.id);
                                      }
                                    }
                                    addDesc(item.goal.id);
                                  } else {
                                    next.remove(item.goal.id);
                                    void removeDesc(String pid) {
                                      for (final g in allGoals.where((g) => g.parentId == pid)) {
                                        next.remove(g.id);
                                        removeDesc(g.id);
                                      }
                                    }
                                    removeDesc(item.goal.id);
                                    String? pid = item.goal.parentId;
                                    while (pid != null) {
                                      next.remove(pid);
                                      pid = allGoals.where((g) => g.id == pid).firstOrNull?.parentId;
                                    }
                                  }
                                  dlgRef
                                      .read(taskGoalFilterProvider.notifier)
                                      .state = next;
                                },
                              ),
                          ],
                        ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  dlgRef.read(taskTargetFilterProvider.notifier).state = const {};
                  dlgRef.read(taskGoalFilterProvider.notifier).state = const {};
                },
                child: Text(s.reset),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text(MaterialLocalizations.of(dlgCtx).okButtonLabel),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _CompletedTasksSection extends ConsumerWidget {
  const _CompletedTasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final date = ref.watch(dateProvider);
    final targetFilter = ref.watch(taskTargetFilterProvider);
    final goalFilter = ref.watch(taskGoalFilterProvider);
    final expandedTargetFilter = _expandSemGoalIds(targetFilter, ref.watch(semesterGoalsProvider));
    final expandedGoalFilter = _expandFutureGoalIds(goalFilter, ref.watch(futureGoalsProvider));
    final completed = ref.watch(filteredTasksProvider)
        .where((t) => t.isCompletedOn(date) && _passesFilter(t, expandedTargetFilter, expandedGoalFilter))
        .toList();

    if (completed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.completedTasks, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            children: [
              for (final task in completed) ...[
                _TaskTile(task: task),
                const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final date = ref.watch(dateProvider);
    final effectiveDate = DateTime(date.year, date.month, date.day);
    final isCompleted = task.isCompletedOn(effectiveDate);
    final targets = ref.watch(semesterGoalsProvider);
    final goals = ref.watch(futureGoalsProvider);

    final linkedTarget = task.linkedTargetId != null
        ? targets.where((g) => g.id == task.linkedTargetId).firstOrNull
        : null;
    final linkedGoal = task.linkedGoalId != null
        ? goals.where((g) => g.id == task.linkedGoalId).firstOrNull
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: Checkbox(
        value: isCompleted,
        onChanged: (_) => ref.read(tasksProvider.notifier).toggleOnDate(task.id, effectiveDate),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted ? AppColors.textTertiary : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.content != null)
            Text(task.content!, style: Theme.of(context).textTheme.bodySmall),
          if (task.dueTime != null)
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: _dueColor(task.dueTime!)),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _formatDueTime(task.dueTime!),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _dueColor(task.dueTime!),
                  ),
                ),
                if (task.recurrence != null && !task.recurrence!.isNone) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.repeat, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 2),
                  Text(
                    _recurrenceShort(task.recurrence!, s),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            )
          else if (task.recurrence != null && !task.recurrence!.isNone)
            Row(
              children: [
                Icon(Icons.repeat, size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 2),
                Text(
                  _recurrenceShort(task.recurrence!, s),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          if (linkedTarget != null)
            Text(
              '→ ${linkedTarget.title}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (linkedGoal != null)
            Text(
              '⭐ ${linkedGoal.title}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.priority > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              decoration: BoxDecoration(
                color: task.priority == 3 ? AppColors.errorLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                task.priority == 3 ? s.priorityHigh : s.priorityMed,
                style: TextStyle(
                  fontSize: 11,
                  color: task.priority == 3 ? AppColors.error : AppColors.warning,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              if (await _confirmDelete(context, s)) {
                ref.read(tasksProvider.notifier).remove(task.id);
              }
            },
          ),
        ],
      ),
      onTap: () => _showEditTaskSheet(context, ref, task),
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

// ─── Date+time picker (clock style) ──────────────────────────────────────────

Future<DateTime?> _showDateTimePicker(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

// ─── Recurrence helpers ───────────────────────────────────────────────────────

String _recurrenceLabel(RecurrenceType type, AppStrings s) {
  switch (type) {
    case RecurrenceType.none:       return s.repeatNone;
    case RecurrenceType.daily:      return s.repeatDaily;
    case RecurrenceType.weekly:     return s.repeatWeekly;
    case RecurrenceType.monthly:    return s.repeatMonthly;
    case RecurrenceType.everyNDays: return s.repeatEveryNDays;
  }
}

String _recurrenceShort(RecurrenceRule rule, AppStrings s) {
  switch (rule.type) {
    case RecurrenceType.none:       return '';
    case RecurrenceType.daily:      return s.repeatDaily;
    case RecurrenceType.weekly:     return s.repeatWeekly;
    case RecurrenceType.monthly:    return s.repeatMonthly;
    case RecurrenceType.everyNDays: return '${rule.interval}${s.repeatInterval}';
  }
}

Future<RecurrenceRule?> _showRecurrencePicker(
  BuildContext context, AppStrings s, RecurrenceRule? current) async {
  var type = current?.type ?? RecurrenceType.none;
  var interval = current?.interval ?? 2;
  final intervalCtrl = TextEditingController(text: '$interval');

  return showDialog<RecurrenceRule>(
    context: context,
    builder: (dlgCtx) => StatefulBuilder(
      builder: (dlgCtx, setState) => AlertDialog(
        title: Text(s.repeat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final t in RecurrenceType.values)
                  ChoiceChip(
                    label: Text(_recurrenceLabel(t, s)),
                    selected: type == t,
                    onSelected: (_) => setState(() => type = t),
                  ),
              ],
            ),
            if (type == RecurrenceType.everyNDays)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  controller: intervalCtrl,
                  decoration: InputDecoration(labelText: s.repeatInterval),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => interval = int.tryParse(v) ?? interval,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dlgCtx,
              RecurrenceRule(type: type, interval: interval),
            ),
            child: Text(MaterialLocalizations.of(dlgCtx).okButtonLabel),
          ),
        ],
      ),
    ),
  );
}

// ─── Target / Goal selectors ──────────────────────────────────────────────────

void _showTargetSelector(
  BuildContext context, WidgetRef ref, AppStrings s,
  String? currentId, ValueChanged<String?> onSelect,
) {
  final targets = ref.read(semesterGoalsProvider);
  showDialog(
    context: context,
    builder: (dlgCtx) => AlertDialog(
      title: Text(s.selectTarget),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(s.noLink),
              selected: currentId == null,
              selectedColor: AppColors.primary,
              onTap: () { onSelect(null); Navigator.pop(dlgCtx); },
            ),
            for (final g in targets)
              ListTile(
                title: Text(g.title),
                subtitle: Text(g.semester),
                selected: g.id == currentId,
                selectedColor: AppColors.primary,
                onTap: () { onSelect(g.id); Navigator.pop(dlgCtx); },
              ),
          ],
        ),
      ),
      actions: [TextButton(
        onPressed: () => Navigator.pop(dlgCtx),
        child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
      )],
    ),
  );
}

void _showGoalSelectorForTask(
  BuildContext context, WidgetRef ref, AppStrings s,
  String? currentId, ValueChanged<String?> onSelect,
) {
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
              selectedColor: AppColors.primary,
              onTap: () { onSelect(null); Navigator.pop(dlgCtx); },
            ),
            for (final g in goals)
              ListTile(
                title: Text(g.title),
                selected: g.id == currentId,
                selectedColor: AppColors.primary,
                onTap: () { onSelect(g.id); Navigator.pop(dlgCtx); },
              ),
          ],
        ),
      ),
      actions: [TextButton(
        onPressed: () => Navigator.pop(dlgCtx),
        child: Text(MaterialLocalizations.of(dlgCtx).cancelButtonLabel),
      )],
    ),
  );
}

// ─── Link row widget (due time / recurrence / links) ─────────────────────────

Widget _linkRow({
  required IconData icon,
  required String label,
  required bool active,
  required VoidCallback onTap,
  VoidCallback? onClear,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(AppRadius.md),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18,
              color: active ? AppColors.primary : AppColors.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClear != null && active)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16,
                  color: AppColors.textTertiary),
            ),
        ],
      ),
    ),
  );
}

// ─── Add task sheet ───────────────────────────────────────────────────────────

// Public so HomeScreen FAB can call it
void showAddTaskSheet(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      var priority = 1;
      DateTime? dueTime;
      RecurrenceRule? recurrence;
      String? linkedTargetId;
      String? linkedGoalId;

      return StatefulBuilder(
        builder: (sheetCtx, setState) {
          final targets = ref.read(semesterGoalsProvider);
          final goals = ref.read(futureGoalsProvider);
          final linkedTarget = linkedTargetId != null
              ? targets.where((g) => g.id == linkedTargetId).firstOrNull
              : null;
          final linkedGoal = linkedGoalId != null
              ? goals.where((g) => g.id == linkedGoalId).firstOrNull
              : null;

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(s.addTask,
                      style: Theme.of(sheetCtx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: s.titleField),
                    onSubmitted: (_) => _submitTask(sheetCtx, ref,
                        titleController, contentController, priority,
                        dueTime, recurrence, linkedTargetId, linkedGoalId),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: s.taskNotes,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _linkRow(
                    icon: Icons.calendar_today_outlined,
                    label: dueTime != null
                        ? _formatDueTime(dueTime!)
                        : s.dueTime,
                    active: dueTime != null,
                    onTap: () async {
                      final result = await _showDateTimePicker(
                          sheetCtx, dueTime ?? DateTime.now());
                      if (result != null) setState(() => dueTime = result);
                    },
                    onClear: () => setState(() => dueTime = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.repeat,
                    label: (recurrence == null || recurrence!.isNone)
                        ? s.repeatNone
                        : _recurrenceShort(recurrence!, s),
                    active: recurrence != null && !recurrence!.isNone,
                    onTap: () async {
                      final result =
                          await _showRecurrencePicker(sheetCtx, s, recurrence);
                      if (result != null) setState(() => recurrence = result);
                    },
                    onClear: () => setState(
                        () => recurrence = const RecurrenceRule(
                            type: RecurrenceType.none)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.flag_outlined,
                    label: linkedTarget != null
                        ? '${linkedTarget.title} · ${linkedTarget.semester}'
                        : s.linkedTarget,
                    active: linkedTarget != null,
                    onTap: () => _showTargetSelector(
                        sheetCtx, ref, s, linkedTargetId,
                        (id) => setState(() => linkedTargetId = id)),
                    onClear: () => setState(() => linkedTargetId = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.stars_outlined,
                    label: linkedGoal != null
                        ? linkedGoal.title
                        : s.linkedGoal,
                    active: linkedGoal != null,
                    onTap: () => _showGoalSelectorForTask(
                        sheetCtx, ref, s, linkedGoalId,
                        (id) => setState(() => linkedGoalId = id)),
                    onClear: () => setState(() => linkedGoalId = null),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(s.priority,
                          style: Theme.of(sheetCtx).textTheme.bodyMedium),
                      const SizedBox(width: 12),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 1, label: Text(s.priorityLow)),
                          ButtonSegment(value: 2, label: Text(s.priorityMed)),
                          ButtonSegment(value: 3, label: Text(s.priorityHigh)),
                        ],
                        selected: {priority},
                        onSelectionChanged: (v) =>
                            setState(() => priority = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _submitTask(sheetCtx, ref,
                          titleController, contentController, priority,
                          dueTime, recurrence, linkedTargetId, linkedGoalId),
                      child: Text(s.add),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showEditTaskSheet(BuildContext context, WidgetRef ref, Task task) {
  final titleController = TextEditingController(text: task.title);
  final contentController = TextEditingController(text: task.content ?? '');
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      var priority = task.priority;
      DateTime? dueTime = task.dueTime;
      RecurrenceRule? recurrence = task.recurrence;
      String? linkedTargetId = task.linkedTargetId;
      String? linkedGoalId = task.linkedGoalId;

      return StatefulBuilder(
        builder: (sheetCtx, setState) {
          final targets = ref.read(semesterGoalsProvider);
          final goals = ref.read(futureGoalsProvider);
          final linkedTarget = linkedTargetId != null
              ? targets.where((g) => g.id == linkedTargetId).firstOrNull
              : null;
          final linkedGoal = linkedGoalId != null
              ? goals.where((g) => g.id == linkedGoalId).firstOrNull
              : null;

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.pageHorizontal,
              right: AppSpacing.pageHorizontal,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(s.editTask,
                      style: Theme.of(sheetCtx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${s.createdAtLabel}：${_formatCreatedAt(task.createdAt)}',
                    style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(labelText: s.titleField),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: s.taskNotes,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _linkRow(
                    icon: Icons.calendar_today_outlined,
                    label: dueTime != null
                        ? _formatDueTime(dueTime!)
                        : s.dueTime,
                    active: dueTime != null,
                    onTap: () async {
                      final result = await _showDateTimePicker(
                          sheetCtx, dueTime ?? DateTime.now());
                      if (result != null) setState(() => dueTime = result);
                    },
                    onClear: () => setState(() => dueTime = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.repeat,
                    label: (recurrence == null || recurrence!.isNone)
                        ? s.repeatNone
                        : _recurrenceShort(recurrence!, s),
                    active: recurrence != null && !recurrence!.isNone,
                    onTap: () async {
                      final result =
                          await _showRecurrencePicker(sheetCtx, s, recurrence);
                      if (result != null) setState(() => recurrence = result);
                    },
                    onClear: () => setState(
                        () => recurrence = const RecurrenceRule(
                            type: RecurrenceType.none)),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.flag_outlined,
                    label: linkedTarget != null
                        ? '${linkedTarget.title} · ${linkedTarget.semester}'
                        : s.linkedTarget,
                    active: linkedTarget != null,
                    onTap: () => _showTargetSelector(
                        sheetCtx, ref, s, linkedTargetId,
                        (id) => setState(() => linkedTargetId = id)),
                    onClear: () => setState(() => linkedTargetId = null),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _linkRow(
                    icon: Icons.stars_outlined,
                    label: linkedGoal != null
                        ? linkedGoal.title
                        : s.linkedGoal,
                    active: linkedGoal != null,
                    onTap: () => _showGoalSelectorForTask(
                        sheetCtx, ref, s, linkedGoalId,
                        (id) => setState(() => linkedGoalId = id)),
                    onClear: () => setState(() => linkedGoalId = null),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(s.priority,
                          style: Theme.of(sheetCtx).textTheme.bodyMedium),
                      const SizedBox(width: 12),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(value: 1, label: Text(s.priorityLow)),
                          ButtonSegment(value: 2, label: Text(s.priorityMed)),
                          ButtonSegment(value: 3, label: Text(s.priorityHigh)),
                        ],
                        selected: {priority},
                        onSelectionChanged: (v) =>
                            setState(() => priority = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;
                        ref.read(tasksProvider.notifier).update(Task(
                          id: task.id,
                          title: title,
                          content: contentController.text.trim().isEmpty
                              ? null
                              : contentController.text.trim(),
                          priority: priority,
                          dueTime: dueTime,
                          isCompleted: task.isCompleted,
                          createdAt: task.createdAt,
                          recurrence: recurrence,
                          linkedTargetId: linkedTargetId,
                          linkedGoalId: linkedGoalId,
                        ));
                        Navigator.pop(sheetCtx);
                      },
                      child: Text(s.save),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _submitTask(
  BuildContext context,
  WidgetRef ref,
  TextEditingController titleCtrl,
  TextEditingController contentCtrl,
  int priority,
  DateTime? dueTime,
  RecurrenceRule? recurrence,
  String? linkedTargetId,
  String? linkedGoalId,
) {
  final title = titleCtrl.text.trim();
  if (title.isEmpty) return;
  ref.read(tasksProvider.notifier).add(
    title,
    content: contentCtrl.text.trim().isEmpty ? null : contentCtrl.text.trim(),
    priority: priority,
    dueTime: dueTime,
    recurrence: recurrence,
    linkedTargetId: linkedTargetId,
    linkedGoalId: linkedGoalId,
  );
  Navigator.pop(context);
}

void showAddInspirationSheet(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final s = ref.read(stringsProvider);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
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
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(s.addInspiration,
              style: Theme.of(sheetCtx).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: titleController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.titleField),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: s.inspirationDetails),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                ref.read(inspirationsProvider.notifier).add(
                  title,
                  content: contentController.text.trim().isEmpty
                      ? null
                      : contentController.text.trim(),
                );
                Navigator.pop(sheetCtx);
              },
              child: Text(s.add),
            ),
          ),
        ],
      ),
    ),
  );
}

Color? _dueColor(DateTime dueTime) {
  final now = DateTime.now();
  if (dueTime.isBefore(now)) return AppColors.error;
  if (dueTime.difference(now).inHours < 24) return AppColors.warning;
  return null;
}

String _formatDueTime(DateTime dt) {
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$mm/$dd $hh:$min';
}

String _formatCreatedAt(DateTime dt) {
  final yyyy = dt.year;
  final mm = dt.month.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$yyyy/$mm/$dd $hh:$min';
}
