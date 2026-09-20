import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/screens/future_screen.dart';

import '../helpers/pump_app.dart';

// The visions page's two filter rows, per the 2026-09-16 canvas: categories
// first, semesters under them, and the semester row's "all" says what it means
// rather than borrowing the category row's label.
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  testWidgets('categories sit above the semesters', (tester) async {
    final c = testContainer();
    c.read(futureGoalsProvider.notifier).addGoal(
          title: '出國交換一學期',
          categories: const [FutureCategories.exchange],
          startSemester: '115-1',
        );

    await pumpScreen(tester, const Scaffold(body: FutureScreen()), container: c);
    await tester.pumpAndSettle();

    final categories = tester.getRect(find.text(zh.catAll));
    final semesters = tester.getRect(find.text(zh.anySemester));
    expect(categories.top, lessThan(semesters.top));
  });

  testWidgets('picking a category filters the list', (tester) async {
    final c = testContainer();
    final visions = c.read(futureGoalsProvider.notifier);
    visions.addGoal(title: '出國交換', categories: const [FutureCategories.exchange]);
    visions.addGoal(title: '找實習', categories: const [FutureCategories.intern]);

    await pumpScreen(tester, const Scaffold(body: FutureScreen()), container: c);
    await tester.pumpAndSettle();
    expect(find.text('找實習'), findsOneWidget);

    await tester.tap(find.text(zh.catExchange));
    await tester.pumpAndSettle();

    expect(find.text('出國交換'), findsOneWidget);
    expect(find.text('找實習'), findsNothing);
  });
}
