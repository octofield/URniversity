import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/widgets/completion_effect.dart';

import '../helpers/pump_app.dart';

// Haptics (system_design.md §3-Q, data_dictionary.md D25): each moment buzzes
// at its own weight, and the switch in Settings silences all of them —
// independently of the completion effect
void main() {
  setUp(() => setUpTestSupabase());

  // What HapticFeedback asked the platform for, in order
  List<String> recordBuzzes(WidgetTester tester) {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    return calls;
  }

  Future<void> tapBox(WidgetTester tester, {required bool value, bool last = false, bool haptics = true,
      TaskCompletionEffect effect = TaskCompletionEffect.celebrate}) async {
    final c = testContainer();
    await c.read(hapticsProvider.notifier).set(haptics);
    await c.read(completionEffectProvider.notifier).set(effect);
    await pumpScreen(
      tester,
      Scaffold(
        body: Center(
          child: TaskCheckbox(value: value, onToggle: () {}, isLastOutstanding: () => last),
        ),
      ),
      container: c,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
  }

  testWidgets('ticking a task off is a light tap', (tester) async {
    final buzzes = recordBuzzes(tester);
    await tapBox(tester, value: false);
    expect(buzzes, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('finishing the day is a firmer one', (tester) async {
    final buzzes = recordBuzzes(tester);
    await tapBox(tester, value: false, last: true);
    expect(buzzes, ['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('unticking is only a click', (tester) async {
    final buzzes = recordBuzzes(tester);
    await tapBox(tester, value: true);
    expect(buzzes, ['HapticFeedbackType.selectionClick']);
  });

  testWidgets('switched off, nothing buzzes', (tester) async {
    final buzzes = recordBuzzes(tester);
    await tapBox(tester, value: false, last: true, haptics: false);
    expect(buzzes, isEmpty);
  });

  testWidgets('the completion effect being off does not silence it', (tester) async {
    final buzzes = recordBuzzes(tester);
    await tapBox(tester, value: false, effect: TaskCompletionEffect.off);
    expect(buzzes, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('the switch is remembered on this device', (tester) async {
    final c = testContainer();
    await c.read(hapticsProvider.notifier).set(false);

    final fresh = testContainer();
    // Read once to build it, then let it load what was stored
    expect(fresh.read(hapticsProvider), isTrue);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(fresh.read(hapticsProvider), isFalse);
  });
}
