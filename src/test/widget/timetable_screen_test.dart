import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/core/period_tables.dart';
import 'package:urniversity/core/review_stats.dart' show termAt;
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/course.dart';
import 'package:urniversity/providers/course_catalog_provider.dart';
import 'package:urniversity/providers/courses_provider.dart';
import 'package:urniversity/providers/profile_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/trash_provider.dart';
import 'package:urniversity/screens/timetable_screen.dart';
import 'package:urniversity/screens/today_screen.dart' show TodayScreen;
import 'package:urniversity/widgets/timetable_grid.dart';
import 'package:urniversity/widgets/today_classes_strip.dart';

import '../helpers/pump_app.dart';

// This semester, the way the screen works it out on a guest's default settings
final _thisSemester = termAt(DateTime.now(), SemesterSettings.defaultSettings);

class _FakeCatalog implements CatalogSource {
  final List<CatalogCourse> rows;
  final List<CatalogSchool> schoolList;
  _FakeCatalog(this.rows, this.schoolList);

  @override
  Future<List<CatalogSchool>> schools() async => schoolList;

  @override
  Future<List<CatalogCourse>> search(String school, String semester, String query) async => rows
      .where((r) => r.school == school && (r.title.contains(query) || (r.teacher ?? '').contains(query)))
      .toList();
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
      {List<CatalogCourse> catalog = const [], List<CatalogSchool>? schools, bool grades = false}) {
    final c = testContainer(overrides: [
      catalogSourceProvider.overrideWithValue(_FakeCatalog(catalog, schools ?? [ntu, nthu])),
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

  testWidgets('each school with a catalog this semester has its own search, the user\'s first', (tester) async {
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
    final mine = tester.getRect(find.text(zh.searchSchoolCourses('清大')));
    final other = tester.getRect(find.text(zh.searchSchoolCourses('台大')));
    expect(mine.top, lessThan(other.top));
    expect(find.text(zh.searchSchoolCourses('政大')), findsNothing, reason: 'no catalog this semester');

    // Only that school's courses, with the times as the catalog read them
    await tester.tap(find.text(zh.searchSchoolCourses('清大')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '微積分');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('微積分甲'), findsNothing);
    await tester.tap(find.text('微積分一'));
    await tester.pumpAndSettle();
    final added = c.read(coursesProvider).single;
    expect(added.sessions.single.startMinute, 540);
    expect(added.sessions.single.location, 'BMES醫環618');
  });

  testWidgets('with no catalog reachable, adding by hand is still there', (tester) async {
    await open(tester, schools: const []);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.text(zh.addManually), findsOneWidget);
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

  testWidgets('a phone has the timetable beside the progress card and in the drawer', (tester) async {
    await pumpApp(tester, width: 360);
    final ring = tester.getRect(find.byTooltip(zh.taskHistory));
    final card = tester.getRect(onTaskPage(zh.timetable));
    expect(card.left, greaterThan(ring.right));
    expect(card.center.dy, closeTo(ring.center.dy, 24));
    expect(tester.takeException(), isNull);
    await opens(tester, onTaskPage(zh.timetable));

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    await opens(tester, find.descendant(of: find.byType(Drawer), matching: find.text(zh.timetable)));
  });

  testWidgets('desktop has it under the progress card and in the rail', (tester) async {
    await pumpApp(tester, width: 1280);
    final ring = tester.getRect(find.byTooltip(zh.taskHistory));
    final card = tester.getRect(onTaskPage(zh.timetable));
    expect(card.top, greaterThan(ring.bottom));
    await opens(tester, onTaskPage(zh.timetable));
    await opens(tester, find.descendant(of: find.byType(NavigationRail), matching: find.text(zh.timetable)));

    // The narrow rail has no labels: an icon with a tooltip
    setViewWidth(tester, 900);
    await tester.pumpAndSettle();
    await opens(tester, find.descendant(of: find.byType(NavigationRail), matching: find.byTooltip(zh.timetable)));
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
