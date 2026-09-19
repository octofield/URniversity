import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/avatars.dart';
import 'package:urniversity/core/theme/app_colors.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/utils/category_helpers.dart';

// The colours a category can be given. The list grew from 12 to 24; the built-in
// six have to keep their place, or an existing category would change colour just
// because the list was extended.
void main() {
  test('the palette offers 24 distinct colours', () {
    expect(categoryColorPresets, hasLength(24));
    final unique = {for (final c in categoryColorPresets) c.toARGB32()};
    expect(unique, hasLength(categoryColorPresets.length), reason: 'no duplicates');
  });

  test('the built-in category colours still come first, in order', () {
    expect(categoryColorPresets.take(6).map((c) => c.toARGB32()), [
      AppColors.categoryExchange.toARGB32(),
      AppColors.categoryIntern.toARGB32(),
      AppColors.categoryCompetition.toARGB32(),
      AppColors.categoryCert.toARGB32(),
      AppColors.categoryPerformance.toARGB32(),
      AppColors.categoryOther.toARGB32(),
    ]);
  });

  test('the avatar presets grew without moving the old ones', () {
    // avatar_index is stored per user, so reordering swaps everyone's avatar
    expect(AppAvatars.presets, hasLength(24));
    expect(AppAvatars.presets.first.icon, Icons.auto_awesome);
    expect(AppAvatars.presets[9].icon, Icons.rocket_launch);
  });

  test('every default category colour is pickable', () {
    for (final id in FutureCategories.builtIns) {
      expect(
        categoryColorPresets.map((c) => c.toARGB32()),
        contains(defaultCatColor(id).toARGB32()),
        reason: id,
      );
    }
  });
}
