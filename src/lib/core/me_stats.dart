import '../models/journal.dart';

// The numbers on the "me" page's summary tiles.
//
// Pure so the streak rule is testable: journal_provider back-fills every missed
// day with a placeholder entry, so counting entries would always give "every
// day since you started". Only entries the user actually wrote count.
int journalStreak(List<Journal> journals, DateTime now, {required bool Function(Journal) written}) {
  final byDay = <DateTime, Journal>{};
  for (final j in journals) {
    byDay[DateTime(j.date.year, j.date.month, j.date.day)] = j;
  }

  var streak = 0;
  var day = DateTime(now.year, now.month, now.day);
  // Today not being written yet does not break a streak that is still going —
  // the count simply starts at yesterday
  final todayEntry = byDay[day];
  if (todayEntry == null || !written(todayEntry)) {
    day = day.subtract(const Duration(days: 1));
  }

  while (true) {
    final entry = byDay[day];
    if (entry == null || !written(entry)) break;
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
