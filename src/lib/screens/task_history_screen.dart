import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final now = ref.watch(effectiveNowProvider);
    final today = DateTime(now.year, now.month, now.day);
    final periods = _buildPeriods(today);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
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
            if (avgPercent != null)
              Text(s.historyAverage(avgPercent),
                  style: Theme.of(context).textTheme.titleMedium),
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
                            ? '${selected.label} · ${s.historyNoData}'
                            : '${selected.label} · ${s.goalProgress(selected.done, selected.total)}'
                              '（${(selected.rate! * 100).round()}%）',
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
          ],
        ),
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
          height: _chartHeight + 24,
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
        _paintText(canvas, p.label, Offset(x, _chartHeight + 6),
            AppColors.textTertiary, 10, maxWidth: barWidth + _barGap);
      }
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, Color color,
      double fontSize, {double? maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth ?? double.infinity);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_HistoryChartPainter oldDelegate) =>
      oldDelegate.periods != periods || oldDelegate.selected != selected;
}
