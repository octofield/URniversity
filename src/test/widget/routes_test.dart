import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:urniversity/main.dart' show App;
import 'package:urniversity/core/app_routes.dart';
import 'package:urniversity/screens/home_screen.dart';
import 'package:urniversity/screens/splash_screen.dart';
import 'package:urniversity/providers/auth_status_provider.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/guest_provider.dart';
import 'package:urniversity/providers/home_tab_provider.dart';
import 'package:urniversity/screens/auth/login_screen.dart';
import 'package:urniversity/screens/future_screen.dart';
import 'package:urniversity/screens/semester_screen.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/screens/timetable_screen.dart';
import 'package:urniversity/screens/today_screen.dart';
import 'package:urniversity/widgets/grades_view.dart';

import '../helpers/pump_app.dart';

// Every page an address (CLAUDE.md §13, system_design.md §1): the tabs set the
// address and follow it, the main pages have their own, and a signed-out
// visitor keeps the address they came with
void main() {
  const zh = StringsZhTw();

  GoRouter routerOf(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));
  String location(WidgetTester tester) => routerOf(tester).state.uri.path;

  Future<void> go(WidgetTester tester, String path) async {
    routerOf(tester).go(path);
    await tester.pumpAndSettle();
  }

  group('signed in (as a guest)', () {
    setUp(() => setUpTestSupabase());

    testWidgets('the app opens on /tasks, and / goes there too', (tester) async {
      await pumpApp(tester);
      expect(location(tester), AppRoutes.tasks);
      expect(find.byType(TodayScreen), findsOneWidget);
      await go(tester, '/');
      expect(location(tester), AppRoutes.tasks);
    });

    testWidgets('each tab has its address, and the address picks the tab', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.targets);

      // Back in a browser, or a link: the address changes and the tab follows
      await go(tester, AppRoutes.visions);
      expect(find.byType(FutureScreen).hitTestable(), findsOneWidget);
      await go(tester, AppRoutes.targets);
      expect(find.byType(SemesterScreen).hitTestable(), findsOneWidget);
    });

    testWidgets('the main pages open at their own addresses', (tester) async {
      await pumpApp(tester);
      await go(tester, AppRoutes.timetable);
      expect(find.byType(TimetableScreen), findsOneWidget);
      // Nothing under it to go back to: a way home instead
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.tasks);

      await go(tester, AppRoutes.grades);
      expect(find.byType(GradesView), findsOneWidget);
      await go(tester, AppRoutes.settings);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('a page opened from a tab gets its address and Back returns', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.settings);
      expect(find.byIcon(Icons.home_outlined), findsNothing, reason: 'there is a page to go back to');

      await tester.tap(find.byType(BackButton)); // pageBack() looks for the English tooltip
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.tasks);
    });

    testWidgets('a tab picked under an open page reaches the address once it closes', (tester) async {
      final scope = await pumpApp(tester);
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();
      scope.read(pendingTabProvider.notifier).state = 1;
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget, reason: 'the page stays open');

      await tester.tap(find.byType(BackButton)); // pageBack() looks for the English tooltip
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.targets);
      expect(find.byType(SemesterScreen).hitTestable(), findsOneWidget);
    });

    testWidgets('the browser tab is titled after the page', (tester) async {
      await pumpApp(tester);
      String title() => tester.widgetList<Title>(find.byType(Title)).last.title;
      expect(title(), '${zh.tasks} · URniversity');
      await go(tester, AppRoutes.targets);
      expect(title(), '${zh.targets} · URniversity');
      await go(tester, AppRoutes.timetable);
      expect(title(), '${zh.timetable} · URniversity');
      await go(tester, AppRoutes.settings);
      expect(title(), '${zh.settings} · URniversity');
    });

    testWidgets('while a stored session is still settling, the wait screen, not the tasks', (tester) async {
      // Pumped by hand: the wait screen animates forever, so nothing settles
      setViewWidth(tester, 400);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: testContainer(overrides: [authStatusProvider.overrideWithValue(AuthStatus.unknown)]),
        child: const App(),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('an unknown address lands on the tasks', (tester) async {
      await pumpApp(tester);
      await go(tester, '/login-callback');
      expect(location(tester), AppRoutes.tasks);
    });
  });

  group('signed out', () {
    setUp(() => setUpTestSupabase(guest: false));

    testWidgets('the login page has its own address, carrying where it was headed', (tester) async {
      await pumpApp(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(location(tester), AppRoutes.login);

      await go(tester, AppRoutes.timetable);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(TimetableScreen), findsNothing);
      expect(location(tester), AppRoutes.login);
      expect(routerOf(tester).state.uri.queryParameters['from'], AppRoutes.timetable);
      expect(find.text(zh.timetable), findsNothing);
    });

    testWidgets('signing in (here: as a guest) goes on to where it was headed', (tester) async {
      final scope = await pumpApp(tester);
      await go(tester, AppRoutes.timetable);
      await scope.read(guestModeProvider.notifier).enable();
      await tester.pumpAndSettle();
      expect(location(tester), AppRoutes.timetable);
      expect(find.byType(TimetableScreen), findsOneWidget);
    });
  });
}
