import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/category.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/utils/category_helpers.dart';

// Picking a category is optional. It used to be silently turned into "其他" on
// save, which is a real category the user may be using for something else — an
// uncategorized target now stays uncategorized and shows a neutral colour.
void main() {
  const cats = <CategoryEntry>[];

  test('no category means no category', () {
    expect(primaryCategoryOf(const []), isNull);
    expect(primaryCategoryOf(const ['intern', 'exchange']), 'intern');
  });

  test('an uncategorized row gets nothing to draw', () {
    // Not a neutral tint: that reads as a category the user cannot place
    expect(categoryColorOrNull(cats, null), isNull);
    expect(categoryIconOrNull(cats, null), isNull);
  });

  test('a goal with no category of its own borrows its vision colour', () {
    const vision = FutureGoal(
      id: 'v',
      title: '出國交換',
      categories: [FutureCategories.exchange],
    );

    expect(goalEffectiveColor(cats, const []), isNull);
    expect(
      goalEffectiveColor(cats, const [], linkedVision: vision),
      defaultCatColor(FutureCategories.exchange),
    );
    // Its own category wins over the vision's
    expect(
      goalEffectiveColor(cats, const [FutureCategories.intern],
          linkedVision: vision),
      defaultCatColor(FutureCategories.intern),
    );
  });

  test('a categorized row is unaffected', () {
    expect(
      resolveCatColor(cats, FutureCategories.intern),
      defaultCatColor(FutureCategories.intern),
    );
    expect(categoryColorOrNull(cats, FutureCategories.other),
        defaultCatColor(FutureCategories.other));
  });
}
