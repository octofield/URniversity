import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/period_tables.dart';
import 'package:urniversity/core/timetable.dart';
import 'package:urniversity/models/course.dart';

// The timetable's rules (system_design.md §3-S): the schools' official period
// tables, clashes, the week of term, and today's classes. Reading each school's
// time strings is tested with the script (scripts/catalog/tests)
void main() {
  int hm(int h, int m) => h * 60 + m;

  group('NTU periods', () {
    test('match the registrar\'s table period by period', () {
      const official = {
        '0': '07:10-08:00', '1': '08:10-09:00', '2': '09:10-10:00', '3': '10:20-11:10',
        '4': '11:20-12:10', '5': '12:20-13:10', '6': '13:20-14:10', '7': '14:20-15:10',
        '8': '15:30-16:20', '9': '16:30-17:20', '10': '17:30-18:20', 'A': '18:25-19:15',
        'B': '19:20-20:10', 'C': '20:15-21:05', 'D': '21:10-22:00',
      };
      String fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
      expect(kNtuPeriods.map((p) => p.label), official.keys);
      for (final p in kNtuPeriods) {
        expect('${fmt(p.start)}-${fmt(p.end)}', official[p.label], reason: 'period ${p.label}');
      }
    });

    test('each school finds its own table; one without gets clock times', () {
      expect(periodsFor(kNtuSchool), kNtuPeriods);
      expect(periodsFor(kNthuSchool), kNthuPeriods);
      expect(periodsFor('國立政治大學'), isNull);
      expect(periodsFor(null), isNull);
    });

    test('NTHU matches its registrar\'s table period by period', () {
      const official = {
        '1': '08:00-08:50', '2': '09:00-09:50', '3': '10:10-11:00', '4': '11:10-12:00',
        'n': '12:10-13:00', '5': '13:20-14:10', '6': '14:20-15:10', '7': '15:30-16:20',
        '8': '16:30-17:20', '9': '17:30-18:20', 'a': '18:30-19:20', 'b': '19:30-20:20',
        'c': '20:30-21:20', 'd': '21:30-22:20',
      };
      String fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
      expect(kNthuPeriods.map((p) => p.label), official.keys);
      for (final p in kNthuPeriods) {
        expect('${fmt(p.start)}-${fmt(p.end)}', official[p.label], reason: 'period ${p.label}');
      }
      expect(periodRangeLabel(kNthuPeriods, hm(15, 30), hm(19, 20)), '7–a');
    });

    test('a session is labelled by the periods it spans', () {
      expect(periodRangeLabel(kNtuPeriods, hm(10, 20), hm(12, 10)), '3–4');
      expect(periodRangeLabel(kNtuPeriods, hm(18, 25), hm(19, 15)), 'A');
      expect(periodRangeLabel(kNtuPeriods, hm(10, 0), hm(11, 0)), isNull);
    });
  });

  group('clashes', () {
    final calc = Course(
      id: 'calc', semester: '115-1', title: '微積分', color: 0, createdAt: DateTime(2026),
      sessions: [CourseSession(weekday: 1, startMinute: hm(10, 20), endMinute: hm(12, 10))],
    );

    test('an overlap on the same day clashes', () {
      final clash = clashingCourses([CourseSession(weekday: 1, startMinute: hm(11, 20), endMinute: hm(12, 10))], [calc]);
      expect(clash, [calc]);
    });

    test('touching ends, or another day, do not', () {
      expect(clashingCourses([CourseSession(weekday: 1, startMinute: hm(12, 10), endMinute: hm(13, 0))], [calc]), isEmpty);
      expect(clashingCourses([CourseSession(weekday: 2, startMinute: hm(10, 20), endMinute: hm(12, 10))], [calc]), isEmpty);
    });
  });

  group('the week of term', () {
    final first = DateTime(2026, 9, 7); // a Monday

    test('counts from the week of the first day', () {
      expect(weekOfTerm(DateTime(2026, 9, 7), first), 1);
      expect(weekOfTerm(DateTime(2026, 9, 13), first), 1);
      expect(weekOfTerm(DateTime(2026, 9, 14), first), 2);
      expect(weekOfTerm(DateTime(2026, 9, 6), first), 0);
    });

    test('term runs for the given number of weeks', () {
      expect(inTerm(DateTime(2026, 9, 7), first, 16), isTrue);
      expect(inTerm(DateTime(2026, 12, 27), first, 16), isTrue); // Sunday of week 16
      expect(inTerm(DateTime(2026, 12, 28), first, 16), isFalse);
      expect(inTerm(DateTime(2026, 9, 6), first, 16), isFalse);
    });

    test('the suggestion is the first Monday on or after the start', () {
      expect(suggestedFirstDay(DateTime(2026, 9, 1)), DateTime(2026, 9, 7));
      expect(suggestedFirstDay(DateTime(2026, 9, 7)), DateTime(2026, 9, 7));
    });
  });

  group('today', () {
    CourseSession at(int weekday, int start, int end) =>
        CourseSession(weekday: weekday, startMinute: start, endMinute: end);
    Course course(String id, String semester, List<CourseSession> sessions) =>
        Course(id: id, semester: semester, title: id, color: 0, createdAt: DateTime(2026), sessions: sessions);
    final courses = [
      course('a', '115-1', [at(3, hm(8, 10), hm(10, 0)), at(4, hm(9, 0), hm(10, 0))]),
      course('b', '115-1', [at(3, hm(13, 20), hm(15, 10))]),
      course('c', '115-1', [at(3, hm(15, 30), hm(16, 20))]),
      course('old', '114-2', [at(3, hm(9, 0), hm(10, 0))]),
    ];
    final wednesday = DateTime(2026, 9, 23);

    test('only that weekday, only that semester, in order', () {
      final today = meetingsOn(wednesday, '115-1', courses);
      expect(today.map((m) => m.course.id), ['a', 'b', 'c']);
    });

    test('done, now, next and later', () {
      final today = meetingsOn(wednesday, '115-1', courses);
      expect(meetingStates(today, DateTime(2026, 9, 23, 13, 30)),
          [MeetingState.done, MeetingState.now, MeetingState.next]);
      expect(meetingStates(today, DateTime(2026, 9, 23, 11)),
          [MeetingState.done, MeetingState.next, MeetingState.later]);
      expect(meetingStates(today, DateTime(2026, 9, 23, 17)),
          [MeetingState.done, MeetingState.done, MeetingState.done]);
    });
  });

  group('the grid', () {
    test('08–18 on weekdays by default', () {
      expect(gridBounds(const []), (startHour: 8, endHour: 18, days: 5));
    });

    test('grows for early, late and weekend classes', () {
      final b = gridBounds([
        CourseSession(weekday: 6, startMinute: hm(7, 10), endMinute: hm(8, 0)),
        CourseSession(weekday: 2, startMinute: hm(21, 10), endMinute: hm(22, 0)),
      ]);
      expect(b, (startHour: 7, endHour: 22, days: 6));
    });
  });
}
