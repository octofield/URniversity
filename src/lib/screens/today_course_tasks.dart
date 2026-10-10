part of 'today_screen.dart';

// The course view (system_design.md §2-B, 2026-10-10): this semester's
// courses in the order they first meet in the week, each with its tasks still
// to do, a "+" that adds one already linked and due at its next class, and the
// done ones folded under a count. A course with nothing to do still shows, so
// the "+" is there for it

class _CourseTasksView extends ConsumerStatefulWidget {
  const _CourseTasksView();

  @override
  ConsumerState<_CourseTasksView> createState() => _CourseTasksViewState();
}

class _CourseTasksViewState extends ConsumerState<_CourseTasksView> {
  // Courses whose done tasks are showing. In memory only, like the
  // completed section of the other views
  final _showDone = <String>{};

  // When a course first meets in the week; one with no meetings goes last
  static int _firstMeeting(Course c) => c.sessions.isEmpty
      ? 1 << 30
      : c.sessions.map((m) => m.weekday * 24 * 60 + m.startMinute).reduce(min);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final now = ref.watch(effectiveNowProvider);
    final semester = termAt(now, ref.watch(semesterSettingsProvider));
    final courses = ref.watch(coursesProvider).where((c) => c.semester == semester).toList()
      ..sort((a, b) {
        final byTime = _firstMeeting(a).compareTo(_firstMeeting(b));
        return byTime != 0 ? byTime : a.title.compareTo(b.title);
      });
    final tasks = ref.watch(tasksProvider);
    const padding = EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 12, AppSpacing.pageHorizontal, AppSpacing.xl);

    if (courses.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          Text(s.courseViewEmpty, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openPage(context, AppRoutes.timetable, () => const TimetableScreen()),
              icon: const Icon(Icons.calendar_view_week_outlined),
              label: Text(s.timetable),
            ),
          ),
        ],
      );
    }

    // Done for the occurrence each row is about, as in the all-tasks view
    bool done(Task t) => t.isCompletedOn(currentOccurrence(t, now) ?? now);

    return ListView(
      padding: padding,
      children: [
        for (final course in courses) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: Color(course.color), shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(course.title, style: theme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: s.addTask,
                onPressed: () => showTaskSheet(
                  context,
                  ref,
                  courseId: course.id,
                  due: nextMeetingStart(course, DateTime.now()),
                ),
              ),
            ],
          ),
          ..._group(context, s, course, [for (final t in tasks) if (t.courseId == course.id) t], done),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  List<Widget> _group(BuildContext context, AppStrings s, Course course, List<Task> mine, bool Function(Task) done) {
    final theme = Theme.of(context).textTheme;
    final open = [for (final t in mine) if (!done(t)) t];
    final closed = [for (final t in mine) if (done(t)) t];
    final showing = _showDone.contains(course.id);
    Widget card(List<Task> rows) => Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                TaskTile(task: rows[i]),
              ],
            ],
          ),
        );
    return [
      if (open.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.lg),
          child: Text(s.noTasks, style: theme.bodySmall?.copyWith(color: AppColors.textTertiary)),
        )
      else
        card(open),
      if (closed.isNotEmpty) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => showing ? _showDone.remove(course.id) : _showDone.add(course.id)),
            icon: Icon(showing ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(s.completedTasksWithCount(closed.length)),
          ),
        ),
        if (showing) card(closed),
      ],
    ];
  }
}
