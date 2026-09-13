import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/notification_constants.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/notification_settings.dart';
import 'package:urniversity/providers/notification_provider.dart';
import 'package:urniversity/screens/notification_settings_screen.dart';
import 'package:urniversity/screens/settings_screen.dart';

import '../helpers/pump_app.dart';

// The screen has one rule that is easy to get wrong and expensive when it is:
// the master switch has to make the three kinds inert, or the UI promises
// reminders the OS will never deliver.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  // flutter test reports android by default, so the unsupported path has to be
  // asked for explicitly. This is what a desktop or web user sees
  testWidgets('an unsupported platform says so and disables the switch',
      (tester) async {
    // Reset inside the body, not in addTearDown: the framework asserts that
    // foundation debug variables are unset before tear-downs run
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await pumpScreen(tester, const NotificationSettingsScreen());

      expect(find.text(zh.notifUnsupportedPlatform), findsOneWidget);
      final master = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, zh.notifEnabled),
      );
      expect(master.onChanged, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('all three kinds are listed', (tester) async {
    await pumpScreen(tester, const NotificationSettingsScreen());
    expect(find.text(zh.notifTaskDue), findsOneWidget);
    expect(find.text(zh.notifDailySummary), findsOneWidget);
    expect(find.text(zh.notifGoalDeadline), findsOneWidget);
  });

  group('the master switch gates the three kinds', () {
    testWidgets('they are inert while it is off', (tester) async {
      await pumpScreen(tester, const NotificationSettingsScreen());

      for (final title in [zh.notifTaskDue, zh.notifDailySummary, zh.notifGoalDeadline]) {
        final tile = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, title),
        );
        expect(tile.onChanged, isNull, reason: '$title must be inert');
      }
    });

    testWidgets('they become usable once it is on', (tester) async {
      final c = testContainer();
      // Set directly rather than through enable(), which would ask the OS
      await c
          .read(notificationSettingsProvider.notifier)
          .update(const NotificationSettings(enabled: true));

      await pumpScreen(tester, const NotificationSettingsScreen(), container: c);

      for (final title in [zh.notifTaskDue, zh.notifDailySummary, zh.notifGoalDeadline]) {
        final tile = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, title),
        );
        expect(tile.onChanged, isNotNull, reason: '$title must be usable');
      }
    });
  });

  testWidgets('the lead time picker writes the choice back', (tester) async {
    final c = testContainer();
    await c
        .read(notificationSettingsProvider.notifier)
        .update(const NotificationSettings(enabled: true));

    await pumpScreen(tester, const NotificationSettingsScreen(), container: c);
    await tester.tap(find.text(zh.notifTaskLead));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(SimpleDialog),
      matching: find.text(zh.notifLeadMinutes(60)),
    ));
    await tester.pumpAndSettle();

    expect(c.read(notificationSettingsProvider).taskLeadMinutes, 60);
    expect(NotificationConstants.taskLeadMinuteOptions, contains(60));
  });

  testWidgets('the settings screen offers a way in', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.text(zh.notifications), findsOneWidget);
  });
}
