import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/theme/app_colors.dart';
import 'package:urniversity/core/theme/app_theme.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/screens/semester_goal_detail_screen.dart';

import '../helpers/pump_app.dart';

// The app-wide transitions (system_design.md §3-Q): which one each kind of
// navigation uses, and that each actually plays
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  // The fade wrapped around the tab pages, not any of the framework's own
  Finder tabFade() => find.byWidgetPredicate((w) =>
      w is FadeTransition && w.child is ScaleTransition && (w.child! as ScaleTransition).child is IndexedStack);

  testWidgets('switching tabs fades the new page in', (tester) async {
    await pumpApp(tester);
    double opacity() => tester.widget<FadeTransition>(tabFade()).opacity.value;
    expect(opacity(), 1);

    await tester.tap(find.text(zh.targets).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(opacity(), lessThan(1), reason: 'mid-fade');

    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  test('each platform family gets its own page transition', () {
    final builders = buildAppTheme(AppColors.palette).pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<PredictiveBackPageTransitionsBuilder>());
    expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
    expect(builders[TargetPlatform.macOS], isA<CupertinoPageTransitionsBuilder>());
    expect(builders[TargetPlatform.windows], isA<FadeForwardsPageTransitionsBuilder>());
    expect(builders[TargetPlatform.linux], isA<FadeForwardsPageTransitionsBuilder>());
  });

  testWidgets('a target card grows into its detail page', (tester) async {
    final c = await pumpApp(tester);
    c.read(semesterGoalsProvider.notifier).addGoal('多益 800', c.read(selectedSemesterProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.targets).last);
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is OpenContainer), findsOneWidget);
    await tester.tap(find.text('多益 800'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-transform the detail page is already being drawn inside the card
    expect(find.byType(SemesterGoalDetailScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(SemesterGoalDetailScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(SemesterGoalDetailScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(SemesterGoalDetailScreen), findsNothing);
    expect(find.text('多益 800'), findsOneWidget, reason: 'back on its card');
  });

  testWidgets('the add button gives under a press, touch included', (tester) async {
    await pumpApp(tester);
    final fab = find.byTooltip(zh.addTask);
    double scaleNow() => tester
        .widget<AnimatedScale>(find.descendant(of: fab, matching: find.byType(AnimatedScale)).first)
        .scale;
    expect(scaleNow(), 1);

    // At once, even though the button can also be dragged and so only
    // recognises a tap after the press timeout
    final gesture = await tester.startGesture(tester.getCenter(fab));
    await tester.pump();
    expect(scaleNow(), lessThan(1));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(scaleNow(), 1);
  });
}
