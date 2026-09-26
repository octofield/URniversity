import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/home_tab_provider.dart';
import 'package:urniversity/providers/onboarding_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/semester_screen.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/widgets/coach_mark.dart';
import 'package:urniversity/widgets/sheet_fields.dart';

import '../helpers/pump_app.dart';

// The hands-on tour, driven the way a new user drives it: through the real
// app, the real + button and the real sheets. The assertions that carry the
// weight are the ones about the hole — that it sits on the thing the card
// talks about, that taps inside it reach the app and taps outside do not — and
// that the tour only moves past a sheet once something was actually saved.
void main() {
  const zh = StringsZhTw();

  Rect? hole(WidgetTester tester) {
    final paint = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is SpotlightPainter,
    );
    if (paint.evaluate().isEmpty) return null;
    return (tester.widget<CustomPaint>(paint).painter as SpotlightPainter).hole;
  }

  bool holeOn(WidgetTester tester, Finder target) =>
      hole(tester)?.contains(tester.getCenter(target)) ?? false;

  Finder sheetField(String label) => find.descendant(
        of: find.widgetWithText(SheetTextField, label),
        matching: find.byType(TextField),
      );

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  // "Got it" on the card — the only FilledButton with that text on screen
  Future<void> gotIt(WidgetTester tester) =>
      tapAndSettle(tester, find.widgetWithText(FilledButton, zh.tourGotIt));

  group('first run', () {
    setUp(() => setUpTestSupabase(seenTour: false));

    testWidgets('the tasks chapter opens with the add button lit', (tester) async {
      await pumpApp(tester);

      expect(find.text(zh.tourTaskAddTitle), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(holeOn(tester, find.byTooltip(zh.addTask)), isTrue);
    });

    testWidgets('a tap outside the hole does not reach the app', (tester) async {
      await pumpApp(tester);

      // The targets tab is right there in the nav bar, but it is not the hole
      await tester.tap(find.byIcon(Icons.school_outlined), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(SemesterScreen), findsNothing);
      expect(find.text(zh.tourTaskAddTitle), findsOneWidget);
    });

    testWidgets('the user adds their first task through the real sheet', (tester) async {
      final scope = await pumpApp(tester);

      await tapAndSettle(tester, find.byTooltip(zh.addTask));
      // The hole followed the user into the sheet
      expect(find.text(zh.tourTaskTitleBody), findsOneWidget);
      expect(holeOn(tester, sheetField(zh.titleField)), isTrue);
      await tester.enterText(sheetField(zh.titleField), '交微積分作業');

      await gotIt(tester);
      expect(find.text(zh.tourTaskDueBody), findsOneWidget);
      expect(holeOn(tester, find.text(zh.dueTime)), isTrue);
      await gotIt(tester);
      expect(find.text(zh.tourTaskRepeatBody), findsOneWidget);
      await gotIt(tester);
      expect(find.text(zh.tourTaskLinkBody), findsOneWidget);
      expect(holeOn(tester, find.text(zh.linkedTarget)), isTrue);
      await gotIt(tester);
      expect(find.text(zh.tourTaskSubmitBody), findsOneWidget);

      await tapAndSettle(tester, find.widgetWithText(FilledButton, zh.add));

      expect(scope.read(tasksProvider).single.title, '交微積分作業');
      expect(find.text(zh.tourSaved), findsOneWidget);
      expect(find.text(zh.tourSummaryTitle), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
    });

    testWidgets('closing the sheet without saving goes back to the button', (tester) async {
      final scope = await pumpApp(tester);

      await tapAndSettle(tester, find.byTooltip(zh.addTask));
      // A swipe down or the back key: the sheet goes, nothing was added
      Navigator.of(tester.element(sheetField(zh.titleField))).pop();
      await tester.pumpAndSettle();

      expect(scope.read(tasksProvider), isEmpty);
      expect(find.text(zh.tourRetry), findsOneWidget);
      expect(find.text(zh.tourTaskAddTitle), findsOneWidget);
      expect(holeOn(tester, find.byTooltip(zh.addTask)), isTrue);
    });

    testWidgets('a picker a field opens is usable, and the card comes back', (tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, find.byTooltip(zh.addTask));
      await gotIt(tester);
      await tapAndSettle(tester, find.text(zh.dueTime));

      // The date picker is on top: the tour steps out of its way
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text(zh.tourTaskDueBody), findsNothing);
      expect(hole(tester), isNull);

      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
      await tester.pumpAndSettle();

      expect(find.text(zh.tourTaskDueBody), findsOneWidget);
    });

    testWidgets('skipping the save step closes the sheet and adds nothing', (tester) async {
      final scope = await pumpApp(tester);

      await tapAndSettle(tester, find.byTooltip(zh.addTask));
      for (var i = 0; i < 4; i++) {
        await gotIt(tester);
      }
      expect(find.text(zh.tourTaskSubmitBody), findsOneWidget);
      await tapAndSettle(tester, find.text(zh.tourSkipStep));

      expect(find.byType(SheetTextField), findsNothing);
      expect(scope.read(tasksProvider), isEmpty);
      expect(find.text(zh.tourSummaryTitle), findsOneWidget);
      expect(find.text(zh.tourSaved), findsNothing);
    });

    testWidgets('Back moves between fields but never back out of the sheet', (tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, find.byTooltip(zh.addTask));
      // First field: behind it is "tap +", which already happened
      expect(find.text(zh.tourBack), findsNothing);

      await gotIt(tester);
      expect(find.text(zh.tourBack), findsOneWidget);
      await tapAndSettle(tester, find.text(zh.tourBack));
      expect(find.text(zh.tourTaskTitleBody), findsOneWidget);
    });

    testWidgets('the progress card opens the history, and back returns', (tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, find.text(zh.tourSkipStep));
      expect(find.text(zh.tourSummaryTitle), findsOneWidget);
      // Tapped where the user would: the middle of the lit card
      await tester.tapAt(hole(tester)!.center);
      await tester.pumpAndSettle();
      expect(find.text(zh.tourHistoryBody), findsOneWidget);
      expect(holeOn(tester, find.text(zh.historyDaily)), isTrue);
      await tapAndSettle(tester, find.text(zh.tourGoBack));
      expect(find.text(zh.tourViewBody), findsOneWidget);
    });

    testWidgets('the view switch step moves on when the switch is tapped', (tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, find.text(zh.tourSkipStep));
      await tapAndSettle(tester, find.text(zh.tourSkipStep));
      expect(find.text(zh.tourViewBody), findsOneWidget);
      expect(holeOn(tester, find.text(zh.weeklyTasks)), isTrue);

      await tapAndSettle(tester, find.text(zh.weeklyTasks));

      expect(find.text(zh.tourInspAddTitle), findsOneWidget);
    });

    testWidgets('each tab plays its own chapter once', (tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, find.byTooltip(zh.tourCloseChapter));
      expect(find.text(zh.tourTaskAddTitle), findsNothing);
      expect(
        SharedPreferences.getInstance().then((p) => p.getStringList('onboarding_done')),
        completion(['today']),
      );

      await tapAndSettle(tester, find.byIcon(Icons.school_outlined));
      expect(find.text(zh.tourTemplatesTitle), findsOneWidget);
      expect(holeOn(tester, find.byTooltip(zh.goalTemplates)), isTrue);

      await tapAndSettle(tester, find.byTooltip(zh.tourCloseChapter));
      await tapAndSettle(tester, find.byIcon(Icons.today_outlined));
      // Tasks was already done: going back there starts nothing
      expect(find.byType(CustomPaint).evaluate().where(
        (e) => (e.widget as CustomPaint).painter is SpotlightPainter,
      ), isEmpty);
    });

    testWidgets('with no target made, the milestone part is passed over', (tester) async {
      await pumpApp(tester);
      await tapAndSettle(tester, find.byTooltip(zh.tourCloseChapter));
      await tapAndSettle(tester, find.byIcon(Icons.school_outlined));

      await gotIt(tester);
      expect(find.text(zh.tourTargetAddTitle), findsOneWidget);
      await tapAndSettle(tester, find.text(zh.tourSkipStep));

      expect(find.text(zh.tourMilestoneOpenTitle), findsNothing);
      expect(find.text(zh.tourPickerTitle), findsOneWidget);
    });

    testWidgets('a target made in the tour is split into a milestone', (tester) async {
      final scope = await pumpApp(tester);
      await tapAndSettle(tester, find.byTooltip(zh.tourCloseChapter));
      await tapAndSettle(tester, find.byIcon(Icons.school_outlined));
      await gotIt(tester);

      await tapAndSettle(tester, find.byTooltip(zh.addTarget));
      await tester.enterText(sheetField(zh.titleField), '多益 800');
      // Title, categories, semester — no vision step, since there are none
      for (var i = 0; i < 3; i++) {
        await gotIt(tester);
      }
      expect(find.text(zh.tourTargetVisionBody), findsNothing);
      await tapAndSettle(tester, find.widgetWithText(FilledButton, zh.add));

      expect(find.text(zh.tourMilestoneOpenTitle), findsOneWidget);
      expect(holeOn(tester, find.text('多益 800')), isTrue);
      await tapAndSettle(tester, find.text('多益 800'));

      // On the target's own page now
      expect(find.text(zh.tourMilestoneAddTitle), findsOneWidget);
      expect(holeOn(tester, find.text(zh.addMilestone)), isTrue);
      await tapAndSettle(tester, find.text(zh.addMilestone));
      await tester.enterText(sheetField(zh.titleField), '報名考試');
      await gotIt(tester);
      await tapAndSettle(tester, find.widgetWithText(FilledButton, zh.add));

      final goals = scope.read(semesterGoalsProvider);
      expect(goals.where((g) => g.parentId != null).single.title, '報名考試');
      expect(find.text(zh.tourMilestoneListBody), findsOneWidget);

      await tapAndSettle(tester, find.text(zh.tourGoBack));
      expect(find.text(zh.tourPickerTitle), findsOneWidget);
    });

    testWidgets('the journal button is scrolled into view before it is lit', (tester) async {
      await pumpApp(tester, width: 400);
      await tapAndSettle(tester, find.byTooltip(zh.tourCloseChapter));
      await tapAndSettle(tester, find.byIcon(Icons.person_outlined));

      await gotIt(tester);
      expect(find.text(zh.tourJournalAddTitle), findsOneWidget);
      final lit = hole(tester)!;
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(lit.top, greaterThanOrEqualTo(0));
      expect(lit.bottom, lessThanOrEqualTo(screen.height));
    });

    testWidgets('no chapter starts under another page; it waits for it to close', (tester) async {
      SharedPreferences.setMockInitialValues({
        'is_guest_mode': true,
        'onboarding_done': ['today', 'future', 'me'],
      });
      await preloadOnboarding();
      final scope = await pumpApp(tester);
      expect(hole(tester), isNull);

      await tapAndSettle(tester, find.byIcon(Icons.settings_outlined).first);
      expect(find.byType(SettingsScreen), findsOneWidget);
      // The graph's "see the tasks" path switches tabs while a page is open
      scope.read(pendingTabProvider.notifier).state = 1;
      await tester.pumpAndSettle();
      expect(find.text(zh.tourTemplatesTitle), findsNothing);

      Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.text(zh.tourTemplatesTitle), findsOneWidget);
    });
  });

  group('responsive', () {
    setUp(() => setUpTestSupabase(seenTour: false));

    Rect cardOf(WidgetTester tester, String text) => tester.getRect(
          find.ancestor(of: find.text(text), matching: find.byType(Material)).first,
        );

    for (final size in const [Size(360, 640), Size(400, 800), Size(900, 700), Size(1400, 900)]) {
      testWidgets('at ${size.width.toInt()}×${size.height.toInt()} the card sits on screen, clear of its target',
          (tester) async {
        await pumpApp(tester, width: size.width);
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();

        final card = cardOf(tester, zh.tourTaskAddTitle);
        final lit = hole(tester)!;
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(size.width));
        expect(card.top, greaterThanOrEqualTo(0));
        expect(card.bottom, lessThanOrEqualTo(size.height));
        expect(card.overlaps(lit), isFalse);
      });
    }

    testWidgets('on a wide window the card sits next to the add button', (tester) async {
      await pumpApp(tester, width: 1400);
      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();

      final card = cardOf(tester, zh.tourTaskAddTitle);
      final fab = tester.getRect(find.byTooltip(zh.addTask));
      // Beside it, not pinned to the far left of the screen
      expect(card.right, lessThanOrEqualTo(fab.left));
      expect(fab.left - card.right, lessThan(40));
    });

    testWidgets('on the desktop rail the card sits to the right of the tab it points at', (tester) async {
      await pumpApp(tester, width: 900);
      tester.view.physicalSize = const Size(900, 700);
      await tester.pumpAndSettle();
      // Skip through to "next: targets", which points at the rail
      for (var i = 0; i < 4; i++) {
        await tapAndSettle(tester, find.text(zh.tourSkipStep));
      }
      expect(find.text(zh.tourNextTargetTitle), findsOneWidget);

      final card = cardOf(tester, zh.tourNextTargetTitle);
      expect(card.left, greaterThan(hole(tester)!.right));
    });
  });

  group('guide', () {
    setUp(() => setUpTestSupabase());

    testWidgets('lists every chapter and replays the one picked', (tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, find.byIcon(Icons.settings_outlined).first);
      await tapAndSettle(tester, find.text(zh.tourGuide));

      expect(find.text(zh.tourChapterDone), findsNWidgets(4));
      expect(find.text(zh.tourReplay), findsNWidgets(4));

      // Row order is tab order: the second is the targets chapter
      await tapAndSettle(tester, find.text(zh.tourReplay).at(1));

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(SemesterScreen), findsOneWidget);
      expect(find.text(zh.tourTemplatesTitle), findsOneWidget);
    });
  });
}
