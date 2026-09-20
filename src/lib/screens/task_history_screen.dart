import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/history_stats.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/category.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/categories_provider.dart';
import '../providers/future_goals_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../utils/category_helpers.dart';
import '../widgets/responsive_body.dart';

// One point on the history chart. rate is null when no task applied that
// day/week/month — distinct from 0%, where tasks existed but none were done.
class _Period {
  final String label;
  final double? rate;
  final int done;
  final int total;
  const _Period(this.label, this.rate, this.done, this.total);
}

const _barGap = 3.0;
const _chartHeight = 160.0;
const _axisLabelW = 34.0;

class TaskHistoryScreen extends ConsumerStatefulWidget {
  const TaskHistoryScreen({super.key});

  @override
  ConsumerState<TaskHistoryScreen> createState() => _TaskHistoryScreenState();
}

class _TaskHistoryScreenState extends ConsumerState<TaskHistoryScreen> {
  int _range = 0; // 0 = daily, 1 = weekly, 2 = monthly
  int? _selected;

  List<_Period> _buildPeriods(DateTime today) {
    final tasks = ref.watch(tasksProvider);

    _Period dayPeriod(DateTime date, String label) {
      final stats = taskCompletionStatsOn(tasks, date);
      if (stats == null) return _Period(label, null, 0, 0);
      return _Period(
          label, stats.done / stats.total, stats.done, stats.total);
    }

    switch (_range) {
      case 1: // Weekly: last 12 weeks, Monday-anchored
        final thisMonday = today.subtract(Duration(days: today.weekday - 1));
        return [
          for (var w = 11; w >= 0; w--)
            _weekPeriod(tasks, thisMonday.subtract(Duration(days: w * 7))),
        ];
      case 2: // Monthly: last 6 calendar months
        return [
          for (var m = 5; m >= 0; m--)
            _monthPeriod(tasks, DateTime(today.year, today.month - m, 1)),
        ];
      default: // Daily: last 30 days
        return [
          for (var d = 29; d >= 0; d--)
            dayPeriod(today.subtract(Duration(days: d)),
                '${today.subtract(Duration(days: d)).month}/${today.subtract(Duration(days: d)).day}'),
        ];
    }
  }

  _Period _weekPeriod(List<Task> tasks, DateTime weekStart) {
    var done = 0, total = 0;
    for (var i = 0; i < 7; i++) {
      final stats =
          taskCompletionStatsOn(tasks, weekStart.add(Duration(days: i)));
      if (stats != null) {
        done += stats.done;
        total += stats.total;
      }
    }
    final label = '${weekStart.month}/${weekStart.day}';
    return total == 0
        ? _Period(label, null, 0, 0)
        : _Period(label, done / total, done, total);
  }

  _Period _monthPeriod(List<Task> tasks, DateTime monthStart) {
    final nextMonth = DateTime(monthStart.year, monthStart.month + 1, 1);
    final daysInMonth = nextMonth.difference(monthStart).inDays;
    var done = 0, total = 0;
    for (var i = 0; i < daysInMonth; i++) {
      final stats =
          taskCompletionStatsOn(tasks, monthStart.add(Duration(days: i)));
      if (stats != null) {
        done += stats.done;
        total += stats.total;
      }
    }
    final label = '${monthStart.year}/${monthStart.month}';
    return total == 0
        ? _Period(label, null, 0, 0)
        : _Period(label, done / total, done, total);
  }

  // How many days the current range covers, counting back from today. Used for
  // the "vs the period before" line, which needs the same length twice
  int get _windowDays => switch (_range) {
        1 => 12 * 7,
        2 => 183,
        _ => 30,
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final now = ref.watch(effectiveNowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final periods = _buildPeriods(today);
    final tasks = ref.watch(tasksProvider);
    final targets = ref.watch(semesterGoalsProvider);
    final cats = ref.watch(categoriesProvider);

    final windowStart = today.subtract(Duration(days: _windowDays - 1));
    final previousEnd = windowStart.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: _windowDays - 1));
    final thisRate = rateBetween(tasks, windowStart, today);
    final lastRate = rateBetween(tasks, previousStart, previousEnd);
    final totals = totalsBetween(tasks, windowStart, today);
    final streak = allDoneStreak(tasks, today);
    final best = bestWeekday(tasks, windowStart, today);
    final categories = categoryTotals(tasks, targets, windowStart, today);
    final stale = stalestTasks(tasks, today);

    final withData = periods.where((p) => p.rate != null).toList();
    final avgPercent = withData.isEmpty
        ? null
        : (withData.fold<double>(0, (sum, p) => sum + p.rate!) /
                withData.length *
                100)
            .round();

