import 'package:flutter/material.dart';
import '../core/period_tables.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../l10n/app_strings.dart';
import '../models/course.dart';
import '../providers/timetable_style_provider.dart';
import 'course_sheet.dart' show formatMinute;

// The week at a glance (system_design.md §3-S): a column per day, Monday to
// Friday unless something meets at the weekend, and a row per period of the
// user's school, like a printed timetable ("3｜10:20"); a school without a
// period table gets a row per hour.
//
// A Stack of Positioned blocks rather than rows of cells: a meeting is placed
// through rowPosition, so 10:20–12:10 fills periods 3–4 exactly, and nothing
// needs IntrinsicHeight (which has cut off content here before).
//
// [style] changes only the drawing (2026-10-04): the lines, the left rail and
// the blocks. The agenda style is not a grid and has its own widget
class TimetableGrid extends StatelessWidget {
  final List<Course> courses;
  final List<ClassPeriod>? periods;
  final AppStrings s;
  // Draws the "now" line in this weekday's column, when this week is showing
  final DateTime? now;
  final ValueChanged<Course> onTapCourse;
  final void Function(int weekday, int minute) onTapEmpty;
  final TimetableStyle style;

  const TimetableGrid({
    super.key,
    required this.courses,
    required this.periods,
    required this.s,
    required this.now,
    required this.onTapCourse,
    required this.onTapEmpty,
    this.style = TimetableStyle.standard,
  });

  static const _railWidth = 48.0;
  static const _headerHeight = 32.0;
  // A period is 50 minutes; an hour row is a little taller for its 60
  static const _periodHeight = 56.0;
  static const _hourHeight = 60.0;
  // Compact: short enough for a whole week on one phone screen
  static const _compactPeriodHeight = 40.0;
  static const _compactHourHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final sessions = [for (final c in courses) ...c.sessions];
    final days = gridBounds(sessions).days;
    final rows = gridRows(periods, sessions);
    // Hour rows carry no label; period rows do
    final byPeriod = rows.first.label.isNotEmpty;
    final compact = style == TimetableStyle.compact;
    final rowHeight = byPeriod ? (compact ? _compactPeriodHeight : _periodHeight) : (compact ? _compactHourHeight : _hourHeight);
    double y(int minute) => rowPosition(rows, minute) * rowHeight;
    final paper = style == TimetableStyle.paper;
    final inverse = style == TimetableStyle.inverse;
    final notebook = style == TimetableStyle.notebook;
    // The paper table is ruled in ink, the notebook in the style's colour, the
    // board in chalk; the others barely
    final lineColor = switch (style) {
      TimetableStyle.paper => AppColors.textSecondary.withValues(alpha: 0.45),
      TimetableStyle.notebook => AppColors.primary.withValues(alpha: 0.25),
      TimetableStyle.inverse => AppColors.surface.withValues(alpha: 0.22),
      _ => AppColors.border.withValues(alpha: 0.6),
    };
    // On the board, the labels are in the page's own background colour
    final labelColor = inverse ? AppColors.surface.withValues(alpha: 0.75) : AppColors.textTertiary;
    // Lines between the days: only where the week is a ruled table
    final columnLines = style == TimetableStyle.standard || paper || compact;
    final frame = BorderSide(color: AppColors.textSecondary, width: 1.5);
    // How far a block sits inside its cells: the paper table keeps its rules
    // showing, the cards float a little
    final inset = switch (style) {
      TimetableStyle.paper => 1.0,
      TimetableStyle.solid || TimetableStyle.outline => 2.0,
      _ => 1.5,
    };

