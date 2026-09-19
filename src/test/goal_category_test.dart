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

  test('an uncategorized row still gets a colour and an icon', () {
    expect(resolveCatColor(cats, null), noCategoryColor);
    expect(resolveCatIcon(cats, null), noCategoryIcon);
  });

  test('a categorized row is unaffected', () {
    expect(
      resolveCatColor(cats, FutureCategories.intern),
      defaultCatColor(FutureCategories.intern),
    );
    expect(resolveCatColor(cats, null), isNot(defaultCatColor(FutureCategories.other)));
  });
}
