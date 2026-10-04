import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/screens/category_settings_screen.dart';
import 'package:urniversity/screens/inspirations_screen.dart';
import 'package:urniversity/screens/journal_edit_screen.dart';
import 'package:urniversity/screens/journals_screen.dart';
import 'package:urniversity/screens/notification_settings_screen.dart';
import 'package:urniversity/screens/overview_graph_screen.dart';
import 'package:urniversity/screens/reviews_screen.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/screens/sync_log_screen.dart';
import 'package:urniversity/screens/task_history_screen.dart';
import 'package:urniversity/screens/timetable_screen.dart';
import 'package:urniversity/screens/trash_screen.dart';
import 'package:urniversity/widgets/app_page.dart';

import '../helpers/pump_app.dart';

// The page template (system_design.md §3-Q, 2026-10-04): every page opened on
// top of another pulls down or swipes right to close, follows the finger with
// the page beneath showing through, and stays when the finger comes back
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  // A page under the one being tested, with a line of text to look for
  Future<void> openOver(WidgetTester tester, Widget page, {bool appRoute = true}) async {
    await pumpScreen(
      tester,
      Builder(builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              appRoute
                  ? AppPageRoute<void>(builder: (_) => page)
                  : PageRouteBuilder<void>(pageBuilder: (_, _, _) => page),
            ),
            child: const Text('the page below'),
          ),
        ),
      )),
      container: testContainer(),
    );
    await tester.tap(find.text('the page below'));
    await tester.pumpAndSettle();
  }

  Finder below() => find.text('the page below');

  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  testWidgets('pulled down, the page below shows through, then it closes', (tester) async {
    await openOver(tester, const SettingsScreen());
    expect(below(), findsNothing, reason: 'covered, so not even built on stage');

    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppBar)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    expect(below(), findsOneWidget, reason: 'the finger drives the route: the page below is revealed');
    expect(tester.getTopLeft(find.byType(AppBar)).dy, greaterThan(200), reason: 'the page follows the finger');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('a pull that comes back up stays, even past the threshold', (tester) async {
    await openOver(tester, const SettingsScreen());
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppBar)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    // Still past the threshold, but the last movement was up; holding still
    // first leaves no flick to read either way
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(below(), findsNothing, reason: 'settled back: covered again');
    expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
  });

  testWidgets('a short pull settles back', (tester) async {
    await openOver(tester, const SettingsScreen());
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppBar)));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('swiped right from anywhere, it goes back', (tester) async {
    await openOver(tester, const SettingsScreen());
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SettingsScreen)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
    }
    expect(below(), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('a swipe left does nothing', (tester) async {
    await openOver(tester, const SettingsScreen());
    await tester.drag(find.byType(SettingsScreen), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('with nothing below, there is no gesture', (tester) async {
    await pumpScreen(tester, const SettingsScreen(), container: testContainer());
    // Not even moving under the finger: it would only spring back
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppBar)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    expect(tester.getTopLeft(find.byType(AppBar)), Offset.zero);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(AppBar), const Offset(0, 400));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SettingsScreen), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AppBar)), Offset.zero);
  });

  testWidgets('under another route the page moves itself, and still closes', (tester) async {
    await openOver(tester, const SettingsScreen(), appRoute: false);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(AppBar)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
    }
    expect(tester.getTopLeft(find.byType(AppBar)).dy, greaterThan(200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('reduce motion: it closes at once', (tester) async {
    reduceMotion(tester);
    await openOver(tester, const SettingsScreen());
    await tester.drag(find.byType(AppBar), const Offset(0, 400));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('a sideways drag in a text field edits it, not the page', (tester) async {
    await openOver(tester, const JournalEditScreen());
    await tester.drag(find.byType(TextField).first, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(JournalEditScreen), findsOneWidget);
  });

  testWidgets('pages with views side by side swipe between them, not back', (tester) async {
    await openOver(tester, const TaskHistoryScreen());
    SegmentedButton<int> range() => tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>));
    await tester.fling(find.byType(SegmentedButton<int>), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(range().selected, {1});
    await tester.fling(find.byType(SegmentedButton<int>), const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    expect(range().selected, {0});
    expect(find.byType(TaskHistoryScreen), findsOneWidget, reason: 'a swipe right on the first view stays');

    await tester.drag(find.text(zh.historyDaily), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(TaskHistoryScreen), findsNothing);
  });

  // Every page opened on top of another closes both ways
  final pages = <String, Widget>{
    'settings': const SettingsScreen(),
    'notification settings': const NotificationSettingsScreen(),
    'categories': const CategorySettingsScreen(),
    'trash': const TrashScreen(),
    'inspirations': const InspirationsScreen(),
    'journals': const JournalsScreen(),
    'reviews': const ReviewsScreen(),
    'sync log': const SyncLogScreen(),
    // Its particles never settle unless motion is reduced
    'overview graph': const OverviewGraphScreen(),
  };
  pages.forEach((name, page) {
    testWidgets('$name: swipes right and pulls down to close', (tester) async {
      if (page is OverviewGraphScreen) reduceMotion(tester);
      await openOver(tester, page);
      await tester.drag(find.byType(AppBar).first, const Offset(300, 0));
      await tester.pumpAndSettle();
      expect(find.byWidget(page), findsNothing, reason: 'swiped right');

      await tester.tap(below());
      await tester.pumpAndSettle();
      await tester.drag(find.byType(AppBar).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.byWidget(page), findsNothing, reason: 'pulled down');
    });
  });

  testWidgets('the timetable pulls down to close; sideways it changes page', (tester) async {
    await openOver(tester, const TimetableScreen());
    await tester.drag(find.byType(AppBar), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsOneWidget, reason: 'no swipe back here');
    await tester.drag(find.byType(AppBar), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(TimetableScreen), findsNothing);
  });
}
