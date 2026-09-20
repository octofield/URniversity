import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/screens/semester_screen.dart';
import 'package:urniversity/utils/category_helpers.dart';
import 'package:urniversity/widgets/link_color_bar.dart';

import '../helpers/pump_app.dart';

// A target with no category used to be dressed in a neutral tint and a
// placeholder tag icon, which read as "some category you cannot place". It now
// shows nothing of its own — unless it is linked to a vision, whose colour it
// then wears.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  // The icon box is the only thing carrying the "mark done" tooltip
  final iconBox = find.byTooltip(zh.markDone);

  Future<void> pumpTargets(WidgetTester tester, ProviderContainer c) async {
    await pumpScreen(tester, const Scaffold(body: SemesterScreen()),
        container: c, width: 420);
    await tester.pumpAndSettle();
  }

  Color? barColour(WidgetTester tester) =>
      tester.widget<LinkColorBar>(find.byType(LinkColorBar).first).top;

  testWidgets('no category and no vision means no colour and no icon',
      (tester) async {
    final c = testContainer();
    final sem = currentSemester(c.read(semesterSettingsProvider));
    c.read(semesterGoalsProvider.notifier).addGoal('還沒分類的目標', sem);

    await pumpTargets(tester, c);

    expect(find.text('還沒分類的目標'), findsOneWidget);
    expect(barColour(tester), isNull, reason: 'the bar reserves width, not colour');
    // The box is still there to tap, but it draws nothing inside
    expect(iconBox, findsOneWidget);
    expect(
      find.descendant(of: iconBox, matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets('a title-only card centres the title against the icon box',
      (tester) async {
    final c = testContainer();
    final sem = currentSemester(c.read(semesterSettingsProvider));
    c.read(semesterGoalsProvider.notifier).addGoal('只有標題', sem);

    await pumpTargets(tester, c);

    final box = tester.getRect(iconBox);
    final title = tester.getRect(find.text('只有標題'));
    expect((box.center.dy - title.center.dy).abs(), lessThan(2),
        reason: 'nothing under the title, so the two share a centre line');
  });

  testWidgets('a categorized target keeps its own colour and icon',
      (tester) async {
    final c = testContainer();
    final sem = currentSemester(c.read(semesterSettingsProvider));
    c.read(semesterGoalsProvider.notifier).addGoal(
          '多益 850',
          sem,
          categories: const [FutureCategories.certification],
        );

    await pumpTargets(tester, c);

    expect(barColour(tester), defaultCatColor(FutureCategories.certification));
    expect(
      find.descendant(of: iconBox, matching: find.byType(Icon)),
      findsOneWidget,
    );
  });

  testWidgets('with no category of its own it wears the vision colour',
      (tester) async {
    final c = testContainer();
    c.read(futureGoalsProvider.notifier).addGoal(
          title: '練好爵士鼓',
          categories: const [FutureCategories.performance],
        );
    final visionId = c.read(futureGoalsProvider).single.id;
    final sem = currentSemester(c.read(semesterSettingsProvider));
    final goals = c.read(semesterGoalsProvider.notifier);
    final id = goals.addGoal('課呢', sem);
    goals.linkFutureGoal(id, visionId);

    await pumpTargets(tester, c);

    expect(barColour(tester), defaultCatColor(FutureCategories.performance));
  });
}
