import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/recent_picks.dart';

// The task sheet's one-tap suggestions (system_design.md §3-A)
void main() {
  group('withRecentPick', () {
    test('the newest pick goes first and is never listed twice', () {
      var picks = withRecentPick(const [], 'a');
      picks = withRecentPick(picks, 'b');
      picks = withRecentPick(picks, 'a');
      expect(picks, ['a', 'b']);
    });

    test('only the last few are kept', () {
      var picks = <String>[];
      for (var i = 0; i < kRecentPicksKept + 4; i++) {
        picks = withRecentPick(picks, 'id$i');
      }
      expect(picks, hasLength(kRecentPicksKept));
      expect(picks.first, 'id${kRecentPicksKept + 3}');
    });
  });

  group('resolveRecent', () {
    test('keeps recent order and skips what no longer exists', () {
      final live = {'a': 'Alpha', 'c': 'Charlie'};
      expect(resolveRecent(['c', 'b', 'a'], live, 3), ['Charlie', 'Alpha']);
    });

    test('never offers more than the limit', () {
      final live = {'a': 1, 'b': 2, 'c': 3, 'd': 4};
      expect(resolveRecent(['a', 'b', 'c', 'd'], live, 3), [1, 2, 3]);
    });
  });

  group('suggestedDueDate', () {
    test('a time still to come lands today', () {
      final now = DateTime(2026, 9, 16, 9, 30);
      expect(suggestedDueDate('14:00', now), DateTime(2026, 9, 16, 14, 0));
    });

    test('a time already gone rolls over to tomorrow', () {
      final now = DateTime(2026, 9, 16, 18, 0);
      expect(suggestedDueDate('14:00', now), DateTime(2026, 9, 17, 14, 0));
    });

    test('the current minute counts as gone, not as now', () {
      final now = DateTime(2026, 9, 16, 14, 0);
      expect(suggestedDueDate('14:00', now), DateTime(2026, 9, 17, 14, 0));
    });

    test('rolling over at the end of a month moves to the first', () {
      final now = DateTime(2026, 9, 30, 23, 30);
      expect(suggestedDueDate('08:00', now), DateTime(2026, 10, 1, 8, 0));
    });

    test('formatClock pads both halves', () {
      expect(formatClock(DateTime(2026, 1, 2, 9, 5)), '09:05');
    });
  });
}
