import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/due_level.dart';

// When a due time turns orange and red (system_design.md §3-B, 2026-10-03)
void main() {
  final due = DateTime(2026, 10, 3, 14);

  test('orange from three hours before, not earlier', () {
    expect(dueLevel(due, due.subtract(const Duration(hours: 3, minutes: 1))), DueLevel.none);
    expect(dueLevel(due, due.subtract(const Duration(hours: 3))), DueLevel.warning);
    expect(dueLevel(due, due.subtract(const Duration(minutes: 1))), DueLevel.warning);
  });

  test('still orange for the first day after, red from then on', () {
    expect(dueLevel(due, due), DueLevel.warning);
    expect(dueLevel(due, due.add(const Duration(hours: 23, minutes: 59))), DueLevel.warning);
    expect(dueLevel(due, due.add(const Duration(hours: 24))), DueLevel.late);
    expect(dueLevel(due, due.add(const Duration(days: 3))), DueLevel.late);
  });

  group('postpone a day', () {
    final now = DateTime(2026, 10, 3, 9);

    test('to tomorrow at the time it was due, however late it is', () {
      expect(postponedToTomorrow(DateTime(2026, 9, 30, 14, 30), now), DateTime(2026, 10, 4, 14, 30));
      expect(postponedToTomorrow(DateTime(2026, 10, 3, 8), now), DateTime(2026, 10, 4, 8));
    });

    test('only a one-off task, not done, already past its time', () {
      final past = DateTime(2026, 10, 2, 14);
      expect(canPostpone(due: past, repeats: false, done: false, now: now), isTrue);
      expect(canPostpone(due: past, repeats: true, done: false, now: now), isFalse);
      expect(canPostpone(due: past, repeats: false, done: true, now: now), isFalse);
      expect(canPostpone(due: DateTime(2026, 10, 3, 10), repeats: false, done: false, now: now), isFalse);
      expect(canPostpone(due: null, repeats: false, done: false, now: now), isFalse);
    });
  });
}
