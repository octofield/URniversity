import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/period_tables.dart';
import 'package:urniversity/core/timetable.dart';
import 'package:urniversity/models/course.dart';

// Free time two people share (system_design.md §3-V)
CourseSession _at(int weekday, int h1, int m1, int h2, int m2) =>
    CourseSession(weekday: weekday, startMinute: h1 * 60 + m1, endMinute: h2 * 60 + m2);

String _show(List<FreeSlot> slots) => [
      for (final f in slots)
        '${f.weekday} ${(f.start ~/ 60).toString().padLeft(2, '0')}:${(f.start % 60).toString().padLeft(2, '0')}'
            '–${(f.end ~/ 60).toString().padLeft(2, '0')}:${(f.end % 60).toString().padLeft(2, '0')}',
    ].join(', ');

List<FreeSlot> _on(List<FreeSlot> slots, int weekday) => slots.where((f) => f.weekday == weekday).toList();

void main() {
  group('commonFreeSlots', () {
    test('lines up with whole periods, across lunch', () {
      final slots = commonFreeSlots(
        [_at(3, 10, 20, 12, 10)],
        [_at(3, 15, 30, 17, 20)],
        periods: kNtuPeriods,
      );
      expect(_show(_on(slots, 3)), '3 08:10–10:00, 3 12:20–15:10, 3 17:30–18:20');
    });

    test('a day with no class for either is free from first period to last', () {
      final slots = commonFreeSlots([_at(3, 10, 20, 12, 10)], [], periods: kNtuPeriods);
      expect(_show(_on(slots, 1)), '1 08:10–18:20');
      // Monday to Friday only, with nobody meeting at the weekend
      expect(slots.map((f) => f.weekday).toSet(), {1, 2, 3, 4, 5});
    });

    test('nothing on a day the two fill between them', () {
      final slots = commonFreeSlots(
        [_at(2, 8, 0, 13, 10)],
        [_at(2, 13, 0, 19, 0)],
        periods: kNtuPeriods,
      );
      expect(_on(slots, 2), isEmpty);
    });

    test('without a period table, by the clock from 08:00 to 18:00', () {
      final slots = commonFreeSlots([_at(1, 9, 0, 12, 0)], [_at(1, 14, 0, 15, 0)]);
      expect(_show(_on(slots, 1)), '1 08:00–09:00, 1 12:00–14:00, 1 15:00–18:00');
    });

    test('a weekend day counts once either of them has a class on it', () {
      final slots = commonFreeSlots([], [_at(6, 10, 0, 12, 0)]);
      expect(_show(_on(slots, 6)), '6 08:00–10:00, 6 12:00–18:00');
      expect(_on(slots, 7), isEmpty);
    });

    test('a gap holding no whole period is no slot', () {
      // 08:10–08:50 is only part of period 1 (08:10–09:00)
      final slots = commonFreeSlots([_at(5, 8, 50, 18, 30)], [], periods: kNtuPeriods);
      expect(_on(slots, 5), isEmpty);
    });

    test('a gap shorter than a period is left out', () {
      final slots = commonFreeSlots([_at(4, 8, 0, 10, 0)], [_at(4, 10, 30, 18, 0)]);
      expect(_on(slots, 4), isEmpty);
      final longer = commonFreeSlots([_at(4, 8, 0, 10, 0)], [_at(4, 10, 50, 18, 0)]);
      expect(_show(_on(longer, 4)), '4 10:00–10:50');
    });
  });

  group('nextSlotStart', () {
    // 2026-10-21 is a Wednesday
    const slot = FreeSlot(3, 13 * 60 + 20, 15 * 60 + 10);

    test('later today when it is still ahead', () {
      expect(nextSlotStart(slot, DateTime(2026, 10, 21, 12)), DateTime(2026, 10, 21, 13, 20));
    });

    test('next week once it has begun', () {
      expect(nextSlotStart(slot, DateTime(2026, 10, 21, 14)), DateTime(2026, 10, 28, 13, 20));
    });

    test('this week from an earlier day', () {
      expect(nextSlotStart(slot, DateTime(2026, 10, 18, 9)), DateTime(2026, 10, 21, 13, 20));
    });
  });
}
