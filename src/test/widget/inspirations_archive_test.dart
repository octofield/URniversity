import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/inspiration.dart';
import 'package:urniversity/providers/inspirations_provider.dart';
import 'package:urniversity/screens/inspirations_screen.dart';

import '../helpers/pump_app.dart';

// Archiving is a second axis, independent of is_completed: an idea that was
// never acted on can still be filed away. These cases pin that down, plus the
// part that makes archiving worth anything — the row leaving the active list
void main() {
  const zh = StringsZhTw();

  setUp(() => setUpTestSupabase());

  Inspiration seed(String id, {bool completed = false, bool archived = false}) =>
      Inspiration(
        id: id,
        title: id,
        isCompleted: completed,
        isArchived: archived,
        createdAt: DateTime(2026, 1, 1),
      );

  testWidgets('archiving moves a row out of the active section', (tester) async {
    final scope = await pumpScreen(tester, const InspirationsScreen());
    scope.read(inspirationsProvider.notifier).state = [seed('idea')];
    await tester.pumpAndSettle();

    expect(find.text(zh.pending), findsOneWidget);
    expect(find.text(zh.archived), findsNothing);

    await tester.tap(find.byIcon(Icons.archive_outlined));
    await tester.pumpAndSettle();

    // The section header is what moved; the row itself is inside the collapsed
    // archived block, so it is no longer rendered
    expect(find.text(zh.pending), findsNothing);
    expect(find.text(zh.archived), findsOneWidget);
    expect(find.text('idea'), findsNothing);
  });

  testWidgets('the archived section starts collapsed and expands on tap',
      (tester) async {
    final scope = await pumpScreen(tester, const InspirationsScreen());
    scope.read(inspirationsProvider.notifier).state = [
      seed('filed', archived: true),
    ];
    await tester.pumpAndSettle();

    expect(find.text('filed'), findsNothing);

    await tester.tap(find.text(zh.archived));
    await tester.pumpAndSettle();

    expect(find.text('filed'), findsOneWidget);
  });

  testWidgets('unarchiving puts the row back where it came from',
      (tester) async {
    final scope = await pumpScreen(tester, const InspirationsScreen());
    scope.read(inspirationsProvider.notifier).state = [
      seed('done', completed: true, archived: true),
    ];
    await tester.pumpAndSettle();

    await tester.tap(find.text(zh.archived));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.unarchive_outlined));
    await tester.pumpAndSettle();

    // Completed, not active — archiving never touched is_completed
    expect(find.text(zh.completed), findsOneWidget);
    expect(find.text(zh.pending), findsNothing);
    expect(find.text('done'), findsOneWidget);
  });

  test('an old row with no is_archived column reads as not archived', () {
    final item = Inspiration.fromJson({
      'id': 'x',
      'title': 'x',
      'content': null,
      'is_completed': false,
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    expect(item.isArchived, isFalse);
  });
}
