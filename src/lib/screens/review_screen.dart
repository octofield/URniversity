import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/input_limits.dart';
import '../core/review_stats.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/review.dart';
import '../models/task.dart';
import '../providers/journal_provider.dart';
import '../providers/reviews_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/synced_list_notifier.dart';
import '../providers/tasks_provider.dart';
import '../widgets/responsive_body.dart';
import '../widgets/review_heatmap.dart';
import '../widgets/sheet_fields.dart';

String reviewTitle(ReviewPeriod period, AppStrings s) => switch (period) {
      ReviewPeriod.week => s.reviewWeekTitle,
      ReviewPeriod.month => s.reviewMonthTitle,
      ReviewPeriod.semester => s.reviewSemesterTitle,
    };

String reviewRange(DateTime start, DateTime end, DateDisplayFormat fmt, AppStrings s) =>
    '${formatDate(start, fmt, s)}$kArrow${formatDate(end, fmt, s)}';

// The guided review (UC19): the numbers, three questions, then what is next.
// Three steps rather than one long page, so each fits a phone screen and the
// "3 minutes" promise is visible in the step count.
class ReviewScreen extends ConsumerStatefulWidget {
  final ReviewWindow window;

  const ReviewScreen({super.key, required this.window});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _step = 0;
  // Which way the last step change went, so going back moves backwards
  bool _back = false;

  late final ReviewStats _stats;
  late final List<double?> _heat;
  late final List<Task> _carry;
  final _wentWell = TextEditingController();
  final _stuck = TextEditingController();
  final _nextFocus = TextEditingController();
  late Set<String> _toCarry;
  final Set<String> _carried = {};
  late List<String> _focus;

  ReviewWindow get _window => widget.window;

  @override
  void initState() {
    super.initState();
    final tasks = ref.read(tasksProvider);
    final settings = ref.read(semesterSettingsProvider);
    final now = ref.read(reviewNowProvider);

    // Frozen on opening: this is what the review will store, and the numbers
    // should not shift while the user is looking at them
    _stats = buildReviewStats(
      window: _window,
      tasks: tasks,
      goals: ref.read(semesterGoalsProvider),
      journals: ref.read(journalProvider),
      writtenByUser: JournalNotifier.isWrittenByUser,
      settings: settings,
      now: now,
    );
    // Twelve whole weeks ending with the one under review
    final heatEnd = weekOf(_window.end).end;
    _heat = dailyRates(tasks, heatEnd.subtract(const Duration(days: 12 * 7 - 1)), heatEnd);
    _carry = carryOverCandidates(tasks, _window.start, _window.end);
    _toCarry = {for (final t in _carry) t.id};

    // Doing a period over starts from what was written before
    final previous = ref.read(reviewsProvider).where(_window.sameAs).firstOrNull;
    _wentWell.text = previous?.wentWell ?? '';
    _stuck.text = previous?.stuck ?? '';
    _nextFocus.text = previous?.nextFocus ?? '';
    _focus = [...?previous?.focusTargetIds];
  }

