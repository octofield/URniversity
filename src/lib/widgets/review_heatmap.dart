import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';

// One square per day, a column per week (Monday on top), the way contribution
// calendars look: consistency reads at a glance, and a gap of grey days says
// "nothing planned" rather than "failed", which a 0% bar cannot say.
class ReviewHeatmap extends StatelessWidget {
  // One per day, oldest first, starting on a Monday; null = nothing planned
  final List<double?> rates;

  const ReviewHeatmap({super.key, required this.rates});

  static const _cell = 14.0;
  static const _gap = 3.0;

  static Color colourFor(double? rate) {
    if (rate == null) return AppColors.surfaceVariant;
    // Never fully transparent: a day with something planned and nothing done
    // still has to read as a day, next to the grey of an empty one
    return Color.lerp(AppColors.primaryLight, AppColors.primary, rate)!;
  }

  @override
  Widget build(BuildContext context) {
    final weeks = (rates.length / 7).ceil();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // The most recent week is the one worth seeing on a narrow screen
      reverse: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var w = 0; w < weeks; w++)
            Padding(
              padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : _gap),
              child: Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    Padding(
                      padding: EdgeInsets.only(bottom: d == 6 ? 0 : _gap),
                      child: _Day(rate: w * 7 + d < rates.length ? rates[w * 7 + d] : null, exists: w * 7 + d < rates.length),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  final double? rate;
  final bool exists;

  const _Day({required this.rate, required this.exists});

  @override
  Widget build(BuildContext context) => Container(
        width: ReviewHeatmap._cell,
        height: ReviewHeatmap._cell,
        decoration: BoxDecoration(
          // Days past the end of the range (the rest of this week) stay empty
          color: exists ? ReviewHeatmap.colourFor(rate) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      );
}