    final selected =
        _selected != null && _selected! < periods.length
            ? periods[_selected!]
            : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.taskHistory),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ResponsiveBody(
        child: SingleChildScrollView(
          // The last card sat under the Android navigation bar without this
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.pageHorizontal,
            AppSpacing.pageHorizontal,
            AppSpacing.pageHorizontal + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(s.historyDaily)),
                  ButtonSegment(value: 1, label: Text(s.historyWeekly)),
                  ButtonSegment(value: 2, label: Text(s.historyMonthly)),
                ],
                selected: {_range},
                onSelectionChanged: (v) => setState(() {
                  _range = v.first;
                  _selected = null;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              _SummaryHead(
                percent: avgPercent,
                thisRate: thisRate,
                lastRate: lastRate,
                streak: streak,
                completed: totals.done,
                best: best,
                s: s,
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true, // Most recent period visible by default
                      child: _HistoryChart(
                        periods: periods,
                        selected: _selected,
                        onSelect: (i) => setState(() => _selected = i),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      selected == null
                          ? s.historyTapHint
                          : selected.total == 0
                              ? '${selected.label}$kDotSeparator${s.historyNoData}'
                              : '${selected.label}$kDotSeparator${s.goalProgress(selected.done, selected.total)}'
                                '${s.percentSuffix((selected.rate! * 100).round())}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                        fontWeight:
                            selected == null ? null : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _CategoryBreakdown(rows: categories, cats: cats, s: s),
              ],
              const SizedBox(height: AppSpacing.sm),
              _StaleTasks(
                rows: stale,
                targets: targets,
                visions: ref.watch(futureGoalsProvider),
                cats: cats,
                s: s,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The card above the chart: where this period stands, and three numbers the
// chart cannot show — the run of clear days, how much got done, and which
// weekday goes best
class _SummaryHead extends StatelessWidget {
  final int? percent;
  final double? thisRate;
  final double? lastRate;
  final int streak;
  final int completed;
  final ({int weekday, double rate})? best;
  final AppStrings s;

  const _SummaryHead({
    required this.percent,
    required this.thisRate,
    required this.lastRate,
    required this.streak,
    required this.completed,
    required this.best,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final delta = (thisRate != null && lastRate != null)
        ? ((thisRate! - lastRate!) * 100).round()
        : null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                percent == null ? kEmptyValue : s.percentSuffix(percent!),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.historyAverageLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      if (delta != null)
                        Text(
                          s.historyVsPrevious(
                              '${delta >= 0 ? '+' : ''}${s.percentSuffix(delta)}'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: delta >= 0 ? AppColors.success : AppColors.warning,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat(
                label: s.historyStreak,
                value: '$streak',
                sub: s.historyStreakSub,
              ),
              _Stat(
                label: s.historyCompletedTasks,
                value: '$completed',
                sub: '',
              ),
              _Stat(
                label: s.historyBestWeekday,
                value: best == null ? kEmptyValue : s.weekdayShort(best!.weekday),
                sub: best == null
                    ? ''
                    : s.percentSuffix((best!.rate * 100).round()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Which categories are keeping up and which are not. The order is "most left
// undone first", so the line underneath always names the top row
class _CategoryBreakdown extends StatelessWidget {
  final List<({String category, int done, int total})> rows;
  final List<CategoryEntry> cats;
  final AppStrings s;

  const _CategoryBreakdown({
    required this.rows,
    required this.cats,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final worst = rows.first;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.historyByCategory,
              style: Theme.of(context).textTheme.titleSmall),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: resolveCatColor(cats, row.category),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 64,
                    child: Text(
                      catLabel(row.category, s),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: row.total == 0 ? 0 : row.done / row.total,
                        minHeight: 6,
                        color: resolveCatColor(cats, row.category),
                        backgroundColor: AppColors.surfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    s.goalProgress(row.done, row.total),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
          if (worst.total > worst.done) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.historyCategoryBehind(
                  catLabel(worst.category, s), worst.total - worst.done),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// What has been sitting undone the longest, with the target it belongs to
class _StaleTasks extends StatelessWidget {
  final List<({Task task, int daysLate})> rows;
  final List<SemesterGoal> targets;
  final List<FutureGoal> visions;
  final List<CategoryEntry> cats;
  final AppStrings s;

  const _StaleTasks({
    required this.rows,
    required this.targets,
    required this.visions,
    required this.cats,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.historyStale, style: Theme.of(context).textTheme.titleSmall),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                s.historyNothingStale,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 30,
                    decoration: BoxDecoration(
                      color: taskLinkColor(
                          cats,
                          targets
                              .where((g) => g.id == row.task.linkedTargetId)
                              .firstOrNull,
                          targetVision: visionOf(
                            targets
                                .where((g) => g.id == row.task.linkedTargetId)
                                .firstOrNull,
                            visions,
                          ),
                        ) ??
                        AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          row.task.title,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          s.historyOverdue(row.daysLate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${row.daysLate}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// The page's card shape, so the four cards cannot drift apart
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _Stat({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
          Text(
            sub,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<_Period> periods;
  final int? selected;
  final ValueChanged<int?> onSelect;

  const _HistoryChart({
    required this.periods,
    required this.selected,
    required this.onSelect,
  });

  double get _barWidth => periods.length > 20 ? 12 : (periods.length > 8 ? 24 : 44);

  int? _indexAt(Offset local) {
    final x = local.dx - _axisLabelW;
    if (x < 0) return null;
    final i = (x / (_barWidth + _barGap)).floor();
    return i >= 0 && i < periods.length ? i : null;
  }

  @override
  Widget build(BuildContext context) {
    final width = _axisLabelW + periods.length * (_barWidth + _barGap);
    // Show every Nth label so dense ranges (30 daily bars) stay readable
    final labelStride = periods.length > 20 ? 5 : 1;

    return GestureDetector(
      onTapDown: (d) => onSelect(_indexAt(d.localPosition)),
      child: MouseRegion(
        onHover: (e) => onSelect(_indexAt(e.localPosition)),
        onExit: (_) {},
        child: SizedBox(
          width: width,
          // Room for one line of labels under the plot, with a little slack
          height: _chartHeight + 28,
          child: CustomPaint(
            painter: _HistoryChartPainter(
              periods: periods,
              selected: selected,
              barWidth: _barWidth,
              labelStride: labelStride,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryChartPainter extends CustomPainter {
  final List<_Period> periods;
  final int? selected;
  final double barWidth;
  final int labelStride;
  final TextDirection textDirection;

  const _HistoryChartPainter({
    required this.periods,
    required this.selected,
    required this.barWidth,
    required this.labelStride,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.7)
      ..strokeWidth = 1;

    // Recessive gridlines + muted axis labels at 0/50/100%
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = _chartHeight * (1 - frac);
      canvas.drawLine(Offset(_axisLabelW, y), Offset(size.width, y), gridPaint);
      _paintText(canvas, '${(frac * 100).round()}%',
          Offset(0, y - 6), AppColors.textTertiary, 10);
    }

    for (var i = 0; i < periods.length; i++) {
      final p = periods[i];
      final x = _axisLabelW + i * (barWidth + _barGap);
      final isSelected = selected == i;

      if (p.rate == null) {
        // No task applied this period: a faint baseline tick, not a 0% bar
        final tickPaint = Paint()
          ..color = AppColors.textTertiary.withValues(alpha: 0.35)
          ..strokeWidth = 2;
        canvas.drawLine(
          Offset(x + barWidth / 2, _chartHeight - 2),
          Offset(x + barWidth / 2, _chartHeight),
          tickPaint,
        );
      } else {
        final barH = (_chartHeight * p.rate!).clamp(2.0, _chartHeight);
        final rect = Rect.fromLTWH(x, _chartHeight - barH, barWidth, barH);
        final rrect = RRect.fromRectAndCorners(rect,
            topLeft: const Radius.circular(4), topRight: const Radius.circular(4));
        final barPaint = Paint()
          ..color = p.rate == 1.0
              ? AppColors.success
              : AppColors.primary.withValues(alpha: isSelected ? 1 : 0.85);
        canvas.drawRRect(rrect, barPaint);

        if (isSelected) {
          final ringPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppColors.surface;
          canvas.drawRRect(rrect.deflate(1), ringPaint);
        }
      }

      if (i % labelStride == 0 || i == periods.length - 1) {
        // Centred on its bar and never wrapped: constrained to the bar's own
        // width, "8/31" folded onto a second line that fell outside the box
        // and was cut off. Only every labelStride-th bar is labelled, so the
        // text has the neighbouring gaps to spread into
        _paintCenteredText(canvas, p.label, x + barWidth / 2,
            _chartHeight + 6, AppColors.textTertiary, 10);
      }
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, Color color,
      double fontSize, {double? maxWidth}) {
    _layoutText(text, color, fontSize, maxWidth).paint(canvas, offset);
  }

  // Around a point rather than from it, for labels that belong to a bar
  void _paintCenteredText(Canvas canvas, String text, double centerX,
      double top, Color color, double fontSize) {
    final painter = _layoutText(text, color, fontSize, null);
    painter.paint(canvas, Offset(centerX - painter.width / 2, top));
  }

  TextPainter _layoutText(
      String text, Color color, double fontSize, double? maxWidth) {
    return TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: textDirection,
      maxLines: 1,
    )..layout(maxWidth: maxWidth ?? double.infinity);
  }

  @override
  bool shouldRepaint(_HistoryChartPainter oldDelegate) =>
      oldDelegate.periods != periods || oldDelegate.selected != selected;
}
