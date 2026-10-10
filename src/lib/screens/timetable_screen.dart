import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_routes.dart';
import '../core/period_tables.dart';
import '../core/review_stats.dart' show termAt;
import '../core/theme/app_colors.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/timetable.dart';
import '../l10n/app_strings.dart';
import '../providers/course_catalog_provider.dart';
import '../providers/courses_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/synced_list_notifier.dart' show reportSyncErrorFromWidget;
import '../utils/semester_helpers.dart';
import '../widgets/catalog_search_sheet.dart';
import '../widgets/course_sheet.dart';
import '../widgets/grades_view.dart';
import '../widgets/responsive_body.dart';
import '../widgets/swipe_switcher.dart';
import '../widgets/term_dialog.dart';
import '../widgets/timetable_agenda.dart';
import '../widgets/timetable_grid.dart';
import '../providers/timetable_style_provider.dart';
import '../providers/remote_config_provider.dart';
import '../core/save_image/save_image.dart';
import '../core/ui_symbols.dart';
import '../widgets/app_page.dart';

// The timetable and the grades (UC18, UC20). One screen with two views,
// because a grade is entered on the course it belongs to
class TimetableScreen extends ConsumerStatefulWidget {
  // Opens on the grades view instead of the week
  final bool grades;
  const TimetableScreen({super.key, this.grades = false});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  late bool _grades = widget.grades;
  // The semester the week shows; starts on the one running today
  late String _semester = termAt(ref.read(effectiveNowProvider), ref.read(semesterSettingsProvider));
  // Which way the last change went, so the pages slide the matching way
  bool _forward = true;
  // The week as a picture: drawn once more without the now line and with the
  // semester's name on top, captured, then back to normal
  final _exportKey = GlobalKey();
  bool _exporting = false;

