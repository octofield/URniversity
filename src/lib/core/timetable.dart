import '../models/course.dart';
import 'period_tables.dart';

// The rules behind the timetable (system_design.md §3-S). Pure functions, like
// review_stats.dart, so each is unit-tested and the screens only draw them.
// Reading a school's own time strings is not here: scripts/catalog does it
// once, and the catalog hands the app ready sessions

bool _overlaps(int weekday, int start, int end, CourseSession other) =>
    other.weekday == weekday && start < other.endMinute && other.startMinute < end;

// Which of [courses] the candidate meetings clash with — for "clashes with
// Calculus" in the search results. Adding is still allowed
List<Course> clashingCourses(List<CourseSession> candidate, List<Course> courses) => [
      for (final course in courses)
        if (candidate.any((c) => course.sessions.any((s) => _overlaps(c.weekday, c.startMinute, c.endMinute, s))))
          course,
    ];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

// Week 1 is the week of the first day of classes; 0 or less is before term
int weekOfTerm(DateTime date, DateTime firstDay) {
  final monday = _day(firstDay).subtract(Duration(days: firstDay.weekday - 1));
  final days = _day(date).difference(monday).inDays;
  return days < 0 ? 0 : days ~/ 7 + 1;
}

// Between the first day of classes and the end of the last teaching week
bool inTerm(DateTime date, DateTime firstDay, int weeks) {
  final w = weekOfTerm(date, firstDay);
  return w >= 1 && w <= weeks && !_day(date).isBefore(_day(firstDay));
}

// The suggested first day of classes when the user has not said: the first
// Monday on or after the day the semester starts
DateTime suggestedFirstDay(DateTime semesterStart) {
  final d = _day(semesterStart);
  return d.add(Duration(days: (DateTime.monday - d.weekday + 7) % 7));
}

// A course's meeting on a given day, with the course it belongs to
class ClassMeeting {
  final Course course;
  final CourseSession session;

  const ClassMeeting(this.course, this.session);
}

// The meetings on [date]'s weekday, of courses in [semester], by start time
List<ClassMeeting> meetingsOn(DateTime date, String semester, List<Course> courses) => [
      for (final c in courses)
        if (c.semester == semester)
          for (final s in c.sessions)
            if (s.weekday == date.weekday) ClassMeeting(c, s),
    ]..sort((a, b) => a.session.startMinute.compareTo(b.session.startMinute));

enum MeetingState { done, now, next, later }

// How each of today's meetings stands at [now]: over, happening, the next one,
// or later on
List<MeetingState> meetingStates(List<ClassMeeting> today, DateTime now) {
  final minute = now.hour * 60 + now.minute;
  var nextGiven = false;
  final out = <MeetingState>[];
  for (final m in today) {
    if (m.session.endMinute <= minute) {
      out.add(MeetingState.done);
    } else if (m.session.startMinute <= minute) {
      out.add(MeetingState.now);
    } else if (!nextGiven) {
      nextGiven = true;
      out.add(MeetingState.next);
    } else {
      out.add(MeetingState.later);
    }
  }
  return out;
}

// The rows and columns the weekly grid needs: whole hours around every
// session (08:00–18:00 at the least), and Saturday or Sunday only when
// something meets on them
({int startHour, int endHour, int days}) gridBounds(List<CourseSession> sessions) {
  var start = 8;
  var end = 18;
  var days = 5;
  for (final s in sessions) {
    if (s.startMinute ~/ 60 < start) start = s.startMinute ~/ 60;
    final endHour = (s.endMinute + 59) ~/ 60;
    if (endHour > end) end = endHour;
    if (s.weekday > days) days = s.weekday;
  }
  return (startHour: start, endHour: end, days: days);
}

// The grid's rows, top to bottom (§3-S). With the school's period table, one
// row per period, like a printed timetable: the periods that start between
// 08:00 and 18:00, stretched to take in every session, breaks taking no room.
// Without a table — or when a session lies beyond the table's first or last
// period, where no row could hold it — one row per whole hour of gridBounds
List<ClassPeriod> gridRows(List<ClassPeriod>? periods, List<CourseSession> sessions) {
  final fits = periods != null &&
      periods.isNotEmpty &&
      sessions.every((s) => s.startMinute >= periods.first.start && s.endMinute <= periods.last.end);
  if (!fits) {
    final b = gridBounds(sessions);
    return [
      for (var h = b.startHour; h < b.endHour; h++) ClassPeriod('', h * 60, (h + 1) * 60),
    ];
  }
  bool daytime(ClassPeriod p) => p.start >= 8 * 60 && p.start < 18 * 60;
  bool used(ClassPeriod p) => sessions.any((s) => s.startMinute < p.end && p.start < s.endMinute);
  final first = periods.indexWhere((p) => daytime(p) || used(p));
  final last = periods.lastIndexWhere((p) => daytime(p) || used(p));
  return periods.sublist(first, last + 1);
}

