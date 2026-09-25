import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/goal_templates.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/onboarding_provider.dart';
import 'package:urniversity/screens/home_screen.dart';
import 'package:urniversity/widgets/coach_mark.dart';

import '../helpers/pump_app.dart';

// The spotlight engine itself, below the level of any one chapter: what the
// hole lets through, where it lands on each layout, and that it never
// outlives the screen it was explaining.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase(seenTour: false));

  Rect? hole(WidgetTester tester) {
    final paint = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is SpotlightPainter,
    );
    if (paint.evaluate().isEmpty) return null;
    return (tester.widget<CustomPaint>(paint).painter as SpotlightPainter).hole;
  }

  // Where the hole is and whether the target actually shows through it are two
  // different things: the first version put the hole in the right place yet
  // left the target as dim as the rest on a real device. This rasterises the
  // painter and reads the pixels
  testWidgets('the target shows through the scrim undimmed', (tester) async {
    const hole = Rect.fromLTWH(50, 50, 100, 60);
    final alpha = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      const SpotlightPainter(hole, pulse: 0.5).paint(Canvas(recorder), const Size(200, 200));
      final image = await recorder.endRecording().toImage(200, 200);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return (int x, int y) => bytes.getUint8((y * 200 + x) * 4 + 3);
    });

    // Nothing painted over the middle of the target
    expect(alpha!(100, 80), 0);
    // The scrim everywhere well outside it
    expect(alpha(5, 5), greaterThan(140));
    expect(alpha(195, 195), greaterThan(140));
  });

  testWidgets('an info step blocks even the thing it points at', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip(zh.tourCloseChapter));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.school_outlined));
    await tester.pumpAndSettle();
    expect(find.text(zh.tourTemplatesTitle), findsOneWidget);

    // ✨ is lit, but this step only points it out
    await tester.tap(find.byTooltip(zh.goalTemplates), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text(kGoalTemplates.first.name(zh)), findsNothing);
    expect(find.text(zh.tourTemplatesTitle), findsOneWidget);
  });

  testWidgets('the hole lands on the add button on the desktop rail too', (tester) async {
    await pumpApp(tester, width: 900);

    expect(find.byType(NavigationRail), findsOneWidget);
    final lit = hole(tester);
    expect(lit, isNotNull);
    expect(lit!.contains(tester.getCenter(find.byTooltip(zh.addTask))), isTrue);
  });

  testWidgets('rotating mid-step moves the hole with its target', (tester) async {
    await pumpApp(tester);
    final before = hole(tester)!;

    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpAndSettle();

    expect(hole(tester), isNot(before));
    expect(hole(tester)!.contains(tester.getCenter(find.byTooltip(zh.addTask))), isTrue);
  });

  testWidgets('the tour comes down with the screen that started it', (tester) async {
    // Stands in for _AuthGate swapping HomeScreen out mid-chapter. Flipped
    // directly: a tap anywhere outside the hole is blocked by design
    final showHome = ValueNotifier(true);
    addTearDown(showHome.dispose);
    final scope = await pumpScreen(tester, _Host(showHome: showHome));
    expect(find.text(zh.tourTaskAddTitle), findsOneWidget);

    showHome.value = false;
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsNothing);
    expect(hole(tester), isNull);
    expect(find.text(zh.tourTaskAddTitle), findsNothing);
    // Nobody saw it through, so it is still due next time
    expect(scope.read(onboardingProvider), isNot(contains('today')));
  });

  testWidgets('closing a chapter counts it as seen', (tester) async {
    final scope = await pumpApp(tester);

    await tester.tap(find.byTooltip(zh.tourCloseChapter));
    await tester.pumpAndSettle();

    expect(hole(tester), isNull);
    expect(scope.read(onboardingProvider), contains('today'));
  });

  testWidgets('a device that has seen every chapter gets none', (tester) async {
    await setUpTestSupabase();
    await pumpApp(tester);

    expect(hole(tester), isNull);
    expect(find.text(zh.tourTaskAddTitle), findsNothing);
  });
}

// Shows HomeScreen until the notifier is flipped, then drops it — the closest
// a widget test gets to _AuthGate deciding the user is no longer signed in
class _Host extends StatelessWidget {
  final ValueListenable<bool> showHome;

  const _Host({required this.showHome});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: showHome,
      builder: (context, show, child) =>
          show ? const HomeScreen() : const Scaffold(body: Center(child: Text('gone'))),
    );
  }
}
