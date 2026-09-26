import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/review_stats.dart';
import '../models/review.dart';
import 'settings_provider.dart';
import 'synced_list_notifier.dart';

class ReviewsNotifier extends SyncedListNotifier<Review> {
  ReviewsNotifier(super.ref)
      : super(
          table: 'reviews',
          localKey: 'guest_reviews',
          orderColumn: 'period_start',
          orderAscending: false,
        );

  @override
  Review fromJson(Map<String, dynamic> json) => Review.fromJson(json);

  @override
  Map<String, dynamic> toJson(Review item) => item.toJson();

  @override
  String idOf(Review item) => item.id;

  // One review per period: doing a week over replaces its row rather than
  // adding a second one (the table enforces the same with a unique key)
  void save(Review review) {
    final existing = state.where((r) => r.period == review.period && r.periodStart == review.periodStart).firstOrNull;
    final kept = existing == null
        ? review
        : Review(
            id: existing.id,
            period: review.period,
            periodStart: review.periodStart,
            periodEnd: review.periodEnd,
            wentWell: review.wentWell,
            stuck: review.stuck,
            nextFocus: review.nextFocus,
            focusTargetIds: review.focusTargetIds,
            stats: review.stats,
            createdAt: existing.createdAt,
          );
    state = [
      kept,
      for (final r in state)
        if (r.id != kept.id) r,
    ]..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    upsert(kept);
  }

  void remove(String id) {
    state = state.where((r) => r.id != id).toList();
    deleteRow(id);
  }
}

final reviewsProvider = StateNotifierProvider<ReviewsNotifier, List<Review>>(
  (ref) => ReviewsNotifier(ref),
);

// "Now" for the review rules: the app's day (so developer mode's date override
// moves it) with the wall-clock time, since the Sunday 18:00 rule needs an
// hour. Its own provider so tests can pin it
final reviewNowProvider = Provider<DateTime>((ref) {
  final day = ref.watch(effectiveNowProvider);
  final clock = DateTime.now();
  return DateTime(day.year, day.month, day.day, clock.hour, clock.minute);
});

// The review the task page offers right now, or null
final dueReviewProvider = Provider<ReviewWindow?>((ref) => dueReviewWindow(
      now: ref.watch(reviewNowProvider),
      settings: ref.watch(semesterSettingsProvider),
      done: ref.watch(reviewsProvider),
    ));

// The targets picked in the last weekly review, for "focus this week"
final activeFocusProvider = Provider<List<String>>((ref) => activeFocus(
      ref.watch(reviewsProvider),
      ref.watch(reviewNowProvider),
    ));