// Where a minute sits on the grid, counted in rows: inside a row by its share
// of that row, in a break on the boundary below it, and clamped at both ends.
// Blocks, the now line and taps all go through this, so a meeting typed by the
// clock rather than by period still lands where it runs
double rowPosition(List<ClassPeriod> rows, int minute) {
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    if (minute < r.start) return i.toDouble();
    if (minute <= r.end) return i + (minute - r.start) / (r.end - r.start);
  }
  return rows.length.toDouble();
}

// When the course next meets after [now], within a week; null if it has no
// meetings. A homework task added from the course is due then by default
DateTime? nextMeetingStart(Course course, DateTime now) {
  DateTime? best;
  for (final s in course.sessions) {
    for (var d = 0; d <= 7; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      if (day.weekday != s.weekday) continue;
      final start = day.add(Duration(minutes: s.startMinute));
      if (!start.isAfter(now)) continue;
      if (best == null || start.isBefore(best)) best = start;
      break;
    }
  }
  return best;
}


// A stretch of a weekday when two people are both free (§3-V), in minutes
// since midnight
class FreeSlot {
  final int weekday;
  final int start;
  final int end;

  const FreeSlot(this.weekday, this.start, this.end);
}

// When neither of two people has a class, week by week: Monday to Friday,
// plus a weekend day either of them has a class on. The day runs over the
// daytime periods of [periods] (those starting 08:00–18:00, like the grid), or
// 08:00–18:00 by the clock without a table. With a table, each gap is trimmed
// to whole periods, so 12:10–15:30 is offered as 12:20–15:10. Gaps shorter
// than [minMinutes] are left out
List<FreeSlot> commonFreeSlots(
  List<CourseSession> mine,
  List<CourseSession> theirs, {
  List<ClassPeriod>? periods,
  int minMinutes = 50,
}) {
  final all = [...mine, ...theirs];
  final daytime = [
    for (final p in periods ?? const <ClassPeriod>[])
      if (p.start >= 8 * 60 && p.start < 18 * 60) p,
  ];
  final dayStart = daytime.isEmpty ? 8 * 60 : daytime.first.start;
  final dayEnd = daytime.isEmpty ? 18 * 60 : daytime.last.end;
  final lastDay = all.any((s) => s.weekday == DateTime.sunday)
      ? 7
      : all.any((s) => s.weekday == DateTime.saturday)
          ? 6
          : 5;
  final out = <FreeSlot>[];
  for (var d = 1; d <= lastDay; d++) {
    if (d == DateTime.saturday && lastDay == 7 && !all.any((s) => s.weekday == d)) continue;
    final busy = [for (final s in all) if (s.weekday == d) s]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    var from = dayStart;
    void gap(int to) {
      var a = from;
      var b = to;
      if (daytime.isNotEmpty) {
        a = daytime.where((p) => p.start >= a).firstOrNull?.start ?? b;
        b = daytime.where((p) => p.end <= b).lastOrNull?.end ?? a;
      }
      if (b - a >= minMinutes) out.add(FreeSlot(d, a, b));
    }
    for (final s in busy) {
      if (s.startMinute > from) gap(s.startMinute < dayEnd ? s.startMinute : dayEnd);
      if (s.endMinute > from) from = s.endMinute;
      if (from >= dayEnd) break;
    }
    if (from < dayEnd) gap(dayEnd);
  }
  return out;
}

// The next time [slot] begins, from [now]: later today, or the same weekday
// next week once today's has begun. "Meet then" makes a task due at this time
DateTime nextSlotStart(FreeSlot slot, DateTime now) {
  var days = (slot.weekday - now.weekday + 7) % 7;
  final today = DateTime(now.year, now.month, now.day);
  if (days == 0 && now.hour * 60 + now.minute >= slot.start) days = 7;
  final day = DateTime(today.year, today.month, today.day + days);
  return day.add(Duration(minutes: slot.start));
}
