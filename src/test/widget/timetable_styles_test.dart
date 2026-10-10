import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/core/review_stats.dart' show termAt;
import 'package:urniversity/core/save_image/save_image.dart';
import 'package:urniversity/core/theme/app_colors.dart';
import 'package:urniversity/core/theme/app_styles.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/course.dart';
import 'package:urniversity/providers/courses_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/timetable_style_provider.dart';
import 'package:urniversity/screens/timetable_screen.dart';
import 'package:urniversity/widgets/timetable_agenda.dart';
import 'package:urniversity/widgets/timetable_grid.dart';

import '../helpers/pump_app.dart';

// Timetable styles (system_design.md §3-S, 2026-10-04): five ways to draw the
// same week, picked in the app bar, remembered, and each one sound at a phone,
// a tablet and a desktop width, in a light style and in Midnight
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());
  tearDown(() => AppColors.use(kStylePalettes[AppStyle.linen]!));

  String sem(ProviderContainer container) => termAt(container.read(effectiveNowProvider), container.read(semesterSettingsProvider));

  // A week with a long title, a short class and a light course colour
  void seed(ProviderContainer container) {
    final courses = container.read(coursesProvider.notifier);
    courses.add(
      semester: sem(container),
      title: '微積分',
      credits: 4,
      color: 0xFF4A90C4,
      sessions: const [
        CourseSession(weekday: 1, startMinute: 550, endMinute: 670, location: '普101'),
        CourseSession(weekday: 4, startMinute: 550, endMinute: 670, location: '普101'),
      ],
    );
    courses.add(
      semester: sem(container),
      title: '一門名字非常非常長、長到一格放不下的通識課程',
      credits: 2,
      color: 0xFFF2D04B,
      sessions: const [CourseSession(weekday: 3, startMinute: 800, endMinute: 850, location: '博雅101')],
    );
  }

  for (final style in TimetableStyle.values) {
    for (final palette in [AppStyle.linen, AppStyle.midnight]) {
      for (final width in [360.0, 768.0, 1280.0]) {
        testWidgets('${style.name} in ${palette.name} at $width draws without overflow', (tester) async {
          AppColors.use(kStylePalettes[palette]!);
          final c = testContainer();
          await c.read(timetableStyleProvider.notifier).set(style);
          seed(c);
          await pumpScreen(tester, const TimetableScreen(), container: c, width: width);
          expect(tester.takeException(), isNull);
          if (style == TimetableStyle.agenda || style == TimetableStyle.weekList) {
            expect(find.byType(TimetableAgenda), findsOneWidget);
            expect(find.byType(TimetableGrid), findsNothing);
            if (style == TimetableStyle.weekList) {
              // Every day with classes at once: Monday's and Thursday's calculus
              expect(find.text('微積分'), findsNWidgets(2));
            }
          } else {
            expect(find.descendant(of: find.byType(TimetableGrid), matching: find.text('微積分')), findsNWidgets(2));
          }
        });
      }
    }
  }

  testWidgets('picked from the app bar, the style is drawn and remembered', (tester) async {
    final c = testContainer();
    seed(c);
    await pumpScreen(tester, const TimetableScreen(), container: c, width: 420);
    await tester.tap(find.byTooltip(zh.timetableStyle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.timetableStyleAgenda).last);
    await tester.pumpAndSettle();

    expect(c.read(timetableStyleProvider), TimetableStyle.agenda);
    expect(find.byType(TimetableAgenda), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('timetable_style'), 'agenda');
  });

  testWidgets('the agenda exports the whole week, not the day on screen', (tester) async {
    final c = testContainer();
    await c.read(timetableStyleProvider.notifier).set(TimetableStyle.agenda);
    seed(c);
    await pumpScreen(tester, const TimetableScreen(), container: c, width: 420);
    bool? wholeWeek;
    final realCapture = capturePng;
    final realSave = savePng;
    capturePng = (key) async {
      wholeWeek = tester.widget<TimetableAgenda>(find.byType(TimetableAgenda)).allDays;
      return Uint8List(0);
    };
    savePng = (_, _) async {};
    addTearDown(() {
      capturePng = realCapture;
      savePng = realSave;
    });
    await tester.tap(find.byTooltip(zh.exportTimetable));
    await tester.pumpAndSettle();
    expect(wholeWeek, isTrue);
    expect(tester.widget<TimetableAgenda>(find.byType(TimetableAgenda)).allDays, isFalse, reason: 'back to one day');
  });

  // A course on the last day used to cover the table's right rule, which was
  // drawn under the blocks (reported 2026-10-10)
  testWidgets('paper: the outer rule is drawn over the blocks, right edge included', (tester) async {
    final c = testContainer();
    await c.read(timetableStyleProvider.notifier).set(TimetableStyle.paper);
    c.read(coursesProvider.notifier).add(
          semester: sem(c),
          title: '文字探勘初論',
          sessions: const [CourseSession(weekday: 5, startMinute: 620, endMinute: 730)],
        );
    await pumpScreen(tester, const TimetableScreen(), container: c, width: 420);
    final stack = find.descendant(of: find.byType(TimetableGrid), matching: find.byType(Stack)).first;
    final children = tester.widget<Stack>(stack).children;
    final frameAt = children.indexWhere((w) =>
        w is Positioned &&
        w.child is IgnorePointer &&
        (((w.child as IgnorePointer).child as DecoratedBox?)?.decoration as BoxDecoration?)?.border is Border &&
        ((((w.child as IgnorePointer).child as DecoratedBox).decoration as BoxDecoration).border as Border).right !=
            BorderSide.none);
    final blockAt = children.lastIndexWhere((w) =>
        w is Positioned && find.descendant(of: find.byWidget(w), matching: find.text('文字探勘初論')).evaluate().isNotEmpty);
    expect(frameAt, isNonNegative, reason: 'there is an outer frame with a right rule');
    expect(frameAt, greaterThan(blockAt), reason: 'painted after, so over, the course');
  });

  test('a stored name this build does not know is the standard style', () {
    expect(timetableStyleFromName('neon'), TimetableStyle.standard);
    expect(timetableStyleFromName(null), TimetableStyle.standard);
    expect(timetableStyleFromName('paper'), TimetableStyle.paper);
  });

  group('agenda', () {
    final calc = Course(
      id: 'c',
      semester: '115-1',
      title: '微積分',
      color: 0xFF4A90C4,
      createdAt: DateTime(2026),
      sessions: const [
        CourseSession(weekday: 4, startMinute: 600, endMinute: 720, location: '普101'),
        CourseSession(weekday: 1, startMinute: 600, endMinute: 720),
      ],
    );
    final music = Course(
      id: 'm',
      semester: '115-1',
      title: '音樂與人生',
      color: 0xFF3FA5A0,
      createdAt: DateTime(2026),
      sessions: const [CourseSession(weekday: 4, startMinute: 930, endMinute: 1040)],
    );
    // A Thursday, during calculus
    final thursday = DateTime(2026, 10, 8, 10, 30);

    // An exported picture has no now; the week list on screen does
    Future<void> pumpAgenda(WidgetTester tester, {bool allDays = false, bool withNow = false}) => pumpScreen(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: TimetableAgenda(
                courses: [calc, music],
                s: zh,
                now: allDays && !withNow ? null : thursday,
                allDays: allDays,
                onTapCourse: (_) {},
              ),
            ),
          ),
          container: testContainer(),
          width: 390,
        );

    testWidgets('opens on today, the class under way marked; another day switches the list', (tester) async {
      await pumpAgenda(tester);
      expect(find.text('${zh.weekdayFull(4)} · ${zh.agendaClassCount(2)}'), findsOneWidget);
      expect(find.text(zh.classNow), findsOneWidget);
      expect(tester.getTopLeft(find.text('微積分')).dy, lessThan(tester.getTopLeft(find.text('音樂與人生')).dy),
          reason: 'in the order of the day');

      await tester.tap(find.text(zh.weekdayShort(1)));
      await tester.pumpAndSettle();
      expect(find.text('${zh.weekdayFull(1)} · ${zh.agendaClassCount(1)}'), findsOneWidget);
      expect(find.text(zh.classNow), findsNothing, reason: 'not today');
      expect(find.text('音樂與人生'), findsNothing);

      await tester.tap(find.text(zh.weekdayShort(2)));
      await tester.pumpAndSettle();
      expect(find.textContaining(zh.agendaNoClasses), findsOneWidget);
    });

    testWidgets('the week list marks today\'s class under way among the whole week', (tester) async {
      await pumpAgenda(tester, allDays: true, withNow: true);
      expect(find.text('${zh.weekdayFull(1)} · ${zh.agendaClassCount(1)}'), findsOneWidget);
      expect(find.text(zh.classNow), findsOneWidget);
    });

    testWidgets('exported, it lists every day with classes', (tester) async {
      await pumpAgenda(tester, allDays: true);
      expect(find.text('${zh.weekdayFull(1)} · ${zh.agendaClassCount(1)}'), findsOneWidget);
      expect(find.text('${zh.weekdayFull(4)} · ${zh.agendaClassCount(2)}'), findsOneWidget);
      expect(find.textContaining(zh.weekdayFull(2)), findsNothing, reason: 'no classes, not listed');
      expect(find.text(zh.classNow), findsNothing, reason: 'a picture has no now');
    });
  });

  testWidgets('solid blocks pick their text against the course colour', (tester) async {
    final c = testContainer();
    await c.read(timetableStyleProvider.notifier).set(TimetableStyle.solid);
    seed(c);
    await pumpScreen(tester, const TimetableScreen(), container: c, width: 1280);
    Color textColor(String title) => tester.widget<Text>(find.text(title).first).style!.color!;
    expect(textColor('微積分'), Colors.white, reason: 'a dark blue');
    expect(textColor('一門名字非常非常長、長到一格放不下的通識課程'), Colors.black87, reason: 'a light yellow');
  });
}
