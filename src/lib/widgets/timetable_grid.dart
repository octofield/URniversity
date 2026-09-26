import 'package:flutter/material.dart';
import '../core/period_tables.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/timetable.dart';
import '../l10n/app_strings.dart';
import '../models/course.dart';
import 'course_sheet.dart' show formatMinute;

// The week at a glance (system_design.md §3-S): a column per day, Monday to
// Friday unless something meets at the weekend, and time running down. At NTU
// the rail names the periods ("3｜10:20"); elsewhere it shows the hours.
//
// A Stack of Positioned blocks rather than rows of cells: a meeting is placed
// by its minutes, so 10:20–12:10 sits exactly where it runs, and nothing needs
// IntrinsicHeight (which has cut off content here before)
class TimetableGrid extends StatelessWidget {
  final List<Course> courses;
  final List<ClassPeriod>? periods;
  final AppStrings s;
  // Draws the "now" line in this weekday's column, when this week is showing
  final DateTime? now;
  final ValueChanged<Course> onTapCourse;
  final void Function(int weekday, int minute) onTapEmpty;

  const TimetableGrid({
    super.key,
    required this.courses,
    required this.periods,
    required this.s,
    required this.now,
    required this.onTapCourse,
    required this.onTapEmpty,
  });

  static const _railWidth = 48.0;
  static const _headerHeight = 32.0;
  static const _hourHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sessions = [for (final c in courses) ...c.sessions];
    final bounds = gridBounds(sessions);
    final minutes = (bounds.endHour - bounds.startHour) * 60;
    const perMinute = _hourHeight / 60;
    double y(int minute) => (minute - bounds.startHour * 60) * perMinute;

    return LayoutBuilder(builder: (context, constraints) {
      final dayWidth = (constraints.maxWidth - _railWidth) / bounds.days;
      final height = minutes * perMinute;

      // Rail labels: the periods at NTU, the hours elsewhere
      final railLabels = <(double, String)>[
        if (periods != null)
          for (final p in periods!)
            if (p.start >= bounds.startHour * 60 && p.end <= bounds.endHour * 60)
              (y(p.start), '${p.label}\n${formatMinute(p.start)}')
        else
          for (var h = bounds.startHour; h < bounds.endHour; h++) (y(h * 60), formatMinute(h * 60)),
      ];

      final blocks = <Widget>[
        for (final c in courses)
          for (final m in c.sessions)
            Positioned(
              left: _railWidth + (m.weekday - 1) * dayWidth + 1.5,
              top: y(m.startMinute) + 1,
              width: dayWidth - 3,
              height: (m.endMinute - m.startMinute) * perMinute - 2,
              child: _Block(course: c, session: m, onTap: () => onTapCourse(c)),
            ),
      ];

      final nowMinute = now == null ? null : now!.hour * 60 + now!.minute;
      final showNow = now != null &&
          now!.weekday <= bounds.days &&
          nowMinute! >= bounds.startHour * 60 &&
          nowMinute < bounds.endHour * 60;

      return Column(
        children: [
          // Weekday header; today's column is marked
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                const SizedBox(width: _railWidth),
                for (var d = 1; d <= bounds.days; d++)
                  SizedBox(
                    width: dayWidth,
                    child: Center(
                      child: Text(
                        s.weekdayShort(d),
                        style: theme.labelLarge?.copyWith(
                          color: now?.weekday == d ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: now?.weekday == d ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: height,
            child: Stack(
              children: [
                // Hour lines, and a tap target per empty cell
                for (var h = bounds.startHour; h < bounds.endHour; h++)
                  Positioned(
                    left: _railWidth,
                    right: 0,
                    top: y(h * 60),
                    child: Container(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
                  ),
                for (var d = 1; d <= bounds.days; d++)
                  Positioned(
                    left: _railWidth + (d - 1) * dayWidth,
                    top: 0,
                    bottom: 0,
                    width: dayWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // The hour tapped, whole: a new course usually starts on one
                      onTapUp: (details) => onTapEmpty(
                        d,
                        bounds.startHour * 60 + (details.localPosition.dy / perMinute) ~/ 60 * 60,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: now?.weekday == d ? AppColors.primaryLight.withValues(alpha: 0.35) : null,
                          border: Border(left: BorderSide(color: AppColors.border.withValues(alpha: 0.6))),
                        ),
                      ),
                    ),
                  ),
                for (final (top, label) in railLabels)
                  Positioned(
                    left: 0,
                    width: _railWidth - 4,
                    top: top,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.labelSmall?.copyWith(color: AppColors.textTertiary, height: 1.2),
                    ),
                  ),
                ...blocks,
                if (showNow)
                  Positioned(
                    left: _railWidth + (now!.weekday - 1) * dayWidth,
                    width: dayWidth,
                    top: y(nowMinute) - 1,
                    child: IgnorePointer(child: Container(height: 2, color: AppColors.error)),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _Block extends StatelessWidget {
  final Course course;
  final CourseSession session;
  final VoidCallback onTap;

  const _Block({required this.course, required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final color = Color(course.color);
    return Material(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(AppRadius.xs),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
          padding: const EdgeInsets.fromLTRB(4, 3, 3, 2),
          child: LayoutBuilder(builder: (context, c) {
            // As many lines as the block has room for; the title always first
            final lines = (c.maxHeight / 14).floor().clamp(1, 6);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    course.title,
                    maxLines: lines > 1 ? lines - 1 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                if (lines > 1 && session.location != null)
                  Text(
                    session.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelSmall?.copyWith(color: AppColors.textSecondary),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
