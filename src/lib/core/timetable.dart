import '../models/course.dart';

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
