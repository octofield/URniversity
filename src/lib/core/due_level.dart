// How urgent a task's due time looks (system_design.md §3-B): orange from
// three hours before it until a day after, red once a day late. The first
// version turned orange a whole day ahead and red the moment it passed, which
// read as alarming too early and too late at once

enum DueLevel { none, warning, late }

const kDueWarningBefore = Duration(hours: 3);
const kDueLateAfter = Duration(hours: 24);

DueLevel dueLevel(DateTime due, DateTime now) {
  if (due.isAfter(now)) {
    return due.difference(now) <= kDueWarningBefore ? DueLevel.warning : DueLevel.none;
  }
  return now.difference(due) < kDueLateAfter ? DueLevel.warning : DueLevel.late;
}

// "Postpone a day" on an overdue task: tomorrow at the time it was due, however
// late it already is, so a task three days late is not still late after it
DateTime postponedToTomorrow(DateTime due, DateTime now) =>
    DateTime(now.year, now.month, now.day + 1, due.hour, due.minute);

// Only a one-off task, not done, whose due time has passed
bool canPostpone({required DateTime? due, required bool repeats, required bool done, required DateTime now}) =>
    due != null && !repeats && !done && due.isBefore(now);
