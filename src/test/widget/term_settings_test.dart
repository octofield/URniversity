import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/review_stats.dart' show termAt;
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/courses_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/screens/timetable_screen.dart';
import 'package:urniversity/utils/semester_helpers.dart';
import 'package:urniversity/widgets/term_dialog.dart';

import '../helpers/pump_app.dart';

// First days of classes in Settings (2026-10-04): the same D30 value the
// timetable sets, so a change on either side shows on the other
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  test('Settings lists last, this and next term, and any other set', () {
    const settings = SemesterSettings.defaultSettings;
    final now = DateTime(2026, 10, 4);
    final here = termAt(now, settings);
    final terms = termsForSettings(now, settings, const []);
    expect(terms, hasLength(3));
    expect(terms[1], here);

    // One set long ago is listed too, in order; a break never is
    final older = termsForSettings(now, settings, const ['113-1', '114-B1']);
    expect(older.first, '113-1');
    expect(older, isNot(contains('114-B1')));
  });

  testWidgets('set in Settings, the timetable shows it; set there, Settings shows it', (tester) async {
    final c = testContainer();
    final sem = termAt(c.read(effectiveNowProvider), c.read(semesterSettingsProvider));
    await pumpScreen(tester, const SettingsScreen(), container: c);
    await tester.scrollUntilVisible(find.text(zh.termStartsSetting), 200);
    await tester.tap(find.text(zh.termStartsSetting));
    await tester.pumpAndSettle();

    final row = find.widgetWithText(ListTile, formatSemester(sem, c.read(semesterSettingsProvider), zh));
    expect(find.descendant(of: row, matching: find.text(zh.setFirstDay)), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, zh.teachingWeeks), '18');
    await tester.tap(find.widgetWithText(FilledButton, zh.save));
    await tester.pumpAndSettle();
    expect(c.read(termsProvider)[sem]!.weeks, 18);
    expect(find.descendant(of: row, matching: find.textContaining('18')), findsOneWidget,
        reason: 'the list shows the new value at once');
    await tester.tap(find.widgetWithText(TextButton, MaterialLocalizations.of(tester.element(row)).closeButtonLabel));
    await tester.pumpAndSettle();

    // The timetable reads the same value: no "set the first day" left
    await pumpScreen(tester, const TimetableScreen(), container: c, width: 420);
    expect(find.text(zh.setFirstDay), findsNothing);

    // And the other way: written where the timetable writes it, Settings has it
    await c.read(termsProvider.notifier).set(sem, TermInfo(DateTime(2026, 9, 14), 17));
    await pumpScreen(tester, const SettingsScreen(), container: c);
    await tester.scrollUntilVisible(find.text(zh.termStartsSetting), 200);
    await tester.tap(find.text(zh.termStartsSetting));
    await tester.pumpAndSettle();
    expect(find.descendant(of: row, matching: find.textContaining('17')), findsOneWidget);
  });
}