  @override
  void dispose() {
    _wentWell.dispose();
    _stuck.dispose();
    _nextFocus.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() {
      _back = step < _step;
      _step = step;
    });
  }

  // Moves each ticked task a week on, keeping its time of day
  void _carryOver() {
    final s = ref.read(stringsProvider);
    final notifier = ref.read(tasksProvider.notifier);
    var moved = 0;
    for (final task in _carry) {
      if (!_toCarry.contains(task.id) || _carried.contains(task.id)) continue;
      notifier.update(task.copyWith(dueTime: task.dueTime!.add(const Duration(days: 7))));
      _carried.add(task.id);
      moved++;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.reviewCarryDone(moved))));
  }

  void _finish() {
    final s = ref.read(stringsProvider);
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    ref.read(reviewsProvider.notifier).save(Review(
          id: newRowId(),
          period: _window.period,
          periodStart: _window.start,
          periodEnd: _window.end,
          wentWell: text(_wentWell),
          stuck: text(_stuck),
          nextFocus: text(_nextFocus),
          focusTargetIds: _focus,
          stats: _stats,
          createdAt: DateTime.now(),
        ));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(s.reviewSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final fmt = ref.watch(settingsProvider);
    final steps = [s.reviewStepNumbers, s.reviewStepReflect, s.reviewStepPlan];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reviewTitle(_window.period, s)),
            Text(
              reviewRange(_window.start, _window.end, fmt, s),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.sm, AppSpacing.pageHorizontal, 0),
              child: Row(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: scaled(context, AppMotion.move),
                            curve: AppMotion.moveCurve,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _step ? AppColors.primary : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            steps[i],
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: i == _step ? AppColors.primary : AppColors.textTertiary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (i < steps.length - 1) const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            Expanded(
              // Material's shared axis: the steps are a sequence, so the next
              // one slides in a short way from the side it lies on while the
              // current one fades out. Steps move with the buttons only — a
              // stray swipe while typing would throw the user back a step.
              // The typed text lives in this state's controllers, so a step
              // leaving the tree loses nothing
              child: PageTransitionSwitcher(
                duration: scaled(context, AppMotion.page),
                reverse: _back,
                transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  transitionType: SharedAxisTransitionType.horizontal,
                  fillColor: Colors.transparent,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: [
                  _NumbersStep(stats: _stats, heat: _heat, s: s),
                  _ReflectStep(wentWell: _wentWell, stuck: _stuck, nextFocus: _nextFocus, s: s),
                  _PlanStep(
                    carry: _carry,
                    toCarry: _toCarry,
                    carried: _carried,
                    onToggleCarry: (id, on) => setState(() => on ? _toCarry.add(id) : _toCarry.remove(id)),
                    onCarry: _carryOver,
                    focus: _focus,
                    onToggleFocus: (id) => setState(() {
                      if (_focus.contains(id)) {
                        _focus.remove(id);
                      } else if (_focus.length < 3) {
                        _focus.add(id);
                      }
                    }),
                    semester: termAt(ref.read(reviewNowProvider), ref.read(semesterSettingsProvider)),
                    s: s,
                    fmt: fmt,
                  ),
                  ][_step],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.sm, AppSpacing.pageHorizontal, AppSpacing.md),
                child: Row(
                  children: [
                    if (_step > 0) TextButton(onPressed: () => _goTo(_step - 1), child: Text(s.reviewBack)),
                    const Spacer(),
                    FilledButton(
                      onPressed: _step < steps.length - 1 ? () => _goTo(_step + 1) : _finish,
                      child: Text(_step < steps.length - 1 ? s.reviewNext : s.reviewFinish),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumbersStep extends ConsumerWidget {
  final ReviewStats stats;
  final List<double?> heat;
  final AppStrings s;

  const _NumbersStep({required this.stats, required this.heat, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rate = stats.rate;
    final prev = stats.previousRate;
    final change = rate == null || prev == null ? null : ((rate - prev) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        _Card(
          child: rate == null
              ? Text(s.reviewNothingPlanned, style: theme.textTheme.bodyMedium)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${(rate * 100).round()}%', style: theme.textTheme.displaySmall?.copyWith(color: AppColors.primary)),
                    Text(s.reviewDoneOf(stats.done, stats.total), style: theme.textTheme.bodyMedium),
                    if (change != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        change > 0
                            ? s.reviewChangeUp(change)
                            : change < 0
                                ? s.reviewChangeDown(-change)
                                : s.reviewChangeSame,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: change >= 0 ? AppColors.success : AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (stats.streak > 0) _Pill(s.reviewStreak(stats.streak)),
                        if (stats.bestWeekday != null)
                          _Pill('${s.historyBestWeekday}$kDotSeparator${s.weekdayShort(stats.bestWeekday!)}'),
                        if (stats.journals > 0) _Pill(s.reviewJournals(stats.journals)),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.reviewHeatmapTitle, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              ReviewHeatmap(rates: heat),
              const SizedBox(height: AppSpacing.sm),
              Text(s.reviewHeatmapLegend, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
            ],
          ),
        ),
        if (stats.targets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.reviewTargetsHeader, style: theme.textTheme.titleSmall),
                for (final t in stats.targets) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(t.title, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: t.milestonesTotal == 0 ? 0 : t.milestonesDone / t.milestonesTotal,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceVariant,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.reviewTargetLine(t.milestonesDone, t.milestonesTotal, t.tasksDone, t.tasksTotal),
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReflectStep extends StatelessWidget {
  final TextEditingController wentWell;
  final TextEditingController stuck;
  final TextEditingController nextFocus;
  final AppStrings s;

  const _ReflectStep({required this.wentWell, required this.stuck, required this.nextFocus, required this.s});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        Text(s.reviewOptional, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary)),
        const SizedBox(height: AppSpacing.md),
        SheetTextField(label: s.reviewWentWell, hint: s.reviewWentWellHint, controller: wentWell, maxLength: InputLimits.body, minLines: 2, maxLines: 5),
        const SizedBox(height: AppSpacing.md),
        SheetTextField(label: s.reviewStuck, hint: s.reviewStuckHint, controller: stuck, maxLength: InputLimits.body, minLines: 2, maxLines: 5),
        const SizedBox(height: AppSpacing.md),
        SheetTextField(label: s.reviewNextFocus, hint: s.reviewNextFocusHint, controller: nextFocus, maxLength: InputLimits.body, minLines: 1, maxLines: 3),
      ],
    );
  }
}

class _PlanStep extends ConsumerWidget {
  final List<Task> carry;
  final Set<String> toCarry;
  final Set<String> carried;
  final void Function(String id, bool on) onToggleCarry;
  final VoidCallback onCarry;
  final List<String> focus;
  final ValueChanged<String> onToggleFocus;
  final String semester;
  final AppStrings s;
  final DateDisplayFormat fmt;

  const _PlanStep({
    required this.carry,
    required this.toCarry,
    required this.carried,
    required this.onToggleCarry,
    required this.onCarry,
    required this.focus,
    required this.onToggleFocus,
    required this.semester,
    required this.s,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final targets = ref
        .watch(semesterGoalsProvider)
        .where((g) => g.parentId == null && g.semester == semester && !g.isDone)
        .toList();
    final pending = carry.where((t) => !carried.contains(t.id)).toList();
    final ticked = pending.where((t) => toCarry.contains(t.id)).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      children: [
        Text(s.reviewCarryTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        if (pending.isEmpty)
          Text(s.reviewCarryNone, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))
        else ...[
          for (final task in pending)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: toCarry.contains(task.id),
              onChanged: (v) => onToggleCarry(task.id, v ?? false),
              title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(formatDate(task.dueTime!, fmt, s)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: ticked == 0 ? null : onCarry,
              child: Text(s.reviewCarryAction(ticked)),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(s.reviewFocusTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (targets.isEmpty)
          Text(s.reviewFocusNone, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary))
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in targets)
                FilterChip(
                  label: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  selected: focus.contains(t.id),
                  // Three at most: past that "focus" stops meaning anything
                  onSelected: focus.contains(t.id) || focus.length < 3 ? (_) => onToggleFocus(t.id) : null,
                ),
            ],
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.primaryDark)),
      );
}