  Future<void> _export(AppStrings s) async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final png = await capturePng(_exportKey);
      if (png == null) return;
      await savePng(png, 'URniversity-$_semester.png');
    } catch (e) {
      // Nothing of the user's is lost: say so, and let them try again
      messenger.showSnackBar(SnackBar(content: Text(s.exportFailed)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<String> get _semesters {
    // Regular terms only (no breaks), newest last, and always the one showing
    final all = generateSemesters(ref.read(semesterSettingsProvider))
        .where((t) => RegExp(r'^\d+-\d+$').hasMatch(t))
        .toList();
    if (!all.contains(_semester)) all.add(_semester);
    return all;
  }

  String? _neighbour(int delta) {
    final list = _semesters;
    final i = list.indexOf(_semester) + delta;
    return i < 0 || i >= list.length ? null : list[i];
  }

  void _show({required bool grades, required String semester, required bool forward}) {
    setState(() {
      _grades = grades;
      _semester = semester;
      _forward = forward;
    });
  }

  void _step(int delta) {
    final other = _neighbour(delta);
    if (other != null) _show(grades: _grades, semester: other, forward: delta > 0);
  }

  // The pages in one line, a semester's week then its grades: … last term's
  // grades · this week · this term's grades · next term's week … A swipe to the
  // left moves along it, to the right moves back
  void _next() {
    if (!_grades) {
      _show(grades: true, semester: _semester, forward: true);
    } else if (_neighbour(1) case final next?) {
      _show(grades: false, semester: next, forward: true);
    }
  }

  void _previous() {
    if (_grades) {
      _show(grades: false, semester: _semester, forward: false);
    } else if (_neighbour(-1) case final previous?) {
      _show(grades: true, semester: previous, forward: false);
    }
  }

  // Straight into the user's own school's search, the other schools with a
  // catalog this semester one chip away (a cross-registered course is in the
  // other school's catalog). No school to search — none yet, or offline —
  // opens adding by hand, which always works
  Future<void> _add() async {
    // Catalog search switched off from the admin backend: by hand only
    if (!ref.read(featureOnProvider('catalog_search'))) {
      showCourseSheet(context, semester: _semester);
      return;
    }
    final mySchool = ref.read(profileProvider)?.school;
    List<CatalogSchool> all;
    try {
      all = await ref.read(catalogSchoolsProvider.future);
    } catch (e) {
      reportSyncErrorFromWidget(ref, e, where: 'catalog_schools read');
      all = const [];
    }
    if (!mounted) return;
    final here = [
      for (final school in all)
        if (school.semesters.contains(_semester)) school,
    ]..sort((a, b) => (b.name == mySchool ? 1 : 0) - (a.name == mySchool ? 1 : 0));
    if (here.isEmpty) {
      showCourseSheet(context, semester: _semester);
    } else {
      showCatalogSearch(context, schools: here, semester: _semester);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final theme = Theme.of(context).textTheme;
    final settings = ref.watch(semesterSettingsProvider);
    final now = ref.watch(effectiveNowProvider);
    final clock = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, clock.hour, clock.minute);
    final courses = ref.watch(coursesProvider).where((c) => c.semester == _semester).toList();
    final term = ref.watch(effectiveTermsProvider)[_semester];
    final fromSchool = term != null && ref.watch(termsProvider)[_semester] == null;
    final periods = periodsFor(ref.watch(profileProvider)?.school);
    final style = ref.watch(timetableStyleProvider);
    final isCurrent = _semester == termAt(now, settings);

    final String? weekLabel;
    if (term == null) {
      weekLabel = null;
    } else {
      final w = weekOfTerm(today, term.firstDay);
      weekLabel = w < 1
          ? s.timetableBeforeTerm
          : w > term.weeks
              ? s.timetableAfterTerm
              : s.timetableWeek(w);
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0, AppSpacing.pageHorizontal, AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _step(-1),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  formatSemester(_semester, settings, s),
                  textAlign: TextAlign.center,
                  style: theme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _step(1),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(s.timetable), icon: const Icon(Icons.calendar_view_week_outlined)),
              ButtonSegment(value: true, label: Text(s.grades), icon: const Icon(Icons.school_outlined)),
            ],
            selected: {_grades},
            onSelectionChanged: (v) => _show(grades: v.first, semester: _semester, forward: v.first),
          ),
        ],
      ),
    );

    final credits = s.semesterCredits(formatCredits(courses.fold<double>(0, (sum, c) => sum + c.credits)));
    final week = ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0, AppSpacing.pageHorizontal, 96),
      children: [
        Row(
          children: [
            ActionChip(
              avatar: Icon(term == null ? Icons.event_outlined : Icons.event_available_outlined, size: 18),
              label: Text(weekLabel == null ? s.setFirstDay : fromSchool ? s.termFromSchool(weekLabel) : weekLabel),
              onPressed: () => editTermStart(context, ref, _semester),
            ),
            const Spacer(),
            Text(credits, style: theme.labelLarge?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (courses.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(s.noCoursesYet, style: theme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
        RepaintBoundary(
          key: _exportKey,
          child: ColoredBox(
            color: AppColors.background,
            // The picture gets a margin and a frame: edge to edge it looked
            // cut off once shared (2026-10-04). On screen nothing changes
            child: Padding(
              padding: EdgeInsets.all(_exporting ? AppSpacing.lg : 0),
              child: DecoratedBox(
                decoration: _exporting
                    ? BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      )
                    : const BoxDecoration(),
                child: Padding(
                  padding: EdgeInsets.all(_exporting ? AppSpacing.md : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_exporting)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text('${formatSemester(_semester, settings, s)}$kDotSeparator$credits', style: theme.titleMedium),
                        ),
                      // The agenda is not a grid; exported, it lists the whole
                      // week, which is all the week list ever shows
                      if (style == TimetableStyle.agenda || style == TimetableStyle.weekList)
                        TimetableAgenda(
                          courses: courses,
                          s: s,
                          now: isCurrent && !_exporting ? today : null,
                          allDays: _exporting || style == TimetableStyle.weekList,
                          onTapCourse: (c) => showCourseSheet(context, semester: _semester, existing: c),
                        )
                      else
                        TimetableGrid(
                          courses: courses,
                          periods: periods,
                          s: s,
                          style: style,
                          now: isCurrent && !_exporting ? today : null,
                          onTapCourse: (c) => showCourseSheet(context, semester: _semester, existing: c),
                          onTapEmpty: (weekday, minute) =>
                              showCourseSheet(context, semester: _semester, weekday: weekday, startMinute: minute),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return AppPage(swipeBack: false, child: Scaffold(
      appBar: AppBar(
        title: Text(_grades ? s.grades : s.timetable),
        leading: homeButtonIfFirst(context),
        actions: [
          // How the week is drawn (§3-S); the grades view has no week to draw
          if (!_grades)
            PopupMenuButton<TimetableStyle>(
              icon: const Icon(Icons.palette_outlined),
              tooltip: s.timetableStyle,
              initialValue: style,
              onSelected: (picked) => ref.read(timetableStyleProvider.notifier).set(picked),
              itemBuilder: (_) => [
                for (final option in TimetableStyle.values)
                  CheckedPopupMenuItem(
                    value: option,
                    checked: option == style,
                    child: Text(switch (option) {
                      TimetableStyle.standard => s.timetableStyleStandard,
                      TimetableStyle.solid => s.timetableStyleSolid,
                      TimetableStyle.outline => s.timetableStyleOutline,
                      TimetableStyle.paper => s.timetableStylePaper,
                      TimetableStyle.agenda => s.timetableStyleAgenda,
                      TimetableStyle.compact => s.timetableStyleCompact,
                      TimetableStyle.pastel => s.timetableStylePastel,
                      TimetableStyle.inverse => s.timetableStyleInverse,
                      TimetableStyle.notebook => s.timetableStyleNotebook,
                      TimetableStyle.weekList => s.timetableStyleWeekList,
                    }),
                  ),
              ],
            ),
          if (!_grades)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: s.exportTimetable,
              onPressed: _exporting ? null : () => _export(s),
            ),
        ],
      ),
      floatingActionButton: _grades
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(s.addCourse),
            ),
      // Pulled down from the top, either page closes
      body: ResponsiveBody(
          // The week needs more room than a list does
          maxWidth: 960,
          child: Column(
            children: [
              header,
              Expanded(
                child: SwipeSwitcher(
                  onNext: _next,
                  onPrevious: _previous,
                  // Material's shared axis, as between the review's steps: the
                  // page arriving slides in from the side it lies on
                  child: PageTransitionSwitcher(
                    duration: scaled(context, AppMotion.page),
                    reverse: !_forward,
                    transitionBuilder: (child, primary, secondary) => SharedAxisTransition(
                      animation: primary,
                      secondaryAnimation: secondary,
                      transitionType: SharedAxisTransitionType.horizontal,
                      fillColor: Colors.transparent,
                      child: child,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey('$_semester $_grades'),
                      child: _grades ? GradesView(semester: _semester) : week,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ));
  }
}

// First day of classes and how many weeks of teaching
