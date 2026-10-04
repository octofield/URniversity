import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/core/input_limits.dart';
import 'package:urniversity/core/save_image/save_image.dart';
import 'package:urniversity/core/period_tables.dart';
import 'package:urniversity/core/theme/app_spacing.dart';
import 'package:urniversity/core/timetable.dart' show nextMeetingStart;
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/core/review_stats.dart' show termAt;
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/course.dart';
import 'package:urniversity/providers/course_catalog_provider.dart';
import 'package:urniversity/providers/courses_provider.dart';
import 'package:urniversity/providers/grade_settings_provider.dart';
import 'package:urniversity/providers/profile_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart' show generateSemesters;
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/trash_provider.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/screens/timetable_screen.dart';
import 'package:urniversity/widgets/page_header.dart';
import 'package:urniversity/screens/task_history_screen.dart';
import 'package:urniversity/screens/today_screen.dart' show TodayScreen, TaskTile;
import 'package:urniversity/widgets/timetable_grid.dart';
import 'package:urniversity/widgets/completion_effect.dart' show TaskCheckbox;
import 'package:urniversity/widgets/swipe_switcher.dart';
import 'package:urniversity/widgets/grades_view.dart';
import 'package:urniversity/utils/semester_helpers.dart';
import 'package:urniversity/widgets/today_classes_strip.dart';

import '../helpers/pump_app.dart';

// This semester, the way the screen works it out on a guest's default settings
final _thisSemester = termAt(DateTime.now(), SemesterSettings.defaultSettings);

class _FakeCatalog implements CatalogSource {
  final List<CatalogCourse> rows;
  final List<CatalogSchool> schoolList;
  // Keyed "school entryYear"
  final Map<String, List<DegreeRequirement>> requirementsBy;
  _FakeCatalog(this.rows, this.schoolList, [this.requirementsBy = const {}]);

  @override
  Future<List<CatalogSchool>> schools() async => schoolList;

  @override
  Future<List<CatalogCourse>> search(String school, String semester, String query) async => rows
      .where((r) => r.school == school && (r.title.contains(query) || (r.teacher ?? '').contains(query)))
      .toList();

  @override
  Future<List<CatalogCourse>> byIds(List<String> ids) async => rows.where((r) => ids.contains(r.id)).toList();

  @override
  Future<List<DegreeRequirement>> requirements(String school, int entryYear) async =>
      requirementsBy['$school $entryYear'] ?? const [];
}

