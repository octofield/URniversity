import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

// Every main page built its own header, and the targets page's drawer button
// ended up sitting higher than the other three. They share PageHeader now, so
// the button has to land in exactly the same place on all four.
void main() {
  setUp(() => setUpTestSupabase());

  testWidgets('the drawer button sits in the same place on all four pages',
      (tester) async {
    await pumpApp(tester);

    final menu = find.widgetWithIcon(IconButton, Icons.menu);
    final rects = <Rect>[];

    for (final tab in [
      Icons.today_outlined,
      Icons.school_outlined,
      Icons.flag_outlined,
      Icons.person_outlined,
    ]) {
      // The selected tab swaps to the filled icon, so the first page is read
      // before switching away from it
      if (rects.isNotEmpty) {
        await tester.tap(find.byIcon(tab));
        await tester.pumpAndSettle();
      }
      expect(menu, findsOneWidget, reason: 'every page has the drawer button');
      rects.add(tester.getRect(menu));
    }

    expect(rects.toSet(), hasLength(1), reason: 'same rect on every page: $rects');
  });
}