    // The board is drawn round the whole week, so the days are measured inside it
    return Container(
      decoration: inverse
          ? BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(AppRadius.lg))
          : null,
      padding: EdgeInsets.all(inverse ? AppSpacing.xs : 0),
      child: LayoutBuilder(builder: (context, constraints) {
      final dayWidth = (constraints.maxWidth - _railWidth) / days;
      final height = rows.length * rowHeight;

      final blocks = <Widget>[
        for (final c in courses)
          for (final m in c.sessions)
            Positioned(
              left: _railWidth + (m.weekday - 1) * dayWidth + inset,
              top: y(m.startMinute) + (paper ? 1 : inset - 0.5),
              width: dayWidth - (paper ? 1 : inset * 2),
              height: y(m.endMinute) - y(m.startMinute) - (paper ? 1 : inset * 2 - 1),
              child: _Block(
                course: c,
                session: m,
                style: style,
                credits: c.credits > 0 ? s.creditsCount(formatCredits(c.credits)) : null,
                onTap: () => onTapCourse(c),
              ),
            ),
      ];

      final nowMinute = now == null ? null : now!.hour * 60 + now!.minute;
      final showNow = now != null &&
          now!.weekday <= days &&
          nowMinute! >= rows.first.start &&
          nowMinute < rows.last.end;

      return Column(
        children: [
          // Weekday header; today's column is marked. On paper it is a shaded
          // band ruled off from the week below
          Container(
            height: _headerHeight,
            decoration: paper
                ? BoxDecoration(
                    color: AppColors.surfaceVariant,
                    border: Border(top: frame, left: frame, right: frame, bottom: frame),
                  )
                : null,
            child: Row(
              children: [
                SizedBox(width: paper ? _railWidth - 1.5 : _railWidth),
                for (var d = 1; d <= days; d++)
                  Container(
                    width: d == days && paper ? dayWidth - 1.5 : dayWidth,
                    decoration: paper ? BoxDecoration(border: Border(left: BorderSide(color: lineColor))) : null,
                    child: Center(
                      child: Text(
                        s.weekdayShort(d),
                        style: theme.labelLarge?.copyWith(
                          color: inverse
                              ? AppColors.surface
                              : now?.weekday == d
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
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
                // Solid: every other row a soft band in place of lines
                if (style == TimetableStyle.solid)
                  for (var i = 0; i < rows.length; i += 2)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: i * rowHeight,
                      height: rowHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                // Paper: the rail is part of the table, shaded like the header
                if (paper)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _railWidth,
                    child: Container(color: AppColors.background),
                  ),
                // A line under each row (dashed for outline, from the rail's
                // edge on paper), and a tap target per empty cell
                // The notebook's margin, down the rail's edge
                if (notebook)
                  Positioned(
                    left: _railWidth - 3,
                    top: 0,
                    bottom: 0,
                    width: 1.5,
                    child: Container(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                if (style != TimetableStyle.solid && style != TimetableStyle.pastel)
                  for (var i = 0; i <= rows.length; i++)
                    Positioned(
                      left: paper ? 0 : _railWidth,
                      right: 0,
                      top: i == rows.length ? height - 1 : i * rowHeight,
                      child: style == TimetableStyle.outline
                          ? CustomPaint(size: const Size.fromHeight(1), painter: _DashedLine(lineColor))
                          : Container(height: 1, color: lineColor),
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
                          color: now?.weekday == d && style != TimetableStyle.solid && !inverse
                              ? AppColors.primaryLight.withValues(alpha: 0.35)
                              : null,
                          // The last day closes the grid on the right, so the
                          // week does not look as if it ran on past the edge.
                          // The open styles go without column lines
                          border: columnLines
                              ? Border(
                                  left: BorderSide(color: lineColor),
                                  right: d == days && !paper ? BorderSide(color: lineColor) : BorderSide.none,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                for (var i = 0; i < rows.length; i++)
                  if (paper)
                    // A printed table's rail: the period large, its time small,
                    // both in the middle of the row
                    Positioned(
                      left: 0,
                      width: _railWidth,
                      top: i * rowHeight,
                      height: rowHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (byPeriod)
                            Text(rows[i].label, style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            formatMinute(rows[i].start),
                            style: theme.labelSmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    Positioned(
                      left: 0,
                      width: _railWidth - 4,
                      top: i * rowHeight + 2,
                      child: Text(
                        byPeriod ? '${rows[i].label}\n${formatMinute(rows[i].start)}' : formatMinute(rows[i].start),
                        textAlign: TextAlign.center,
                        style: theme.labelSmall?.copyWith(color: labelColor, height: 1.2),
                      ),
                    ),
                ...blocks,
                // Paper: the table's outer rule (the header carries the top),
                // over the blocks — drawn under them, a course on the last day
                // covered the right edge (reported 2026-10-10)
                if (paper)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(border: Border(left: frame, right: frame, bottom: frame)),
                      ),
                    ),
                  ),
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
    }),
    );
  }
}

// A course's credits as a person writes them: 3, 2.5
String formatCredits(double c) => c == c.roundToDouble() ? c.toInt().toString() : c.toString();

// Text on a course's own colour: that colour is the user's data and the same in
// every style, so the text is chosen against it rather than taken from AppColors:
// white or near-black, whichever has the higher WCAG contrast. Flutter's
// estimateBrightnessForColor put white on a deepened yellow at about 2.9:1
Color _onCourseColor(Color fill) {
  final l = fill.computeLuminance();
  return 1.05 / (l + 0.05) >= (l + 0.05) / 0.05 ? Colors.white : Colors.black87;
}

class _Block extends StatelessWidget {
  final Course course;
  final CourseSession session;
  final TimetableStyle style;
  // "3 學分", or null for a course with none
  final String? credits;
  final VoidCallback onTap;

  const _Block({
    required this.course,
    required this.session,
    required this.style,
    this.credits,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final color = Color(course.color);
    // Solid: the course colour deepened, so white text reads on most of them
    final fill = Color.lerp(color, Colors.black, 0.28)!;
    // Pastel: a light tint of it over the page
    final tint = Color.alphaBlend(color.withValues(alpha: 0.28), AppColors.background);
    final (Color background, ShapeBorder shape, Color title, Color secondary) = switch (style) {
      TimetableStyle.solid => (
          fill,
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          _onCourseColor(fill),
          _onCourseColor(fill).withValues(alpha: 0.85),
        ),
      TimetableStyle.outline => (
          AppColors.surface,
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(color: color, width: 1.5),
          ),
          AppColors.textPrimary,
          AppColors.textSecondary,
        ),
      TimetableStyle.paper => (
          AppColors.surface,
          const RoundedRectangleBorder(),
          AppColors.textPrimary,
          AppColors.textSecondary,
        ),
      // The board's blocks are filled in like solid ones
      TimetableStyle.inverse => (
          fill,
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          _onCourseColor(fill),
          _onCourseColor(fill).withValues(alpha: 0.85),
        ),
      TimetableStyle.pastel => (
          tint,
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          _deepTone(color, tint),
          AppColors.textSecondary,
        ),
      // No box at all: the name is marked as with a highlighter instead
      TimetableStyle.notebook => (
          Colors.transparent,
          const RoundedRectangleBorder(),
          AppColors.textPrimary,
          AppColors.textSecondary,
        ),
      _ => (
          color.withValues(alpha: 0.18),
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
          AppColors.textPrimary,
          AppColors.textSecondary,
        ),
    };
    final paper = style == TimetableStyle.paper;
    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: style == TimetableStyle.standard || style == TimetableStyle.compact
              ? BoxDecoration(border: Border(left: BorderSide(color: color, width: 3)))
              : null,
          padding: switch (style) {
            TimetableStyle.standard || TimetableStyle.compact => const EdgeInsets.fromLTRB(4, 3, 3, 2),
            TimetableStyle.paper => const EdgeInsets.all(2),
            _ => const EdgeInsets.fromLTRB(5, 4, 4, 3),
          },
          child: LayoutBuilder(builder: (context, c) {
            // As many lines as the block has room for; the title always first.
            // Paper gives one line to its colour mark
            final lines = ((c.maxHeight - (paper ? 7 : 0)) / 14).floor().clamp(1, 6);
            // Compact keeps to the name; elsewhere the credits only once the
            // title and room have a line each
            final titleOnly = style == TimetableStyle.compact;
            final showRoom = !titleOnly && lines > 1 && session.location != null;
            final showCredits = !titleOnly && credits != null && lines > 2;
            final below = (showRoom ? 1 : 0) + (showCredits ? 1 : 0);
            final align = paper ? TextAlign.center : TextAlign.start;
            final titleText = Text(
              course.title,
              maxLines: lines - below > 0 ? lines - below : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: align,
              style: theme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: title,
                // The notebook's highlighter stroke, in the course colour
                background: style == TimetableStyle.notebook ? (Paint()..color = color.withValues(alpha: 0.35)) : null,
              ),
            );
            return Column(
              crossAxisAlignment: paper ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              mainAxisAlignment: paper ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                // Paper: a short bar of the course colour above the name
                if (paper)
                  Container(
                    width: 18,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.xs)),
                  ),
                Flexible(
                  child: style == TimetableStyle.outline
                      // Outline: a dot of the course colour before the name
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 5, right: 3),
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            Expanded(child: titleText),
                          ],
                        )
                      : titleText,
                ),
                if (showRoom)
                  Text(
                    session.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: align,
                    style: theme.labelSmall?.copyWith(color: secondary),
                  ),
                if (showCredits)
                  Text(
                    credits!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: align,
                    style: theme.labelSmall?.copyWith(
                      color: style == TimetableStyle.solid ? secondary : AppColors.textTertiary,
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// Pastel: the course colour taken deep enough to read on its own tint; a
// colour that will not get there gives way to the body text colour
Color _deepTone(Color color, Color tint) {
  final deep = Color.lerp(color, Colors.black, 0.6)!;
  final a = deep.computeLuminance();
  final b = tint.computeLuminance();
  final ratio = (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
  return ratio >= 4.5 ? deep : AppColors.textPrimary;
}

// The outline style's hour lines
class _DashedLine extends CustomPainter {
  final Color color;
  const _DashedLine(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 4 < size.width ? x + 4 : size.width, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
