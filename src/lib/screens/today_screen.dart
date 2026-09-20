import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_breakpoints.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/recent_picks.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';
import '../providers/trash_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/date_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/recent_picks_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/category_helpers.dart';
import '../utils/semester_helpers.dart';
import '../widgets/completion_effect.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/drag_reorder.dart';
import '../widgets/semester_grouped_picker.dart';
import '../widgets/sheet_body.dart';
import '../widgets/hover_lift.dart';
import '../widgets/link_color_bar.dart';
import '../widgets/page_header.dart';
import '../widgets/swipe_switcher.dart';
import '../widgets/sheet_fields.dart';
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

    // The task filter, shown as a banner chip across every view
    final targetFilter = ref.watch(taskTargetFilterProvider);
    final isFiltered = targetFilter.isNotEmpty;

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
        PageHeader(
          title: greeting,
          subtitle: Text(
            '${formatDate(todayDate, dateFormat, s)}$kDotSeparator'
            '${s.todayStatus(todayTasks.length, todayDone)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
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
                        '${s.filters}$kDotSeparator${targetFilter.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          ref.read(taskTargetFilterProvider.notifier).state = const {};
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
          // Swiping the body moves between 全部 / 當日 / 當週, in the order the
          // segmented button shows them
          child: SwipeSwitcher(
            onNext: taskView < 2
                ? () => ref.read(taskViewProvider.notifier).state = taskView + 1
                : null,
            // Nothing before the first view, so that swipe pulls out the
            // drawer instead — the same direction as dragging from the edge
            onPrevious: taskView > 0
                ? () => ref.read(taskViewProvider.notifier).state = taskView - 1
                : () => Scaffold.of(context).openDrawer(),
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

// The week as one continuous sheet, Monday to Sunday top to bottom: a fixed
// date column on the left ruled off from that day's tasks on the right
// (direction B of the 2026-09-15 design canvas)
class _WeeklyGridState extends ConsumerState<_WeeklyGrid> {
  final _dayKeys = List.generate(7, (_) => GlobalKey());

  @override
  Widget build(BuildContext context) {
    ref.listen(dateProvider, (_, next) {
      final dayIndex = DateTime(next.year, next.month, next.day)
          .difference(widget.weekStart)
          .inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _dayKeys[dayIndex].currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
          }
        });
      }
    });

    final isDesktop = MediaQuery.of(context).size.width >= AppBreakpoints.desktop;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        80,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // A single column of rows reads badly when stretched across a wide window
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < 7; i++)
                  _DayRow(
                    key: _dayKeys[i],
                    date: widget.weekStart.add(Duration(days: i)),
                    isFirst: i == 0,
                    dateColumnWidth: isDesktop ? 84 : 60,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayRow extends ConsumerWidget {
  final DateTime date;
  final bool isFirst;
  final double dateColumnWidth;
  const _DayRow({
    super.key,
    required this.date,
    required this.isFirst,
    required this.dateColumnWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final normalDate = DateTime(date.year, date.month, date.day);
    // Weekly view honors the same goal filters as the other views
    final expandedTargetFilter = expandSemGoalIds(
      ref.watch(taskTargetFilterProvider),
      ref.watch(semesterGoalsProvider),
    );
    final tasks = ref
        .watch(tasksForDateProvider(normalDate))
        .where((t) => passesTaskFilter(t, expandedTargetFilter))
        .toList();
    final selectedDate = ref.watch(dateProvider);
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isFocused =
        date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day;

    return Container(
      decoration: BoxDecoration(
        border: isFirst ? null : const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: isToday ? AppColors.primaryLight : Colors.transparent,
              child: InkWell(
                onTap: () => ref.read(dateProvider.notifier).setDate(normalDate),
                child: Container(
                  width: dateColumnWidth,
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        s.weekdayShort(date.weekday),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isToday ? AppColors.primary : AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        constraints: const BoxConstraints(minWidth: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isToday ? AppColors.primary : null,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          // The picked day, when it isn't today, gets an outline
                          // so tapping a date still shows where you are
                          border: isFocused && !isToday
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Text(
                          '${date.month}/${date.day}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isToday ? AppColors.textOnPrimary : AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: AppSpacing.sm + 4,
                      ),
                      child: Text(
                        '–',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var j = 0; j < tasks.length; j++) ...[
                          if (j > 0) const Divider(height: 1, indent: 12),
                          _WeekTaskTile(task: tasks[j], date: normalDate),
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

class _WeekTaskTile extends ConsumerWidget {
  final Task task;
  final DateTime date;
  const _WeekTaskTile({required this.task, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final isCompleted = task.isCompletedOn(date);
    final cats = ref.watch(categoriesProvider);
    final linkedTarget = task.linkedTargetId != null
        ? ref.watch(semesterGoalsProvider).where((g) => g.id == task.linkedTargetId).firstOrNull
        : null;
    // One bar, not the day list's split one: this row is too short to split
    final barColor = taskLinkColor(cats, linkedTarget,
            targetVision: visionOf(linkedTarget, ref.watch(futureGoalsProvider))) ??
        Colors.transparent;
    final isRecurring = task.recurrence != null && !task.recurrence!.isNone;
    final meta = isRecurring
        ? _recurrenceShort(task.recurrence!, s, task.createdAt)
        : (task.dueTime != null ? _formatDueTime(task.dueTime!) : null);
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary);

    return InkWell(
      onTap: () => showTaskSheet(context, ref, existing: task),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 24,
              height: 24,
              child: TaskCheckbox(
                value: isCompleted,
                onToggle: () => ref.read(tasksProvider.notifier).toggleOnDate(task.id, date),
                isLastOutstanding: () => _isLastOutstanding(ref, date),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta != null)
                    Row(
                      children: [
                        Icon(
                          isRecurring ? Icons.repeat : Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            meta,
                            style: metaStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Whether this is the day's last task still outstanding — checked before the
// tick is written, because afterwards there is nothing left to count
bool _isLastOutstanding(WidgetRef ref, DateTime date) =>
    ref
        .read(tasksForDateProvider(DateTime(date.year, date.month, date.day)))
        .where((t) => !t.isCompletedOn(date))
        .length ==
    1;

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

    // The whole card opens the history, not just the ring: the ring was a
    // 72px target nobody found
    return HoverLift(
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaskHistoryScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
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
          ),
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
    final targetFilter = ref.watch(taskTargetFilterProvider);
    final isFiltered = targetFilter.isNotEmpty;
    final expandedTargetFilter = expandSemGoalIds(targetFilter, ref.watch(semesterGoalsProvider));
    final sort = ref.watch(taskSortProvider);
    final tasks = ref
        .watch(filteredTasksProvider)
        .where(
          (t) =>
              !t.isCompletedOn(ref.watch(taskRowDateProvider(t))) &&
              passesTaskFilter(t, expandedTargetFilter),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              Text(s.tasksWithCount(tasks.length), style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.arrow_downward,
                  color: sort == TaskSort.manual
                      ? AppColors.textTertiary
                      : AppColors.primary,
                  size: 20,
                ),
                tooltip: s.sortBy,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () => _showSortMenu(context, ref, s),
              ),
              const SizedBox(width: AppSpacing.xs),
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

// Which order the list is in. A sheet rather than a popup menu: the same
// control has to be reachable on a phone held one-handed
void _showSortMenu(BuildContext context, WidgetRef ref, AppStrings s) {
  final labels = {
    TaskSort.manual: s.sortManual,
    TaskSort.created: s.sortCreated,
    TaskSort.title: s.sortTitle,
    TaskSort.target: s.sortTarget,
    TaskSort.due: s.sortDue,
  };

  showAppSheet(
    context,
    builder: (sheetCtx) => Consumer(
      builder: (_, sheetRef, _) {
        final current = sheetRef.watch(taskSortProvider);
        return SheetBody(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.sortBy, style: Theme.of(sheetCtx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              // The sheet's own background is a DecoratedBox, so the tiles need
              // a Material of their own to paint their ink on
              Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in labels.entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value),
                        trailing: entry.key == current
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        selected: entry.key == current,
                        selectedColor: AppColors.primary,
                        onTap: () {
                          sheetRef.read(taskSortProvider.notifier).set(entry.key);
                          Navigator.pop(sheetCtx);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// Filtering tasks by target, grouped by semester the same way the link picker
// groups them — a flat list of every target ever set was unusable by the second
// year. Multi-select, and picking a target implies its milestones.
void _showTaskFilterDialog(BuildContext context, WidgetRef ref, AppStrings s) {
  showDialog(
    context: context,
    builder: (dlgCtx) => Consumer(
      builder: (_, dlgRef, _) {
        final allTargets = dlgRef.watch(semesterGoalsProvider);
        final settings = dlgRef.watch(semesterSettingsProvider);
        final selected = dlgRef.watch(taskTargetFilterProvider);

        void toggle(SemesterGoal goal, bool on) {
          final next = Set<String>.from(selected);
          void withDescendants(String id, void Function(String) apply) {
            apply(id);
            for (final child in allTargets.where((g) => g.parentId == id)) {
              withDescendants(child.id, apply);
            }
          }

          if (on) {
            withDescendants(goal.id, next.add);
          } else {
            withDescendants(goal.id, next.remove);
            // Unticking a milestone also unticks whatever it sat under, or the
            // parent would still be pulling the milestone's tasks in
            String? parentId = goal.parentId;
            while (parentId != null) {
              next.remove(parentId);
              parentId = allTargets.where((g) => g.id == parentId).firstOrNull?.parentId;
            }
          }
          dlgRef.read(taskTargetFilterProvider.notifier).state = next;
        }

        return SemesterGroupedFilterDialog(
          title: s.targets,
          emptyLabel: s.noTargets,
          resetLabel: s.reset,
          items: [
            for (final g in allTargets)
              SemesterPickerItem(
                id: g.id,
                title: g.title,
                semester: g.semester,
                parentId: g.parentId,
                sortOrder: g.sortOrder,
              ),
          ],
          selectedIds: selected,
          currentSemester: currentSemester(settings),
          settings: settings,
          s: s,
          onToggle: (id, on) {
            final goal = allTargets.where((g) => g.id == id).firstOrNull;
            if (goal != null) toggle(goal, on);
          },
          onReset: () => dlgRef.read(taskTargetFilterProvider.notifier).state = const {},
        );
      },
    ),
  );
}

class _CompletedTasksSection extends ConsumerStatefulWidget {
  const _CompletedTasksSection();

  @override
  ConsumerState<_CompletedTasksSection> createState() => _CompletedTasksSectionState();
}

class _CompletedTasksSectionState extends ConsumerState<_CompletedTasksSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final expandedTargetFilter = expandSemGoalIds(
      ref.watch(taskTargetFilterProvider),
      ref.watch(semesterGoalsProvider),
    );
    final completed = ref
        .watch(filteredTasksProvider)
        .where(
          (t) =>
              t.isCompletedOn(ref.watch(taskRowDateProvider(t))) &&
              passesTaskFilter(t, expandedTargetFilter),
        )
        .toList();

    if (completed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Text(
                  s.completedTasksWithCount(completed.length),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : HoverLift(
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
        ),
      ],
    );
  }
}

// Left inset where a task tile's title starts: color bar + padding + checkbox + gap
const double _taskTitleIndent = 62.0;

// Width of the link colour bar down a task row's left edge
const double _linkBarWidth = 6.0;

// Task list with drag-to-reorder. Mirrors the goal
// screens' Draggable/DragTarget pattern: dropping on a row's top edge inserts
// before it, dropping on the body makes the task a subtask of that row
