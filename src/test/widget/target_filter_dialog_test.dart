import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/utils/semester_helpers.dart';
import 'package:urniversity/widgets/semester_grouped_picker.dart';

import '../helpers/pump_app.dart';

// Filtering tasks by target used to be one flat list of every target ever set.
// It now groups by semester like the link picker does, and ticking a row keeps
// the dialog open.
void main() {
  const s = StringsZhTw();
  const settings = SemesterSettings.defaultSettings;

  setUp(() => setUpTestSupabase());

  const items = [
    SemesterPickerItem(
      id: 'old',
      title: '大一目標',
      semester: '114-1',
      parentId: null,
      sortOrder: 0,
    ),
    SemesterPickerItem(
      id: 'now',
      title: '本學期目標',
      semester: '115-1',
      parentId: null,
      sortOrder: 0,
    ),
    SemesterPickerItem(
      id: 'milestone',
      title: '里程碑',
      semester: '115-1',
      parentId: 'now',
      sortOrder: 1,
    ),
  ];

  Future<void> pumpDialog(
    WidgetTester tester, {
    Set<String> selected = const {},
    void Function(String id, bool on)? onToggle,
    VoidCallback? onReset,
  }) {
    return pumpScreen(
      tester,
      SemesterGroupedFilterDialog(
        title: s.targets,
        emptyLabel: s.noTargets,
        resetLabel: s.reset,
        items: items,
        selectedIds: selected,
        currentSemester: '115-1',
        settings: settings,
        s: s,
        onToggle: onToggle ?? (_, _) {},
        onReset: onReset ?? () {},
      ),
    );
  }

  testWidgets('every semester has a chip and a heading', (tester) async {
    await pumpDialog(tester);

    final older = formatSemester('114-1', settings, s);
    final current = formatSemester('115-1', settings, s);
    // Once as a chip and once as the group heading
    expect(find.text(older), findsNWidgets(2));
    expect(find.text(current), findsNWidgets(2));
    expect(find.text(s.catAll), findsOneWidget);
    expect(find.text('大一目標'), findsOneWidget);
    expect(find.text('里程碑'), findsOneWidget);
  });

  testWidgets('a semester chip narrows the list to that semester', (tester) async {
    await pumpDialog(tester);

    // The chip row scrolls, so the later semesters can start off-screen
    final chip = find.widgetWithText(ChoiceChip, formatSemester('115-1', settings, s));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('大一目標'), findsNothing);
    expect(find.text('本學期目標'), findsOneWidget);
  });

  testWidgets('rows are checkboxes and ticking one keeps the dialog open', (tester) async {
    final toggled = <String, bool>{};
    await pumpDialog(tester, selected: const {'now'}, onToggle: (id, on) => toggled[id] = on);

    expect(
      tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, '本學期目標')).value,
      isTrue,
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, '里程碑'));
    await tester.pumpAndSettle();

    expect(toggled, {'milestone': true});
    expect(find.byType(SemesterGroupedFilterDialog), findsOneWidget);
  });

  testWidgets('reset is offered', (tester) async {
    var reset = false;
    await pumpDialog(tester, selected: const {'now'}, onReset: () => reset = true);

    await tester.tap(find.widgetWithText(TextButton, s.reset));
    await tester.pump();

    expect(reset, isTrue);
  });
}
