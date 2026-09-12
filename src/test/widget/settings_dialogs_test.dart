import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_en.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/providers/trash_provider.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/screens/trash_screen.dart';

import '../helpers/pump_app.dart';

// These four helpers took an untyped `dynamic s` before the refactor, so a
// renamed getter would only have shown up when the dialog was opened. Retires
// cases 19 and 21 of docs/test-plans/2026-08-23-style-and-responsive.md;
// case 20 (the account profile dialog) stays manual.
void main() {
  const zh = StringsZhTw();
  const en = StringsEn();

  setUp(() => setUpTestSupabase());

  Future<void> openSetting(WidgetTester tester, String tile) async {
    await tester.tap(find.text(tile));
    await tester.pumpAndSettle();
  }

  testWidgets('language dialog switches the whole screen', (tester) async {
    final c = await pumpScreen(tester, const SettingsScreen());
    await openSetting(tester, zh.language);
    await tester.tap(find.text(zh.langEn));
    await tester.pumpAndSettle();

    expect(c.read(languageProvider), AppLanguage.en);
    expect(find.text(en.dateFormat), findsOneWidget);
  });

  testWidgets('date format dialog applies the choice', (tester) async {
    final c = await pumpScreen(tester, const SettingsScreen());
    await openSetting(tester, zh.dateFormat);
    await tester.tap(find.text(zh.fmtYyyymmdd));
    await tester.pumpAndSettle();

    expect(c.read(settingsProvider), DateDisplayFormat.yyyymmdd);
  });

  testWidgets('default task view dialog applies the choice', (tester) async {
    final c = await pumpScreen(tester, const SettingsScreen());
    await openSetting(tester, zh.defaultTaskView);
    // The tile itself already shows the current label, so scope to the dialog
    await tester.tap(find.descendant(
      of: find.byType(SimpleDialog),
      matching: find.text(zh.weeklyTasks),
    ));
    await tester.pumpAndSettle();

    expect(c.read(defaultTaskViewProvider), 2);
  });

  testWidgets('semester settings dialog applies the choice', (tester) async {
    final c = await pumpScreen(tester, const SettingsScreen());
    await openSetting(tester, zh.semesterSettings);
    expect(find.text(zh.semesterCount), findsOneWidget);

    await tester.tap(find.text(zh.threeSemesters));
    await tester.pumpAndSettle();
    await tester.tap(find.text(zh.save));
    await tester.pumpAndSettle();

    expect(c.read(semesterSettingsProvider).count, 3);
  });

  group('trash', () {
    testWidgets('offers no empty button when it is empty', (tester) async {
      await pumpScreen(tester, const TrashScreen());
      expect(find.text(zh.noTrash), findsOneWidget);
      expect(find.text(zh.emptyTrash), findsNothing);
    });

    testWidgets('confirms before emptying', (tester) async {
      final c = testContainer();
      c.read(tasksProvider.notifier).add('要丟掉的');
      c.read(trashProvider.notifier).addTask(c.read(tasksProvider).single);

      await pumpScreen(tester, const TrashScreen(), container: c);
      await tester.tap(find.text(zh.emptyTrash));
      await tester.pumpAndSettle();
      expect(find.text(zh.emptyTrashConfirm), findsOneWidget);

      await tester.tap(find.text(MaterialLocalizations.of(
              tester.element(find.byType(AlertDialog)))
          .cancelButtonLabel));
      await tester.pumpAndSettle();
      expect(c.read(trashProvider), hasLength(1));
    });
  });
}
