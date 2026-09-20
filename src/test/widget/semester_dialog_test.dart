import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/widgets/semester_list_dialog.dart';

import '../helpers/pump_app.dart';

// The semester list runs from the first year to the last, so opening at the
// top meant scrolling past years already finished. It opens on the current
// semester now — earlier ones are still a scroll up.
void main() {
  const zh = StringsZhTw();
  const settings = SemesterSettings.defaultSettings;
  // Long enough that the current semester can actually reach the top; with a
  // short list the best the view can do is scroll to its end
  const semesters = [
    '112-1', '112-2', '113-1', '113-2', '114-1', '114-2',
    '115-1', '115-2', '116-1', '116-2', '117-1', '117-2', '118-1', '118-2',
  ];

  setUp(() => setUpTestSupabase());

  Future<void> pumpDialog(
    WidgetTester tester, {
    String openAt = '115-1',
    String? anyLabel,
  }) =>
      pumpScreen(
        tester,
        SemesterListDialog(
          title: zh.semester,
          semesters: semesters,
          selected: openAt,
          openAt: openAt,
          settings: settings,
          s: zh,
          anyLabel: anyLabel,
          onSelect: (_) {},
        ),
      );

  testWidgets('it opens on the current semester', (tester) async {
    await pumpDialog(tester);

    final list = tester.getRect(find.byType(ListView));
    // The row, not the label: the text sits centred inside its 48px row
    final current = tester.getRect(
      find.ancestor(of: find.text('115-1'), matching: find.byType(ListTile)),
    );
    expect((current.top - list.top).abs(), lessThan(2),
        reason: 'the current semester is the first row in view');
  });

  testWidgets('earlier semesters are one scroll up', (tester) async {
    await pumpDialog(tester);
    expect(find.text('112-1'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('112-1'), findsOneWidget);
  });

  testWidgets('the filter version keeps "any semester" above the list',
      (tester) async {
    await pumpDialog(tester, anyLabel: zh.anySemester);

    // Still opening on the current one, with the extra row accounted for
    final list = tester.getRect(find.byType(ListView));
    final current = tester.getRect(
      find.ancestor(of: find.text('115-1'), matching: find.byType(ListTile)),
    );
    expect((current.top - list.top).abs(), lessThan(2));

    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(find.text(zh.anySemester), findsOneWidget);
  });
}
