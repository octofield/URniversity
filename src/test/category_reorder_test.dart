import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/providers/categories_provider.dart';

// CategoriesNotifier.reorder takes the indices ReorderableListView's
// onReorderItem hands over, which the framework has ALREADY adjusted for the
// item being lifted out of the list. So reorder is a plain "remove at oldIndex,
// insert at newIndex" — it must not adjust the index a second time.
//
// The old onReorder callback passed raw indices and left the adjustment to the
// caller; reorder used to do it here. Keeping that line after the migration
// dropped every downward drag one slot short, which is what these tests pin.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  List<String> idsAfter(int oldIndex, int newIndex) {
    final notifier = container.read(categoriesProvider.notifier);
    notifier.reorder(oldIndex, newIndex);
    return [for (final c in container.read(categoriesProvider)) c.id];
  }

  test('starts from the built-in order', () {
    expect(
      [for (final c in container.read(categoriesProvider)) c.id],
      FutureCategories.builtIns,
    );
  });

  group('reorder', () {
    test('dragging down lands on the requested index', () {
      // exchange, intern, competition, certification, performance, other
      //    0         1          2            3             4         5
      // Drag "exchange" down to slot 2
      expect(idsAfter(0, 2), [
        FutureCategories.intern,
        FutureCategories.competition,
        FutureCategories.exchange,
        FutureCategories.certification,
        FutureCategories.performance,
        FutureCategories.other,
      ]);
    });

    test('dragging up lands on the requested index', () {
      expect(idsAfter(3, 1), [
        FutureCategories.exchange,
        FutureCategories.certification,
        FutureCategories.intern,
        FutureCategories.competition,
        FutureCategories.performance,
        FutureCategories.other,
      ]);
    });

    test('first to last', () {
      expect(idsAfter(0, 5), [
        FutureCategories.intern,
        FutureCategories.competition,
        FutureCategories.certification,
        FutureCategories.performance,
        FutureCategories.other,
        FutureCategories.exchange,
      ]);
    });

    test('last to first', () {
      expect(idsAfter(5, 0), [
        FutureCategories.other,
        FutureCategories.exchange,
        FutureCategories.intern,
        FutureCategories.competition,
        FutureCategories.certification,
        FutureCategories.performance,
      ]);
    });

    test('moving an item onto its own index is a no-op', () {
      expect(idsAfter(2, 2), FutureCategories.builtIns);
    });

    test('a neighbouring swap moves exactly one slot', () {
      // The regression this guards: with a double adjustment (1, 2) would put
      // intern back where it started instead of after competition
      expect(idsAfter(1, 2), [
        FutureCategories.exchange,
        FutureCategories.competition,
        FutureCategories.intern,
        FutureCategories.certification,
        FutureCategories.performance,
        FutureCategories.other,
      ]);
    });
  });
}
