import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../models/future_goal.dart';

String catLabel(String cat, AppStrings s) {
  switch (cat) {
    case FutureCategories.exchange:      return s.catExchange;
    case FutureCategories.intern:        return s.catIntern;
    case FutureCategories.competition:   return s.catCompetition;
    case FutureCategories.certification: return s.catCertification;
    case FutureCategories.performance:   return s.catPerformance;
    case FutureCategories.other:         return s.catOther;
    default:                             return cat;
  }
}

IconData catIcon(String cat) {
  const icons = <String, IconData>{
    FutureCategories.exchange:      Icons.flight_outlined,
    FutureCategories.intern:        Icons.work_outline,
    FutureCategories.competition:   Icons.emoji_events_outlined,
    FutureCategories.certification: Icons.card_membership_outlined,
    FutureCategories.performance:   Icons.mic_outlined,
    FutureCategories.other:         Icons.star_outline,
  };
  return icons[cat] ?? Icons.label_outline;
}

Color catColor(String cat) {
  switch (cat) {
    case FutureCategories.exchange:      return AppColors.categoryExchange;
    case FutureCategories.intern:        return AppColors.categoryIntern;
    case FutureCategories.competition:   return AppColors.categoryCompetition;
    case FutureCategories.certification: return AppColors.categoryCert;
    case FutureCategories.performance:   return AppColors.categoryPerformance;
    default:                             return AppColors.categoryOther;
  }
}
