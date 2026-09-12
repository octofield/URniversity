import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/screens/auth/login_screen.dart';
import 'package:urniversity/screens/auth/register_screen.dart';
import 'package:urniversity/screens/auth/reset_password_screen.dart';
import 'package:urniversity/screens/category_settings_screen.dart';
import 'package:urniversity/screens/future_goal_detail_screen.dart';
import 'package:urniversity/screens/future_screen.dart';
import 'package:urniversity/screens/home_screen.dart';
import 'package:urniversity/screens/inspirations_screen.dart';
import 'package:urniversity/screens/journal_edit_screen.dart';
import 'package:urniversity/screens/journals_screen.dart';
import 'package:urniversity/screens/me_screen.dart';
import 'package:urniversity/screens/semester_goal_detail_screen.dart';
import 'package:urniversity/screens/semester_screen.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/screens/setup_profile_screen.dart';
import 'package:urniversity/screens/task_history_screen.dart';
import 'package:urniversity/screens/today_screen.dart';
import 'package:urniversity/screens/trash_screen.dart';
import 'package:urniversity/widgets/responsive_body.dart';

import '../helpers/pump_app.dart';

// ResponsiveBody caps a single-column screen at AppBreakpoints.desktop (768):
// below it the child is returned untouched, at or above it the child is centred
// inside a ConstrainedBox. Retires the manual width-dragging cases 23-38 of
// docs/test-plans/2026-08-23-style-and-responsive.md, which asked for twelve
// screens to be dragged across the boundary by hand.
void main() {
  setUp(() => setUpTestSupabase());

  // The cap is the one ConstrainedBox ResponsiveBody itself builds. Matching on
  // the exact maxWidth also catches a screen passing the wrong constant
  Finder capOf(double maxWidth) => find.descendant(
        of: find.byType(ResponsiveBody),
        matching: find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == maxWidth,
        ),
      );

  Future<void> expectCappedAt(
    WidgetTester tester,
    Widget screen,
    double maxWidth,
  ) async {
    await pumpScreen(tester, screen, width: 767);
    expect(find.byType(ResponsiveBody), findsOneWidget,
        reason: 'screen must use ResponsiveBody');
    expect(capOf(maxWidth), findsNothing, reason: 'no cap below 768');

    setViewWidth(tester, 768);
    await tester.pumpAndSettle();
    expect(capOf(maxWidth), findsOneWidget, reason: 'capped at 768');
  }

  group('form screens cap at 420', () {
    testWidgets('login', (t) => expectCappedAt(t, const LoginScreen(), 420));
    testWidgets('register',
        (t) => expectCappedAt(t, const RegisterScreen(), 420));
    testWidgets('reset password',
        (t) => expectCappedAt(t, const ResetPasswordScreen(), 420));
    testWidgets('setup profile',
        (t) => expectCappedAt(t, const SetupProfileScreen(), 420));
  });

  group('content screens cap at 640', () {
    testWidgets('category settings',
        (t) => expectCappedAt(t, const CategorySettingsScreen(), 640));
    testWidgets('inspirations',
        (t) => expectCappedAt(t, const InspirationsScreen(), 640));
    testWidgets('journals',
        (t) => expectCappedAt(t, const JournalsScreen(), 640));
    testWidgets('journal edit',
        (t) => expectCappedAt(t, const JournalEditScreen(), 640));
    testWidgets('settings',
        (t) => expectCappedAt(t, const SettingsScreen(), 640));
    testWidgets('task history',
        (t) => expectCappedAt(t, const TaskHistoryScreen(), 640));
    testWidgets('trash', (t) => expectCappedAt(t, const TrashScreen(), 640));
  });

  // These two pop themselves when the goal is missing, so the container has to
  // be seeded before the first frame and addGoal mints the id itself
  group('detail screens cap at 640', () {
    testWidgets('semester goal detail', (tester) async {
      final c = testContainer();
      c.read(semesterGoalsProvider.notifier).addGoal('目標', '114-1');
      final id = c.read(semesterGoalsProvider).first.id;

      await pumpScreen(tester, SemesterGoalDetailScreen(goalId: id),
          width: 767, container: c);
      expect(capOf(640), findsNothing);

      setViewWidth(tester, 768);
      await tester.pumpAndSettle();
      expect(capOf(640), findsOneWidget);
    });

    testWidgets('future goal detail', (tester) async {
      final c = testContainer();
      c.read(futureGoalsProvider.notifier).addGoal(title: '願景');
      final id = c.read(futureGoalsProvider).first.id;

      await pumpScreen(tester, FutureGoalDetailScreen(goalId: id),
          width: 767, container: c);
      expect(capOf(640), findsNothing);

      setViewWidth(tester, 768);
      await tester.pumpAndSettle();
      expect(capOf(640), findsOneWidget);
    });
  });

  // The tab pages build their own two-column layout with a different cap, so
  // ResponsiveBody must not appear in them at any width. They are pumped
  // through HomeScreen because none of them owns a Scaffold and they reach for
  // Scaffold.of(context) themselves; HomeScreen's IndexedStack builds all four
  group('tab pages never use ResponsiveBody', () {
    for (final width in [400.0, 768.0, 1280.0]) {
      testWidgets('at ${width.toInt()}px', (tester) async {
        await pumpScreen(tester, const HomeScreen(), width: width);
        // IndexedStack keeps the three unselected tabs offstage, which the
        // default finder skips — so all four assertions would silently pass
        // against a single tab without this
        for (final type in [TodayScreen, SemesterScreen, FutureScreen, MeScreen]) {
          expect(find.byType(type, skipOffstage: false), findsOneWidget,
              reason: '$type must be built');
        }
        expect(find.byType(ResponsiveBody, skipOffstage: false), findsNothing);
      });
    }
  });
}
