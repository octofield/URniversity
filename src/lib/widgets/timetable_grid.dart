import 'package:flutter/material.dart';
import '../core/period_tables.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/timetable.dart';
import '../l10n/app_strings.dart';
import '../models/course.dart';
import 'course_sheet.dart' show formatMinute;

// The week at a glance (system_design.md §3-S): a column per day, Monday to
// Friday unless something meets at the weekend, and a row per period of the
// user's school, like a printed timetable ("3｜10:20"); a school without a
// period table gets a row per hour.
//
// A Stack of Positioned blocks rather than rows of cells: a meeting is placed
// through rowPosition, so 10:20–12:10 fills periods 3–4 exactly, and nothing
// needs IntrinsicHeight (which has cut off content here before)
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
  // A period is 50 minutes; an hour row is a little taller for its 60
  static const _periodHeight = 56.0;
  static const _hourHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sessions = [for (final c in courses) ...c.sessions];
    final days = gridBounds(sessions).days;
    final rows = gridRows(periods, sessions);
    // Hour rows carry no label; period rows do
    final byPeriod = rows.first.label.isNotEmpty;
    final rowHeight = byPeriod ? _periodHeight : _hourHeight;
    double y(int minute) => rowPosition(rows, minute) * rowHeight;
    final lineColor = AppColors.border.withValues(alpha: 0.6);

    return LayoutBuilder(builder: (context, constraints) {
      final dayWidth = (constraints.maxWidth - _railWidth) / days;
      final height = rows.length * rowHeight;

      final blocks = <Widget>[
        for (final c in courses)
          for (final m in c.sessions)
            Positioned(
              left: _railWidth + (m.weekday - 1) * dayWidth + 1.5,
              top: y(m.startMinute) + 1,
              width: dayWidth - 3,
              height: y(m.endMinute) - y(m.startMinute) - 2,
              child: _Block(course: c, session: m, onTap: () => onTapCourse(c)),
            ),
      ];

      final nowMinute = now == null ? null : now!.hour * 60 + now!.minute;
      final showNow = now != null &&
          now!.weekday <= days &&
          nowMinute! >= rows.first.start &&
          nowMinute < rows.last.end;

      return Column(
        children: [
          // Weekday header; today's column is marked
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                const SizedBox(width: _railWidth),
                for (var d = 1; d <= days; d++)
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
                // A line under each row, and a tap target per empty cell
                for (var i = 0; i <= rows.length; i++)
                  Positioned(
                    left: _railWidth,
                    right: 0,
                    top: i == rows.length ? height - 1 : i * rowHeight,
                    child: Container(height: 1, color: lineColor),
                  ),
                for (var d = 1; d <= days; d++)
                  Positioned(
                    left: _railWidth + (d - 1) * dayWidth,
                    top: 0,
                    bottom: 0,
                    width: dayWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // The row tapped, from its start: a new course usually
                      // begins with a period (or on the hour)
                      onTapUp: (details) => onTapEmpty(
                        d,
                        rows[(details.localPosition.dy / rowHeight).floor().clamp(0, rows.length - 1)].start,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: now?.weekday == d ? AppColors.primaryLight.withValues(alpha: 0.35) : null,
                          // The last day closes the grid on the right, so the
                          // week does not look as if it ran on past the edge
                          border: Border(
                            left: BorderSide(color: lineColor),
                            right: d == days ? BorderSide(color: lineColor) : BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                for (var i = 0; i < rows.length; i++)
                  Positioned(
                    left: 0,
                    width: _railWidth - 4,
                    top: i * rowHeight + 2,
                    child: Text(
                      byPeriod ? '${rows[i].label}\n${formatMinute(rows[i].start)}' : formatMinute(rows[i].start),
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
