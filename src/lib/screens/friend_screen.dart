import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/input_limits.dart';
import '../core/period_tables.dart';
import '../core/recent_picks.dart' show formatClock;
import '../core/review_stats.dart' show termAt;
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../l10n/app_strings.dart';
import '../models/friend.dart';
import '../providers/courses_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/timetable_style_provider.dart';
import '../widgets/app_page.dart';
import '../widgets/course_sheet.dart' show formatMinute;
import '../widgets/empty_state.dart';
import '../widgets/responsive_body.dart';
import '../widgets/sync_controls.dart';
import '../widgets/timetable_agenda.dart';
import '../widgets/timetable_grid.dart';
import 'friends_screen.dart' show friendAvatar, friendName;

// One friend (system_design.md §2-P, UC24): only what they have switched on,
// a tab each. Phase 7-1 has their timetable and, when the user shares theirs
// too, the times both are free. Nothing here can be changed
class FriendScreen extends ConsumerWidget {
  final FriendEntry entry;

  const FriendScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final list = ref.watch(friendListProvider).valueOrNull;
    // The latest word on what they share; gone from the list means no longer
    // friends, and nothing is shown
    final current = list == null
        ? entry
        : list.where((f) => f.friendshipId == entry.friendshipId && f.status == FriendStatus.friend).firstOrNull;
    final shares = current?.shares ?? const FriendShares();
    final mine = ref.watch(shareSettingsProvider).valueOrNull ?? const FriendShares();
    final name = friendName(entry, s);

    final tabs = <(String, Widget)>[
      if (shares.timetable) (s.timetable, _FriendTimetableTab(friend: entry, name: name, mineShared: mine.timetable)),
      if (shares.timetable && mine.timetable) (s.commonFreeTime, _CommonFreeTab(friend: entry, name: name)),
    ];

    final title = Row(
      children: [
        friendAvatar(entry.name, entry.avatarIndex, entry.avatarUrl, radius: 16),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );

    if (tabs.isEmpty) {
      return AppPage(child: Scaffold(
        appBar: AppBar(title: title),
        body: ResponsiveBody(
          child: PullToSync(
            child: ListView(children: [
              const SizedBox(height: AppSpacing.xxl),
              EmptyState(icon: Icons.visibility_off_outlined, message: s.friendSharesNothing(name)),
            ]),
          ),
        ),
      ));
    }

    return AppPage(
      // Sideways swipes move between the tabs once there are two
      swipeBack: tabs.length < 2,
      child: DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          appBar: AppBar(
            title: title,
            bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
          ),
          body: ResponsiveBody(
            // A week needs more room than a list, as on the timetable page
            maxWidth: 960,
            child: TabBarView(children: [for (final t in tabs) t.$2]),
          ),
        ),
      ),
    );
  }
}

// The semester shown: the one the user is in now, theirs and the friend's
String _semester(WidgetRef ref) => termAt(ref.watch(effectiveNowProvider), ref.watch(semesterSettingsProvider));

class _FriendTimetableTab extends ConsumerWidget {
  final FriendEntry friend;
  final String name;
  final bool mineShared;

  const _FriendTimetableTab({required this.friend, required this.name, required this.mineShared});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final semester = _semester(ref);
    final async = ref.watch(friendTimetableProvider((friend.userId, semester)));
    final style = ref.watch(timetableStyleProvider);
    final now = DateTime.now();

    final Widget content;
    final data = async.valueOrNull;
    if (data == null) {
      content = async.isLoading
          ? const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
          : EmptyState(
              icon: Icons.visibility_off_outlined,
              message: async.hasError ? s.friendsLoadFailed : s.friendSharesNothing(name),
              compact: true,
            );
    } else if (data.courses.isEmpty) {
      content = EmptyState(icon: Icons.calendar_view_week_outlined, message: s.friendNoCourses, compact: true);
    } else if (style == TimetableStyle.agenda || style == TimetableStyle.weekList) {
      content = TimetableAgenda(
        courses: data.courses,
        s: s,
        now: now,
        allDays: style == TimetableStyle.weekList,
      );
    } else {
      content = TimetableGrid(
        courses: data.courses,
        periods: periodsFor(data.school),
        s: s,
        style: style,
        now: now,
      );
    }

    return PullToSync(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.md, AppSpacing.pageHorizontal, AppSpacing.xl),
        children: [
          content,
          if (!mineShared) ...[
            const SizedBox(height: AppSpacing.md),
            Text(s.commonFreeNeedsYours, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _CommonFreeTab extends ConsumerWidget {
  final FriendEntry friend;
  final String name;

  const _CommonFreeTab({required this.friend, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final semester = _semester(ref);
    final theirs = ref.watch(friendTimetableProvider((friend.userId, semester))).valueOrNull;
    final mine = [
      for (final c in ref.watch(coursesProvider))
        if (c.semester == semester) ...c.sessions,
    ];
    final periods = periodsFor(ref.watch(profileProvider)?.school);
    final slots = theirs == null
        ? const <FreeSlot>[]
        : commonFreeSlots(mine, [for (final c in theirs.courses) ...c.sessions], periods: periods);

    return PullToSync(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, AppSpacing.md, AppSpacing.pageHorizontal, AppSpacing.xl),
        children: [
          Text(s.commonFreeHint, style: theme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          if (theirs == null)
            const Center(child: CircularProgressIndicator())
          else if (slots.isEmpty)
            EmptyState(icon: Icons.event_busy_outlined, message: s.commonFreeNone, compact: true)
          else
            for (final slot in slots)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SlotRow(slot: slot, name: name, s: s),
              ),
        ],
      ),
    );
  }
}

class _SlotRow extends ConsumerWidget {
  final FreeSlot slot;
  final String name;
  final AppStrings s;

  const _SlotRow({required this.slot, required this.name, required this.s});

  void _meet(BuildContext context, WidgetRef ref) {
    final at = nextSlotStart(slot, DateTime.now());
    final title = s.meetTaskTitle(name);
    ref.read(tasksProvider.notifier).add(
          title.length > InputLimits.title ? title.substring(0, InputLimits.title) : title,
          dueTime: at,
        );
    final day = s.dateWithWeekday(
      '${at.month.toString().padLeft(2, '0')}/${at.day.toString().padLeft(2, '0')}',
      s.weekdayShort(at.weekday),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.meetTaskAdded('$day ${formatClock(at)}'))),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.event_available_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${s.weekdayFull(slot.weekday)} ${formatMinute(slot.start)}–${formatMinute(slot.end)}',
              style: theme.titleSmall,
            ),
          ),
          TextButton(
            key: ValueKey('meet.${slot.weekday}.${slot.start}'),
            onPressed: () => _meet(context, ref),
            child: Text(s.meetAtSlot),
          ),
        ],
      ),
    );
  }
}
