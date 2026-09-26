import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/review_stats.dart' show termAt;
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../providers/courses_provider.dart';
import '../providers/date_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/timetable_screen.dart';
import 'coach_mark.dart' show TourAnchor;
import 'course_sheet.dart' show formatMinute;

// "Today's classes" on the task page (UC18): a line of chips, the one on now
// in bold, the next marked, the ones over faded. Takes no space at all on a
// day without classes, or outside the teaching weeks once a first day is set
class TodayClassesStrip extends ConsumerWidget {
  const TodayClassesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(dateProvider);
    final nowDay = ref.watch(effectiveNowProvider);
    final settings = ref.watch(semesterSettingsProvider);
    final semester = termAt(day, settings);
    final term = ref.watch(termsProvider)[semester];
    if (term != null && !inTerm(day, term.firstDay, term.weeks)) return const SizedBox.shrink();

    final meetings = meetingsOn(day, semester, ref.watch(coursesProvider));
    if (meetings.isEmpty) return const SizedBox.shrink();

    // States only mean something for today; another day's classes are all "later"
    final isToday = day.year == nowDay.year && day.month == nowDay.month && day.day == nowDay.day;
    final clock = DateTime.now();
    final states = isToday
        ? meetingStates(meetings, DateTime(day.year, day.month, day.day, clock.hour, clock.minute))
        : List.filled(meetings.length, MeetingState.later);
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;

    return TourAnchor(
      id: 'today.classes',
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: meetings.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, i) {
              final m = meetings[i];
              final state = states[i];
              final color = Color(m.course.color);
              final tag = switch (state) {
                MeetingState.now => s.classNow,
                MeetingState.next => s.classNext,
                _ => null,
              };
              return Opacity(
                opacity: state == MeetingState.done ? 0.45 : 1,
                child: Material(
                  color: color.withValues(alpha: state == MeetingState.now ? 0.28 : 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TimetableScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 3, height: 24, color: color),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            formatMinute(m.session.startMinute),
                            style: theme.labelMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              [m.course.title, ?m.session.location].join('・'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.labelLarge?.copyWith(
                                fontWeight: state == MeetingState.now ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (tag != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Text(tag, style: theme.labelSmall?.copyWith(color: AppColors.primary)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
