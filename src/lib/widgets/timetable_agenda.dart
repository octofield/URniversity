import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../core/ui_symbols.dart';
import '../l10n/app_strings.dart';
import '../models/course.dart';
import 'course_sheet.dart' show formatMinute;
import 'timetable_grid.dart' show formatCredits;

// The agenda timetable style (system_design.md §3-S, 2026-10-04): not a grid
// but a day at a time — a strip of weekdays with a dot per class, and the
// picked day's classes down a time line, the one under way marked. Made for a
// phone, where five columns leave each course a sliver. [allDays] lists every
// day with classes one after another: the exported picture
class TimetableAgenda extends StatefulWidget {
  final List<Course> courses;
  final AppStrings s;
  // Today, when this week is showing: picked first, and its class under way
  // marked
  final DateTime? now;
  final ValueChanged<Course> onTapCourse;
  final bool allDays;

  const TimetableAgenda({
    super.key,
    required this.courses,
    required this.s,
    required this.now,
    required this.onTapCourse,
    this.allDays = false,
  });

  @override
  State<TimetableAgenda> createState() => _TimetableAgendaState();
}

class _TimetableAgendaState extends State<TimetableAgenda> {
  int? _picked;

  List<ClassMeeting> _on(int weekday) => [
        for (final c in widget.courses)
          for (final m in c.sessions)
            if (m.weekday == weekday) ClassMeeting(c, m),
      ]..sort((a, b) => a.session.startMinute.compareTo(b.session.startMinute));

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final days = gridBounds([for (final c in widget.courses) ...c.sessions]).days;
    final today = widget.now?.weekday;
    // Today if it is in the week shown, else the first day with a class
    final picked = _picked ??
        (today != null && today <= days
            ? today
            : [for (var d = 1; d <= days; d++) d].firstWhere((d) => _on(d).isNotEmpty, orElse: () => 1));

    if (widget.allDays) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var d = 1; d <= days; d++)
            if (_on(d).isNotEmpty) ...[
              _DayHeading(text: '${s.weekdayFull(d)}$kDotSeparator${s.agendaClassCount(_on(d).length)}'),
              _Timeline(meetings: _on(d), s: s, nowMinute: null, onTapCourse: widget.onTapCourse),
            ],
        ],
      );
    }

    final meetings = _on(picked);
    final nowMinute = widget.now != null && picked == today ? widget.now!.hour * 60 + widget.now!.minute : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var d = 1; d <= days; d++) ...[
              if (d > 1) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _DayButton(
                  label: s.weekdayShort(d),
                  dots: [for (final m in _on(d).take(3)) Color(m.course.color)],
                  picked: d == picked,
                  today: d == today,
                  onTap: () => setState(() => _picked = d),
                ),
              ),
            ],
          ],
        ),
        _DayHeading(
          text: meetings.isEmpty
              ? '${s.weekdayFull(picked)}$kDotSeparator${s.agendaNoClasses}'
              : '${s.weekdayFull(picked)}$kDotSeparator${s.agendaClassCount(meetings.length)}',
        ),
        _Timeline(meetings: meetings, s: s, nowMinute: nowMinute, onTapCourse: widget.onTapCourse),
      ],
    );
  }
}

class _DayButton extends StatelessWidget {
  final String label;
  final List<Color> dots;
  final bool picked;
  final bool today;
  final VoidCallback onTap;

  const _DayButton({
    required this.label,
    required this.dots,
    required this.picked,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: picked ? AppColors.primary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: picked ? BorderSide.none : BorderSide(color: today ? AppColors.primary : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: theme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  // On the primary fill: the style's surface, light on dark
                  // styles' bright primary and the reverse, as a filled chip
                  color: picked ? AppColors.surface : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in dots)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  final String text;
  const _DayHeading({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
        ),
      );
}

class _Timeline extends StatelessWidget {
  final List<ClassMeeting> meetings;
  final AppStrings s;
  // Minutes past midnight now, when this is today's list
  final int? nowMinute;
  final ValueChanged<Course> onTapCourse;

  const _Timeline({required this.meetings, required this.s, required this.nowMinute, required this.onTapCourse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < meetings.length; i++)
          _entry(context, theme, meetings[i], last: i == meetings.length - 1),
      ],
    );
  }

  Widget _entry(BuildContext context, TextTheme theme, ClassMeeting m, {required bool last}) {
    final color = Color(m.course.color);
    final under = nowMinute != null && m.session.startMinute <= nowMinute! && nowMinute! < m.session.endMinute;
    final meta = [
      if (m.session.location != null) m.session.location!,
      if (m.course.credits > 0) s.creditsCount(formatCredits(m.course.credits)),
    ].join(kDotSeparator);
    // The time line is painted behind the row rather than sized to it with
    // IntrinsicHeight: a long title just makes the row taller
    return Stack(
      children: [
        if (!last)
          Positioned(
            left: 52 + AppSpacing.sm + 8,
            top: 26,
            bottom: 0,
            child: Container(width: 2, color: AppColors.border),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatMinute(m.session.startMinute), style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(formatMinute(m.session.endMinute), style: theme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: 18,
                  height: 12,
                  alignment: Alignment.center,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: under ? color : AppColors.border, width: under ? 1.5 : 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTapCourse(m.course),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(m.course.title, style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              ),
                              if (under)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(AppRadius.full),
                                  ),
                                  child: Text(
                                    s.classNow,
                                    style: theme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                          if (meta.isNotEmpty)
                            Text(meta, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
