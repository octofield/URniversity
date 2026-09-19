import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/me_stats.dart';
import 'package:urniversity/models/journal.dart';

// The journal streak on the me page. journal_provider back-fills every missed
// day with a placeholder, so counting entries would always say "every day" —
// only what the user actually wrote counts.
void main() {
  Journal entry(DateTime date, {bool auto = false}) => Journal(
        id: auto ? 'auto_${date.day}' : 'j${date.day}',
        date: date,
        content: auto ? '好像忘記什麼了......' : '寫了點東西',
        createdAt: date,
      );

  bool written(Journal j) => !j.id.startsWith('auto_');

  test('counts back from today', () {
    final now = DateTime(2026, 9, 19, 21);
    final journals = [
      entry(DateTime(2026, 9, 19)),
      entry(DateTime(2026, 9, 18)),
      entry(DateTime(2026, 9, 17)),
    ];
    expect(journalStreak(journals, now, written: written), 3);
  });

  test('a back-filled day breaks it', () {
    final now = DateTime(2026, 9, 19, 21);
    final journals = [
      entry(DateTime(2026, 9, 19)),
      entry(DateTime(2026, 9, 18), auto: true),
      entry(DateTime(2026, 9, 17)),
    ];
    expect(journalStreak(journals, now, written: written), 1);
  });

  test('not having written today yet does not end the streak', () {
    final now = DateTime(2026, 9, 19, 9);
    final journals = [
      entry(DateTime(2026, 9, 18)),
      entry(DateTime(2026, 9, 17)),
    ];
    expect(journalStreak(journals, now, written: written), 2);
  });

  test('nothing written at all is zero', () {
    expect(journalStreak(const [], DateTime(2026, 9, 19), written: written), 0);
  });
}
