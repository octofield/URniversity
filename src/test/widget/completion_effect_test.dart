import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/widgets/completion_effect.dart';

import '../helpers/pump_app.dart';

// The pop used to be a one-way tween, so the box stayed at its enlarged size
// for good — a big square left sitting on the screen. It has to come back.
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
    // The first frame is where the controller starts; the pop shows on the next
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(scaleNow(), greaterThan(1.0), reason: 'the pop plays');

    await tester.pumpAndSettle();
    expect(scaleNow(), 1.0, reason: 'and settles back to the original size');
    expect(ticked, isTrue);
  });

  testWidgets('the tick is drawn over the page, so it outlives the row', (tester) async {
    final c = testContainer();
    await c.read(completionEffectProvider.notifier).set(TaskCompletionEffect.basic);

    await pumpScreen(
      tester,
      Scaffold(
        body: Center(child: TaskCheckbox(value: false, onToggle: () {})),
      ),
      container: c,
    );

    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // An overlay, not part of the row: ticking a task off takes its row out of
    // the list on the next frame
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing, reason: 'and it cleans up');
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