// The timetable and the grades (UC18, UC20): adding by hand and from a school's
// catalog, clashes, the trash, the first day of classes, and the GPA cards
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  String semesterNow(ProviderContainer c) =>
      termAt(c.read(effectiveNowProvider), c.read(semesterSettingsProvider));

  final ntu = CatalogSchool(code: 'ntu', name: kNtuSchool, shortName: '台大', semesters: [_thisSemester]);
  final nthu = CatalogSchool(code: 'nthu', name: kNthuSchool, shortName: '清大', semesters: [_thisSemester]);
  const nccu = CatalogSchool(code: 'nccu', name: '國立政治大學', shortName: '政大', semesters: ['100-1']);

  Future<ProviderContainer> open(WidgetTester tester,
      {List<CatalogCourse> catalog = const [],
      List<CatalogSchool>? schools,
      Map<String, List<DegreeRequirement>> requirements = const {},
      bool grades = false}) {
    final c = testContainer(overrides: [
      catalogSourceProvider.overrideWithValue(_FakeCatalog(catalog, schools ?? [ntu, nthu], requirements)),
    ]);
    return pumpScreen(tester, TimetableScreen(grades: grades), container: c, width: 420);
  }

  testWidgets('a course added by hand lands on the grid', (tester) async {
    final c = await open(tester);
    expect(find.text(zh.noCoursesYet), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.addManually));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, zh.courseTitle), '線性代數');
    await tester.tap(find.widgetWithText(FilledButton, zh.addCourse));
    await tester.pumpAndSettle();

    final course = c.read(coursesProvider).single;
    expect(course.title, '線性代數');
    expect(course.semester, semesterNow(c));
    expect(course.sessions.single.weekday, DateTime.monday);
    expect(find.descendant(of: find.byType(TimetableGrid), matching: find.text('線性代數')), findsOneWidget);
  });

  testWidgets('a course with no name is not saved', (tester) async {
    final c = await open(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.addManually));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, zh.addCourse));
    await tester.pumpAndSettle();

    expect(find.text(zh.courseTitleRequired), findsOneWidget);
    expect(c.read(coursesProvider), isEmpty);
  });

  testWidgets('searching the catalog adds a course with all its meetings, and flags a clash', (tester) async {
    final c = await open(tester, catalog: const [
      CatalogCourse(
        id: 'ntu_115-1_1', school: 'ntu', semester: '115-1', title: '微積分甲', teacher: '王老師', credits: 4,
        timeText: '一3,4(新102)三3,4(新102)',
        sessions: [
          CourseSession(weekday: 1, startMinute: 620, endMinute: 730, location: '新102'),
          CourseSession(weekday: 3, startMinute: 620, endMinute: 730, location: '新102'),
        ],
      ),
    ]);
    // Already on Monday 10:20: the search result must say they clash
    c.read(coursesProvider.notifier).add(
          semester: semesterNow(c),
          title: '普通物理',
          sessions: const [CourseSession(weekday: 1, startMinute: 620, endMinute: 670)],
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.searchSchoolCourses('台大')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '微積分');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('微積分甲'), findsOneWidget);
    expect(find.text(zh.clashesWith('普通物理')), findsOneWidget);

    await tester.tap(find.text('微積分甲'));
    await tester.pumpAndSettle();
    final added = c.read(coursesProvider).firstWhere((x) => x.title == '微積分甲');
    expect(added.credits, 4);
    expect(added.catalogId, 'ntu_115-1_1');
    expect(added.sessions.map((s) => (s.weekday, s.startMinute, s.endMinute, s.location)),
        [(1, 620, 730, '新102'), (3, 620, 730, '新102')]);
    expect(find.text(zh.catalogAdded), findsOneWidget, reason: 'the result now says it is taken');
  });

  testWidgets('add opens the user\'s own school, the others one chip away', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_profile', jsonEncode({'school': kNthuSchool}));
    final c = await open(tester, schools: [ntu, nthu, nccu], catalog: const [
      CatalogCourse(
        id: 'nthu_1', school: 'nthu', semester: '115-1', title: '微積分一', timeText: 'BMES醫環618 W2W3W4',
        sessions: [CourseSession(weekday: 3, startMinute: 540, endMinute: 720, location: 'BMES醫環618')],
      ),
      CatalogCourse(id: 'ntu_1', school: 'ntu', semester: '115-1', title: '微積分甲'),
    ]);
    await c.read(profileProvider.notifier).loadGuest();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // Straight in, on the user's own school; the one without a catalog this
    // semester is not offered
    expect(find.text(zh.searchSchoolCourses('清大')), findsOneWidget);
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect([for (final chip in chips) (chip.label as Text).data], ['清大', '台大']);
    expect(chips.first.selected, isTrue);

    await tester.enterText(find.byType(TextField), '微積分');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('微積分甲'), findsNothing, reason: 'only the chosen school');
    await tester.tap(find.text('微積分一'));
    await tester.pumpAndSettle();
    final added = c.read(coursesProvider).single;
    expect(added.sessions.single.startMinute, 540);
    expect(added.sessions.single.location, 'BMES醫環618');

    // Another school's course, one chip away
    await tester.tap(find.widgetWithText(ChoiceChip, '台大'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text(zh.searchSchoolCourses('台大')), findsOneWidget);
    expect(find.text('微積分甲'), findsOneWidget);
  });

  testWidgets('with no catalog reachable, add goes straight to adding by hand', (tester) async {
    await open(tester, schools: const []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text(zh.searchCourseHint), findsNothing);
    expect(find.widgetWithText(TextField, zh.courseTitle), findsOneWidget);
  });

  testWidgets('an added result neither clashes with itself nor stays: it can be removed', (tester) async {
    final c = await open(tester, catalog: const [
      CatalogCourse(
        id: 'ntu_115-1_1', school: 'ntu', semester: '115-1', title: '微積分甲',
        sessions: [CourseSession(weekday: 1, startMinute: 620, endMinute: 730)],
      ),
    ]);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '微積分');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('微積分甲'));
    await tester.pumpAndSettle();

    expect(find.text(zh.clashesWith('微積分甲')), findsNothing, reason: 'not with its own meetings');
    expect(find.text(zh.catalogAdded), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, zh.catalogRemove));
    await tester.pumpAndSettle();
    expect(c.read(coursesProvider), isEmpty);
    expect(c.read(trashProvider).single.course!.title, '微積分甲');
    expect(find.text(zh.catalogAdded), findsNothing);
    expect(find.byTooltip(zh.addCourse), findsOneWidget, reason: 'the result can be added again');
  });

  testWidgets('swipes run through each term\'s week then its grades', (tester) async {
    final c = await open(tester);
    final settings = c.read(semesterSettingsProvider);
    final terms = generateSemesters(settings).where((t) => RegExp(r'^\d+-\d+$').hasMatch(t)).toList();
    final now = semesterNow(c);
    final next = terms[terms.indexOf(now) + 1];
    final previous = terms[terms.indexOf(now) - 1];

    void expectShowing(String semester, {required bool grades, String? reason}) {
      expect(find.text(formatSemester(semester, settings, zh)), findsOneWidget, reason: reason);
      expect(find.byType(GradesView), grades ? findsOneWidget : findsNothing, reason: reason);
    }

    Future<void> swipe(double dx) async {
      await tester.fling(find.byType(SwipeSwitcher), Offset(dx, 0), 800);
      await tester.pumpAndSettle();
    }

    expectShowing(now, grades: false);
    await swipe(-300);
    expectShowing(now, grades: true, reason: 'left: this term\'s grades');
    await swipe(-300);
    expectShowing(next, grades: false, reason: 'left again: next term\'s week');
    await swipe(300);
    expectShowing(now, grades: true, reason: 'right: back to this term\'s grades');
    await swipe(300);
    expectShowing(now, grades: false);
    await swipe(300);
    expectShowing(previous, grades: true, reason: 'right from a week: last term\'s grades');
  });

  Future<void> openFromAPage(WidgetTester tester) async {
    await pumpScreen(tester, Builder(builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetableScreen())),
          child: const Text('open'),
        ),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsOneWidget);
  }

  testWidgets('pulled down far enough the page closes; a short pull settles back', (tester) async {
    await openFromAPage(tester);

    await tester.drag(find.byType(TimetableGrid), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsOneWidget, reason: 'too short: it settles back');

    await tester.drag(find.byType(TimetableGrid), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsNothing);
  });

  testWidgets('the grades page closes the same way, and so does the header', (tester) async {
    await openFromAPage(tester);
    await tester.tap(find.text(zh.grades));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GradesView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SegmentedButton<bool>), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsNothing);
  });

  testWidgets('more credits than the database takes are stopped in the sheet', (tester) async {
    final c = await open(tester, schools: const []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, zh.courseTitle), '專題研究');
    await tester.enterText(find.widgetWithText(TextField, zh.courseCredits), '31');
    await tester.tap(find.widgetWithText(FilledButton, zh.addCourse));
    await tester.pumpAndSettle();

    expect(find.text(zh.courseCreditsTooMany(InputLimits.courseCredits)), findsOneWidget);
    expect(c.read(coursesProvider), isEmpty);
  });

  // Credits by category (§3-T): off unless switched on
  group('credits by category', () {
    const csie114 = DegreeRequirement(department: '資訊工程學系', required: 51, general: 24, elective: 53, total: 128);
    final ntuWithDepts = CatalogSchool(
        code: 'ntu', name: kNtuSchool, shortName: '台大', semesters: [_thisSemester], audiences: const ['資工系', '電機系']);
    const calculus = CatalogCourse(
      id: 'ntu_1', school: 'ntu', semester: '115-1', title: '微積分甲', credits: 4, requiredFor: ['資工系'],
    );
    const poetry = CatalogCourse(id: 'ntu_2', school: 'ntu', semester: '115-1', title: '讀新詩', credits: 2, kind: 'general');

    Future<ProviderContainer> openAsCsie(WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_profile',
          jsonEncode({'school': kNtuSchool, 'department': '資訊工程學系', 'grade': 2, 'grade_set_year': 2026}));
      final c = await open(tester,
          grades: true,
          schools: [ntuWithDepts],
          catalog: const [calculus, poetry],
          requirements: const {'ntu 114': [csie114]});
      await c.read(profileProvider.notifier).loadGuest();
      await c.read(catalogSchoolsProvider.future);
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('the switch in Settings and on the grades page is one setting', (tester) async {
      final c = testContainer();
      await pumpScreen(tester, const SettingsScreen(), container: c);
      await tester.tap(find.widgetWithText(SwitchListTile, zh.creditCategories));
      await tester.pumpAndSettle();
      expect(c.read(gradeSettingsProvider).categoriesEnabled, isTrue);

      // Switched off elsewhere, the one in Settings follows
      await c.read(gradeSettingsProvider.notifier).set(c.read(gradeSettingsProvider).copyWith(categoriesEnabled: false));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, zh.creditCategories)).value, isFalse);
    });

    testWidgets('off: no categories anywhere, and adding files nothing', (tester) async {
      final c = await openAsCsie(tester);
      expect(find.text(zh.creditCategories), findsOneWidget);
      expect(find.text(zh.creditsEarned), findsOneWidget, reason: 'the single credits card as before');
      expect(find.text(zh.categoryRequired), findsNothing);

      c.read(coursesProvider.notifier).add(semester: semesterNow(c), title: '手動');
      await tester.pumpAndSettle();
      expect(c.read(coursesProvider).single.category, isNull);
    });

    testWidgets('on: the school\'s numbers for the entry year and department, guessed from the profile',
        (tester) async {
      final c = await openAsCsie(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final settings = c.read(gradeSettingsProvider);
      expect(settings.categoriesEnabled, isTrue);
      expect(settings.entryYear, 114);
      expect(settings.requirementDepartment, '資訊工程學系');
      expect(settings.catalogDepartment, '資工系');
      expect(find.text(zh.creditsOf('0', 51)), findsOneWidget);
      expect(find.text(zh.creditsOf('0', 24)), findsOneWidget);
      expect(find.text(zh.creditsOf('0', 53)), findsOneWidget);
      expect(find.text(zh.creditsOf('0', 128)), findsOneWidget);
      expect(find.text(zh.requirementsFrom(114, '資訊工程學系')), findsOneWidget);
      expect(find.text(zh.creditsEarned), findsNothing);
    });

    testWidgets('on: a course added from the catalog is filed, and the sheet can refile it', (tester) async {
      final c = await openAsCsie(tester);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zh.timetable).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '微積分');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('微積分甲'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '新詩');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('讀新詩'));
      await tester.pumpAndSettle();

      final byTitle = {for (final x in c.read(coursesProvider)) x.title: x};
      expect(byTitle['微積分甲']!.category, 'required', reason: 'compulsory for 資工系');
      expect(byTitle['讀新詩']!.category, 'general');
    });

    testWidgets('courses from before are filed in one tap, by their catalog rows', (tester) async {
      final c = await openAsCsie(tester);
      final sem = semesterNow(c);
      c.read(coursesProvider.notifier)
        ..add(semester: sem, title: '微積分甲', catalogId: 'ntu_1', credits: 4)
        ..add(semester: sem, title: '手動的課', credits: 2);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text(zh.unfiledCourses(2)), findsOneWidget);

      await tester.tap(find.text(zh.fileAutomatically));
      await tester.pumpAndSettle();
      final byTitle = {for (final x in c.read(coursesProvider)) x.title: x};
      expect(byTitle['微積分甲']!.category, 'required');
      expect(byTitle['手動的課']!.category, 'elective');
      expect(find.text(zh.unfiledCourses(2)), findsNothing);
    });

    testWidgets('a department the school publishes nothing for takes the user\'s own numbers', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_profile', jsonEncode({'school': kNthuSchool, 'department': '資訊工程學系'}));
      final c = await open(tester, grades: true);
      await c.read(profileProvider.notifier).loadGuest();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text(zh.requirementsManual), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, zh.categoryRequired), '60');
      await tester.enterText(find.widgetWithText(TextField, zh.categoryGeneral), '28');
      await tester.enterText(find.widgetWithText(TextField, zh.categoryElective), '40');
      await tester.tap(find.widgetWithText(TextButton, zh.save));
      await tester.pumpAndSettle();
      expect(c.read(gradeSettingsProvider).requiredCredits, 60);
      expect(find.text(zh.creditsOf('0', 60)), findsOneWidget);
    });
  });

  testWidgets('a deleted course goes to the trash and comes back with its meetings', (tester) async {
    final c = await open(tester);
    final course = c.read(coursesProvider.notifier).add(
          semester: semesterNow(c),
          title: '經濟學原理',
          sessions: const [CourseSession(weekday: 2, startMinute: 560, endMinute: 660, location: '社科101')],
        );
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(TimetableGrid), matching: find.text('經濟學原理')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(zh.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.delete).last);
    await tester.pumpAndSettle();

    expect(c.read(coursesProvider), isEmpty);
    final trashed = c.read(trashProvider).single;
    expect(trashed.course!.sessions.single.location, '社科101');

    c.read(coursesProvider.notifier).restore(c.read(trashProvider.notifier).pop(trashed.id)!.course!);
    expect(c.read(coursesProvider).single.id, course.id);
    expect(c.read(coursesProvider).single.sessions.single.location, '社科101');
  });

  testWidgets('setting the first day of classes shows the week', (tester) async {
    final c = await open(tester);
    await tester.tap(find.text(zh.setFirstDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.save));
    await tester.pumpAndSettle();

    final term = c.read(termsProvider)[semesterNow(c)];
    expect(term, isNotNull);
    expect(term!.weeks, TermInfo.defaultWeeks);
    expect(find.text(zh.setFirstDay), findsNothing);
  });

  testWidgets('the grades view adds up the GPA and the credits', (tester) async {
    final c = testContainer();
    final notifier = c.read(coursesProvider.notifier);
    final sem = termAt(c.read(effectiveNowProvider), c.read(semesterSettingsProvider));
    final a = notifier.add(semester: sem, title: '甲', credits: 3);
    final b = notifier.add(semester: sem, title: '乙', credits: 2);
    notifier.update(a.copyWith(grade: () => 'A'));
    notifier.update(b.copyWith(grade: () => 'B'));
    await pumpScreen(tester, const TimetableScreen(grades: true), container: c, width: 420);

    // (4.0·3 + 3.0·2) / 5 = 3.60 → 82.75 on NTU's table
    expect(find.text('3.60'), findsNWidgets(2));
    expect(find.text(zh.percentEquivalent('82.75')), findsOneWidget);
    expect(find.text(zh.creditsOf('5', 128)), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '3.80').first, '4.3');
    await tester.pumpAndSettle();
    expect(find.text(zh.targetNoCourses), findsOneWidget);
  });

  testWidgets('today\'s classes show on the task page, and only today\'s', (tester) async {
    final c = await pumpApp(tester);
    final now = c.read(effectiveNowProvider);
    final sem = termAt(now, c.read(semesterSettingsProvider));
    final tomorrow = now.weekday % 7 + 1;
    c.read(coursesProvider.notifier).add(
          semester: sem,
          title: '今天的課',
          sessions: [CourseSession(weekday: now.weekday, startMinute: 0, endMinute: 1439, location: '博雅101')],
        );
    c.read(coursesProvider.notifier).add(
          semester: sem,
          title: '明天的課',
          sessions: [CourseSession(weekday: tomorrow, startMinute: 600, endMinute: 700)],
        );
    await tester.pumpAndSettle();

    expect(find.byType(TodayClassesStrip), findsOneWidget);
    expect(find.text('今天的課・博雅101'), findsOneWidget);
    expect(find.textContaining('明天的課'), findsNothing);
    expect(find.text(zh.classNow), findsOneWidget, reason: 'it runs all day, so it is on now');
  });

  testWidgets('outside the teaching weeks the strip stays out of the way', (tester) async {
    final c = await pumpApp(tester);
    final now = c.read(effectiveNowProvider);
    final sem = termAt(now, c.read(semesterSettingsProvider));
    c.read(coursesProvider.notifier).add(
          semester: sem,
          title: '今天的課',
          sessions: [CourseSession(weekday: now.weekday, startMinute: 0, endMinute: 1439)],
        );
    // Term starts next month
    await c.read(termsProvider.notifier).set(sem, TermInfo(now.add(const Duration(days: 40))));
    await tester.pumpAndSettle();

    expect(find.textContaining('今天的課'), findsNothing);
  });

  // The ways in: beside the progress card on a phone, under it on desktop, and
  // below the divider of the side menu at every width
  Future<void> opens(WidgetTester tester, Finder entry) async {
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(TimetableScreen))).pop();
    await tester.pumpAndSettle();
  }

  Finder onTaskPage(String text) =>
      find.descendant(of: find.byType(TodayScreen), matching: find.text(text));

  // The task page shows today's classes only; the way into the timetable is the
  // side menu (2026-10-03). On a phone the progress is a ring in the header
  testWidgets('a phone: a progress ring in the header, the timetable only in the drawer', (tester) async {
    await pumpApp(tester, width: 360);
    expect(onTaskPage(zh.timetable), findsNothing);
    final ring = tester.getRect(find.byTooltip(zh.taskHistory));
    final header = tester.getRect(find.byType(PageHeader).first);
    expect(header.contains(ring.center), isTrue, reason: 'in the header, not over the tasks');
    expect(find.text(zh.tasksCompleted(0, 0)), findsNothing, reason: 'no progress card on a phone');
    expect(tester.takeException(), isNull);

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    await opens(tester, find.descendant(of: find.byType(Drawer), matching: find.text(zh.timetable)));
  });

  testWidgets('the ring opens the history', (tester) async {
    await pumpApp(tester, width: 360);
    await tester.tap(find.byTooltip(zh.taskHistory));
    await tester.pumpAndSettle();
    expect(find.byType(TaskHistoryScreen), findsOneWidget);
  });

  testWidgets('desktop keeps the progress card; the timetable is in the rail', (tester) async {
    await pumpApp(tester, width: 1280);
    expect(onTaskPage(zh.timetable), findsNothing);
    expect(find.text(zh.tasksCompleted(0, 0)), findsOneWidget);
    await opens(tester, find.descendant(of: find.byType(NavigationRail), matching: find.text(zh.timetable)));

    // The narrow rail has no labels: an icon with a tooltip
    setViewWidth(tester, 900);
    await tester.pumpAndSettle();
    await opens(tester, find.descendant(of: find.byType(NavigationRail), matching: find.byTooltip(zh.timetable)));
  });

  // The timetable entry lines up with the destinations above it: its icon on
  // their icon column, its label where theirs start (reported 2026-10-04)
  for (final width in [900.0, 1280.0]) {
    testWidgets('at $width the rail\'s timetable entry lines up with the tabs', (tester) async {
      await pumpApp(tester, width: width);
      final rail = find.byType(NavigationRail);
      Rect icon(IconData data) => tester.getRect(find.descendant(of: rail, matching: find.byIcon(data)));
      final tasks = icon(Icons.today);
      final timetable = icon(Icons.calendar_view_week_outlined);
      expect(timetable.center.dx, moreOrLessEquals(tasks.center.dx, epsilon: 0.5));
      if (width >= 1200) {
        final tasksLabel = tester.getRect(find.descendant(of: rail, matching: find.text(zh.tasks)));
        final timetableLabel = tester.getRect(find.descendant(of: rail, matching: find.text(zh.timetable)));
        expect(timetableLabel.left, moreOrLessEquals(tasksLabel.left, epsilon: 0.5));
      }
    });
  }

  testWidgets('in the drawer the timetable entry lines up with the tabs', (tester) async {
    await pumpApp(tester, width: 360);
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    final drawer = find.byType(Drawer);
    Rect at(Finder f) => tester.getRect(find.descendant(of: drawer, matching: f));
    expect(at(find.byIcon(Icons.calendar_view_week_outlined)).center.dx,
        moreOrLessEquals(at(find.byIcon(Icons.today)).center.dx, epsilon: 0.5));
    expect(at(find.text(zh.timetable)).left, moreOrLessEquals(at(find.text(zh.tasks)).left, epsilon: 0.5));
  });

  // A row per period and a closed right edge: without the last day's right
  // border the week looked cut off at the side (reported 2026-09-27)
  for (final width in [360.0, 412.0, 1280.0]) {
    testWidgets('at $width the week rows are periods and the last day is closed off', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('guest_profile', jsonEncode({'school': kNtuSchool}));
      final c = testContainer();
      await c.read(profileProvider.notifier).loadGuest();
      c.read(coursesProvider.notifier).add(
            semester: termAt(c.read(effectiveNowProvider), c.read(semesterSettingsProvider)),
            title: '星期五的課',
            sessions: const [CourseSession(weekday: 5, startMinute: 620, endMinute: 730)],
          );
      await pumpScreen(tester, const TimetableScreen(), container: c, width: width);

      final grid = tester.getRect(find.byType(TimetableGrid));
      final friday = tester.getRect(find.text('星期五的課'));
      expect(friday.right, lessThanOrEqualTo(grid.right));
      expect(grid.right, lessThanOrEqualTo(width));
      final closed = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          ((w.decoration as BoxDecoration).border as Border?)?.right != BorderSide.none &&
          (w.decoration as BoxDecoration).border != null);
      expect(closed, findsOneWidget);
      // Periods, not hours: NTU's period 3 starts at 10:20
      expect(find.text('3\n10:20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the week shows its credits, and exports as a PNG', (tester) async {
    final c = await open(tester);
    c.read(coursesProvider.notifier)
      ..add(semester: semesterNow(c), title: '微積分', credits: 4,
          sessions: const [CourseSession(weekday: 1, startMinute: 620, endMinute: 730)])
      ..add(semester: semesterNow(c), title: '服務學習', credits: 0.5);
    await tester.pumpAndSettle();
    expect(find.text(zh.semesterCredits('4.5')), findsOneWidget);

    // Capturing itself is tested on its own (save_image_test.dart): here only
    // that the button captures the week and hands it on under its name
    Uint8List? saved;
    String? name;
    final realSave = savePng;
    final realCapture = capturePng;
    // At the moment of capture the week sits inside a margin and a frame,
    // not against the picture's edge
    double? inset;
    capturePng = (key) async {
      final picture = tester.getRect(find.byKey(key));
      final grid = tester.getRect(find.byType(TimetableGrid));
      inset = [grid.left - picture.left, picture.right - grid.right, picture.bottom - grid.bottom]
          .reduce((a, b) => a < b ? a : b);
      return Uint8List.fromList([1, 2, 3]);
    };
    savePng = (png, fileName) async {
      saved = png;
      name = fileName;
    };
    addTearDown(() {
      savePng = realSave;
      capturePng = realCapture;
    });
    await tester.tap(find.byTooltip(zh.exportTimetable));
    await tester.pumpAndSettle();
    expect(saved, [1, 2, 3]);
    expect(name, 'URniversity-${semesterNow(c)}.png');
    expect(inset, greaterThanOrEqualTo(AppSpacing.lg + AppSpacing.md));
  });

  testWidgets('a course\'s own task: due at its next class, listed in the course', (tester) async {
    final c = await open(tester);
    final course = c.read(coursesProvider.notifier).add(
          semester: semesterNow(c),
          title: '線性代數',
          sessions: const [CourseSession(weekday: 3, startMinute: 620, endMinute: 730)],
        );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(TimetableGrid), matching: find.text('線性代數')));
    await tester.pumpAndSettle();
    expect(find.text(zh.courseTasks), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, zh.addTask));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, zh.titleField), '習題 3.1');
    await tester.tap(find.widgetWithText(FilledButton, zh.add));
    await tester.pumpAndSettle();

    final task = c.read(tasksProvider).single;
    expect(task.courseId, course.id);
    expect(task.dueTime, nextMeetingStart(course, task.createdAt));
    // Back on the course: it lists the new task as the task page draws it,
    // above the meeting times (2026-10-04)
    final row = find.ancestor(of: find.text('習題 3.1'), matching: find.byType(TaskTile));
    expect(row, findsOneWidget);
    expect(tester.getRect(row).bottom, lessThan(tester.getRect(find.text(zh.courseMeetings)).top));
    // Ticked from here, it is done
    await tester.tap(find.descendant(of: row, matching: find.byType(TaskCheckbox)));
    await tester.pumpAndSettle();
    expect(c.read(tasksProvider).single.isCompleted, isTrue);
  });

  testWidgets('a task row names its course', (tester) async {
    final c = await pumpApp(tester);
    c.read(taskViewProvider.notifier).state = 0;
    final course = c.read(coursesProvider.notifier).add(semester: semesterNow(c), title: '普通化學');
    c.read(tasksProvider.notifier).add('實驗報告', linkedCourseId: course.id);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(TodayScreen), matching: find.text('普通化學')), findsOneWidget);
  });

  testWidgets('the school\'s first day of classes is the default; the user\'s own wins', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_profile', jsonEncode({'school': kNtuSchool}));
    final now = DateTime.now();
    final sem = termAt(now, SemesterSettings.defaultSettings);
    final schoolDay = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 14));
    final withTerms = CatalogSchool(
      code: 'ntu', name: kNtuSchool, shortName: '台大', semesters: [sem],
      termStarts: {sem: TermInfo(schoolDay), '100-1': TermInfo(DateTime(2011, 9, 12))},
    );
    final other = CatalogSchool(code: 'nthu', name: kNthuSchool, shortName: '清大',
        termStarts: {'99-1': TermInfo(DateTime(2010, 9, 13))});
    final c = await open(tester, schools: [withTerms, other]);
    await c.read(profileProvider.notifier).loadGuest();
    await c.read(catalogSchoolsProvider.future);
    await tester.pumpAndSettle();

    expect(c.read(effectiveTermsProvider)[sem]!.firstDay, schoolDay);
    expect(c.read(effectiveTermsProvider).containsKey('99-1'), isFalse, reason: 'not the user\'s school');
    // Two weeks in: the third week, marked as the school's
    expect(find.text(zh.termFromSchool(zh.timetableWeek(3))), findsOneWidget);

    await c.read(termsProvider.notifier).set(sem, TermInfo(schoolDay.add(const Duration(days: 7))));
    await tester.pumpAndSettle();
    expect(c.read(effectiveTermsProvider)[sem]!.firstDay, schoolDay.add(const Duration(days: 7)));
    expect(find.text(zh.timetableWeek(2)), findsOneWidget);
  });

  testWidgets('the week fits a phone without overflowing', (tester) async {
    final c = testContainer();
    c.read(coursesProvider.notifier).add(
          semester: termAt(c.read(effectiveNowProvider), c.read(semesterSettingsProvider)),
          title: '一門名字非常非常長的課程會不會把格子撐破',
          sessions: const [
            CourseSession(weekday: 6, startMinute: 430, endMinute: 480, location: '很長的教室名稱'),
            CourseSession(weekday: 5, startMinute: 1270, endMinute: 1320),
          ],
        );
    await pumpScreen(tester, const TimetableScreen(), container: c, width: 360);
    expect(tester.takeException(), isNull);
  });
}
