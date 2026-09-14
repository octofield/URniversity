import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';
import '../providers/trash_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/date_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/drag_reorder.dart';
import '../widgets/sheet_body.dart';
import '../widgets/hover_lift.dart';
import 'settings_screen.dart';
import 'task_history_screen.dart';

// Split with `part` rather than separate libraries: every helper here is
// library-private and used across all three files, so real imports would mean
// making a dozen names public for no benefit
part 'today_task_list.dart';
part 'today_task_sheet.dart';

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

  bool _isCurrentWeek(DateTime effectiveNow) {
    final monday = _mondayOf(effectiveNow);
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
    final now = ref.watch(effectiveNowProvider);
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final weekEnd = _weekStart.add(const Duration(days: 6));
    // Layout follows screen width, not platform, so narrow web windows get the mobile UI
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isWide = width >= AppBreakpoints.wide;

    // Active goal filters, shown as a banner chip across every view
    final targetFilter = ref.watch(taskTargetFilterProvider);
    final goalFilter = ref.watch(taskGoalFilterProvider);
    final isFiltered = targetFilter.isNotEmpty || goalFilter.isNotEmpty;

    // Greeting header data
    final profile = ref.watch(profileProvider);
    final greetName = profile?.username ?? '';
    final greeting = now.hour < 12
        ? s.greetingMorning(greetName)
        : now.hour < 18
        ? s.greetingAfternoon(greetName)
        : s.greetingEvening(greetName);
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayTasks = ref.watch(tasksForDateProvider(todayDate));
    final todayDone = todayTasks.where((t) => t.isCompletedOn(todayDate)).length;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.pageTop,
            AppSpacing.pageHorizontal,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDesktop) ...[
                IconButton(
                  icon: const Icon(Icons.menu),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDate(todayDate, dateFormat, s)}$kDotSeparator'
                      '${s.todayStatus(todayTasks.length, todayDone)}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.sm,
            AppSpacing.pageHorizontal,
            AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.allTasks)),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.dailyTasks)),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.weeklyTasks)),
                  ),
                ],
                selected: {taskView},
                onSelectionChanged: (v) => ref.read(taskViewProvider.notifier).state = v.first,
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
              ),
            ],
          ),
        ),
        if (isFiltered)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              4,
              AppSpacing.pageHorizontal,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.primary, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_list, size: 14, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${s.filters}$kDotSeparator${targetFilter.length + goalFilter.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          ref.read(taskTargetFilterProvider.notifier).state = const {};
                          ref.read(taskGoalFilterProvider.notifier).state = const {};
                        },
                        child: const Icon(Icons.close, size: 14, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
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
                  formatDate(selectedDate, dateFormat, s),
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
                    onPressed: () => ref.read(dateProvider.notifier).goToToday(now),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal - 8),
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
                if (!_isCurrentWeek(now))
                  TextButton(
                    onPressed: () {
                      setState(() => _weekStart = _mondayOf(now));
                      ref.read(dateProvider.notifier).goToToday(now);
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                    child: Text(s.backToToday),
                  ),
                IconButton(
                  icon: Icon(
                    isFiltered ? Icons.filter_list : Icons.filter_list_outlined,
                    color: isFiltered ? AppColors.primary : AppColors.textTertiary,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showTaskFilterDialog(context, ref, s),
                ),
              ],
            ),
          ),
        Expanded(
          child: taskView == 2
              ? _WeeklyGrid(weekStart: _weekStart)
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    12,
                    AppSpacing.pageHorizontal,
                    AppSpacing.xl,
                  ),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main block: task lists
                            const Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _TasksSection(),
                                  SizedBox(height: AppSpacing.lg),
                                  _CompletedTasksSection(),
                                ],
                              ),
                            ),
                            SizedBox(width: isWide ? AppSpacing.xl : AppSpacing.lg),
                            // Secondary block: completion summary and inspirations
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Fixed-height header keeps this column's
                                  // top edge aligned with the tasks column
                                  SizedBox(
                                    height: 40,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        s.progressOverview,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  const _SummaryCard(),
                                  const SizedBox(height: AppSpacing.lg),
                                  const _InspirationsQuickList(),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
    );

    if (isDesktop) {
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Two-column cap: roomier on wide screens so side gaps stay balanced
            constraints: BoxConstraints(maxWidth: isWide ? 1100 : 900),
            child: content,
          ),
        ),
      );
    }

    return SafeArea(child: content);
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        8,
        AppSpacing.pageHorizontal,
        80,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < 7; i++) _DayColumn(date: widget.weekStart.add(Duration(days: i))),
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
    // Weekly view honors the same goal filters as the other views
    final expandedTargetFilter = expandSemGoalIds(
      ref.watch(taskTargetFilterProvider),
      ref.watch(semesterGoalsProvider),
    );
    final expandedGoalFilter = expandFutureGoalIds(
      ref.watch(taskGoalFilterProvider),
      ref.watch(futureGoalsProvider),
    );
    final tasks = ref
        .watch(tasksForDateProvider(normalDate))
        .where((t) => passesTaskFilter(t, expandedTargetFilter, expandedGoalFilter))
        .toList();
    final selectedDate = ref.watch(dateProvider);
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isFocused =
        date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day;
    final headerColor = isToday
        ? AppColors.primary
        : (isFocused ? AppColors.primary : AppColors.textTertiary);

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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: headerColor),
                  ),
                  Text(
                    '${date.month}/${date.day}',
                    // No type-scale role is 15px, and 14 or 16 both break the
                    // weekly grid column width
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
                child: Text('–',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary)),
              )
            else
              for (final task in tasks) _WeekTaskTile(task: task, date: normalDate),
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
      onTap: () => showTaskSheet(context, ref, existing: task),
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
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                task.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    final progress = total > 0 ? completed / total : 0.0;

    return HoverLift(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TaskHistoryScreen()),
                  ),
                  child: Tooltip(
                    message: s.taskHistory,
                    waitDuration: const Duration(milliseconds: 400),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: value,
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            color: allDone ? AppColors.success : AppColors.primary,
                            backgroundColor: AppColors.surfaceVariant,
                          ),
                          Center(
                            child: Text(
                              total == 0 ? kEmptyValue : '${(value * 100).round()}%',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    s.tasksCompleted(completed, total),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (allDone) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) =>
                          Transform.scale(scale: v, alignment: Alignment.centerLeft, child: child),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.celebration, size: 16, color: AppColors.warning),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            s.allDoneToday,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspirationsQuickList extends ConsumerWidget {
  const _InspirationsQuickList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final active = ref.watch(inspirationsProvider).where((i) => !i.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.inspirations, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: active.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.lg,
                  ),
                  child: EmptyState(
                    icon: Icons.lightbulb_outline,
                    message: s.noInspirations,
                    actionLabel: s.addInspiration,
                    onAction: () => showAddInspirationSheet(context, ref),
                    compact: true,
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < active.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.lightbulb_outline,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    active[i].title,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  if (active[i].content != null)
                                    Text(
                                      active[i].content!,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final date = ref.watch(dateProvider);
    final targetFilter = ref.watch(taskTargetFilterProvider);
    final goalFilter = ref.watch(taskGoalFilterProvider);
    final isFiltered = targetFilter.isNotEmpty || goalFilter.isNotEmpty;
    final expandedTargetFilter = expandSemGoalIds(targetFilter, ref.watch(semesterGoalsProvider));
    final expandedGoalFilter = expandFutureGoalIds(goalFilter, ref.watch(futureGoalsProvider));
    final tasks = ref
        .watch(filteredTasksProvider)
        .where(
          (t) =>
              !t.isCompletedOn(date) && passesTaskFilter(t, expandedTargetFilter, expandedGoalFilter),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Text(s.tasks, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
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
        ),
        const SizedBox(height: AppSpacing.sm),
        HoverLift(
          child: Container(
            width: double.infinity,
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
                      vertical: AppSpacing.lg,
                    ),
                    child: EmptyState(
                      icon: Icons.task_alt,
                      message: s.noTasks,
                      actionLabel: s.addTask,
                      onAction: () => showTaskSheet(context, ref),
                      compact: true,
                    ),
                  )
                : _DraggableTaskList(tasks: tasks),
          ),
        ),
      ],
    );
  }
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
          final semSettings = dlgRef.watch(semesterSettingsProvider);
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
              tabs: [
                Tab(text: s.targets),
                Tab(text: s.goals),
              ],
            ),
            content: SizedBox(
              height: 320,
              width: 400,
              child: TabBarView(
                children: [
                  // Targets tab
                  targetTree.isEmpty
                      ? Center(
                          child: Text(
                            s.noTargets,
                            style: const TextStyle(color: AppColors.textTertiary),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final item in targetTree)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.only(left: 8.0 + item.depth * 20.0),
                                value: targetFilter.contains(item.goal.id),
                                title: Text(item.goal.title),
                                subtitle: Text(
                                  formatSemester(item.goal.semester, semSettings, s),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                onChanged: (v) {
                                  final next = Set<String>.from(
                                    dlgRef.read(taskTargetFilterProvider),
                                  );
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
                                      pid = allTargets
                                          .where((g) => g.id == pid)
                                          .firstOrNull
                                          ?.parentId;
                                    }
                                  }
                                  dlgRef.read(taskTargetFilterProvider.notifier).state = next;
                                },
                              ),
                          ],
                        ),
                  // Goals tab
                  goalTree.isEmpty
                      ? Center(
                          child: Text(
                            s.noGoals,
                            style: const TextStyle(color: AppColors.textTertiary),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final item in goalTree)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.only(left: 8.0 + item.depth * 20.0),
                                value: goalFilter.contains(item.goal.id),
                                title: Text(item.goal.title),
                                subtitle: item.goal.startSemester != null
                                    ? Text(
                                        formatSemester(item.goal.startSemester!, semSettings, s),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      )
                                    : null,
                                onChanged: (v) {
                                  final next = Set<String>.from(
                                    dlgRef.read(taskGoalFilterProvider),
                                  );
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
                                      pid = allGoals
                                          .where((g) => g.id == pid)
                                          .firstOrNull
                                          ?.parentId;
                                    }
                                  }
                                  dlgRef.read(taskGoalFilterProvider.notifier).state = next;
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
    final expandedTargetFilter = expandSemGoalIds(targetFilter, ref.watch(semesterGoalsProvider));
    final expandedGoalFilter = expandFutureGoalIds(goalFilter, ref.watch(futureGoalsProvider));
    final completed = ref
        .watch(filteredTasksProvider)
        .where(
          (t) =>
              t.isCompletedOn(date) && passesTaskFilter(t, expandedTargetFilter, expandedGoalFilter),
        )
        .toList();

    if (completed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.completedTasks, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        HoverLift(
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              children: [
                for (var i = 0; i < completed.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: _taskTitleIndent),
                  _TaskTile(task: completed[i]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Left inset where a task tile's title starts: color bar + padding + checkbox + gap
const double _taskTitleIndent = 62.0;

// Task list with drag-to-reorder and one level of subtasks. Mirrors the goal
// screens' Draggable/DragTarget pattern: dropping on a row's top edge inserts
// before it, dropping on the body makes the task a subtask of that row
