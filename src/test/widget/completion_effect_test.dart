import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/widgets/completion_effect.dart';

import '../helpers/pump_app.dart';

// The pop used to be a one-way tween, so the box stayed at its enlarged size
// for good — a big square left sitting on the screen. It has to come back.
// Since the motion redesign (system_design.md §3-Q) it gives under the thumb
// first, and the row's own strike-through replaces the old floating tick
void main() {
  setUp(() => setUpTestSupabase());

  testWidgets('the tick box returns to its own size after the pop', (tester) async {
    var ticked = false;
    final c = testContainer();
    await c.read(completionEffectProvider.notifier).set(TaskCompletionEffect.basic);

    await pumpScreen(
      tester,
      Scaffold(
        body: Center(
          child: TaskCheckbox(value: false, onToggle: () => ticked = true),
        ),
      ),
      container: c,
    );

    // Checkbox has a ScaleTransition of its own inside, so scope to ours
    final ourScale = find
        .descendant(of: find.byType(TaskCheckbox), matching: find.byType(ScaleTransition))
        .first;
    double scaleNow() => tester.widget<ScaleTransition>(ourScale).scale.value;

    expect(scaleNow(), 1.0);
    await tester.tap(find.byType(Checkbox));
    // The first frame is where the controller starts; sample the whole pass
    await tester.pump();
    var lowest = 1.0;
    var highest = 1.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      lowest = scaleNow() < lowest ? scaleNow() : lowest;
      highest = scaleNow() > highest ? scaleNow() : highest;
    }
    expect(lowest, lessThan(1.0), reason: 'it gives under the thumb');
    expect(highest, greaterThan(1.0), reason: 'then springs a touch past its size');

    await tester.pumpAndSettle();
    expect(scaleNow(), 1.0, reason: 'and settles back to the original size');
    expect(ticked, isTrue);
  });

  // The confetti is an overlay entry holding one CustomPaint, over the page
  Finder confetti() => find.descendant(
        of: find.byType(Overlay),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_ConfettiPainter',
        ),
      );

  testWidgets('finishing the day bursts confetti over the page, then clears', (tester) async {
    final c = testContainer();
    await c.read(completionEffectProvider.notifier).set(TaskCompletionEffect.celebrate);

    await pumpScreen(
      tester,
      Scaffold(
        body: Center(
          child: TaskCheckbox(value: false, onToggle: () {}, isLastOutstanding: () => true),
        ),
      ),
      container: c,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(confetti(), findsOneWidget);

    await tester.pumpAndSettle();
    expect(confetti(), findsNothing, reason: 'and it cleans up');
  });

  testWidgets('any other tick bursts nothing', (tester) async {
    final c = testContainer();
    await c.read(completionEffectProvider.notifier).set(TaskCompletionEffect.celebrate);

    await pumpScreen(
      tester,
      Scaffold(
        body: Center(
          child: TaskCheckbox(value: false, onToggle: () {}, isLastOutstanding: () => false),
        ),
      ),
      container: c,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(confetti(), findsNothing);
  });

  testWidgets('with the system asking for no motion nothing moves at all', (tester) async {
    final c = testContainer();
    await c.read(completionEffectProvider.notifier).set(TaskCompletionEffect.celebrate);

    await pumpScreen(
      tester,
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: Center(
            child: TaskCheckbox(value: false, onToggle: () {}, isLastOutstanding: () => true),
          ),
        ),
      ),
      container: c,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final ourScale = find
        .descendant(of: find.byType(TaskCheckbox), matching: find.byType(ScaleTransition))
        .first;
    expect(tester.widget<ScaleTransition>(ourScale).scale.value, 1.0);
    expect(confetti(), findsNothing);
  });

  testWidgets('with the effect off the box never scales', (tester) async {
    final c = testContainer();
    await c.read(completionEffectProvider.notifier).set(TaskCompletionEffect.off);

    await pumpScreen(
      tester,
      Scaffold(
        body: Center(child: TaskCheckbox(value: false, onToggle: () {})),
      ),
      container: c,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final ourScale = find
        .descendant(of: find.byType(TaskCheckbox), matching: find.byType(ScaleTransition))
        .first;
    expect(tester.widget<ScaleTransition>(ourScale).scale.value, 1.0);
  });
}
