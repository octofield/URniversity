import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/gpa_stats.dart';
import 'package:urniversity/core/grade_scale.dart';
import 'package:urniversity/models/course.dart';

// Grades and GPA (system_design.md §3-T), checked against NTU's own tables
void main() {
  Course course(String semester, double credits, String? grade, {bool counts = true}) => Course(
        id: '$semester-$credits-$grade',
        semester: semester,
        title: 'c',
        credits: credits,
        grade: grade,
        countsInGpa: counts,
        color: 0,
        createdAt: DateTime(2026),
      );

  group('the grade scale', () {
    test('every letter carries the registrar\'s points', () {
      expect(kGradePoints, {
        'A+': 4.3, 'A': 4.0, 'A-': 3.7, 'B+': 3.3, 'B': 3.0, 'B-': 2.7,
        'C+': 2.3, 'C': 2.0, 'C-': 1.7, 'F': 0.0, 'X': 0.0,
      });
    });

    test('undergraduates pass at C-, graduate students at B-', () {
      expect(isPassing('C-', DegreeLevel.bachelor), isTrue);
      expect(isPassing('F', DegreeLevel.bachelor), isFalse);
      expect(isPassing('C+', DegreeLevel.graduate), isFalse);
      expect(isPassing('B-', DegreeLevel.graduate), isTrue);
      expect(isPassing(kGradePass, DegreeLevel.graduate), isTrue);
      expect(isPassing(kGradeWithdrawn, DegreeLevel.bachelor), isFalse);
    });
  });

  group('GPA to percentage', () {
    // Read off the registrar's printed table, across every segment
    test('matches the printed table', () {
      final printed = <double, double>{
        4.30: 100.0, 4.29: 99.63, 4.13: 93.77, 4.00: 89.00, 3.99: 88.83,
        3.81: 85.83, 3.69: 83.88, 3.62: 83.00, 3.31: 79.13, 3.29: 78.90,
        3.01: 76.10, 2.99: 75.87, 2.83: 73.73, 2.69: 71.93, 2.52: 70.65,
        2.31: 69.08, 2.29: 68.90, 2.01: 66.10, 1.99: 65.80, 1.81: 62.20,
        1.71: 60.20, 1.70: 60.00,
      };
      for (final e in printed.entries) {
        expect(gpaToPercent(e.key), e.value, reason: 'GPA ${e.key}');
      }
    });

    test('has no value below 1.70', () {
      expect(gpaToPercent(1.69), isNull);
      expect(gpaToPercent(0), isNull);
    });
  });

  group('GPA', () {
    test('is weighted by credits', () {
      // (4.0·3 + 3.0·2) / 5 = 3.6
      expect(gpaOf([course('115-1', 3, 'A'), course('115-1', 2, 'B')]), 3.6);
    });

    test('F and X count, at zero', () {
      expect(gpaOf([course('115-1', 2, 'A'), course('115-1', 2, 'F')]), 2.0);
      expect(gpaOf([course('115-1', 2, 'A'), course('115-1', 2, 'X')]), 2.0);
    });

    test('pass/fail, withdrawn, ungraded and switched-off courses do not', () {
      expect(gpaOf([
        course('115-1', 3, 'A'),
        course('115-1', 2, kGradePass),
        course('115-1', 2, kGradeWithdrawn),
        course('115-1', 2, null),
        course('115-1', 1, 'F', counts: false),
      ]), 4.0);
    });

    test('nothing graded is unknown, not zero', () {
      expect(gpaOf([course('115-1', 3, null)]), isNull);
    });

    test('by semester and cumulative', () {
      final all = [course('114-2', 3, 'B'), course('115-1', 3, 'A')];
      expect(semesterGpa(all, '115-1'), 4.0);
      expect(cumulativeGpa(all), 3.5);
      expect(gpaBySemester(all), [('114-2', 3.0), ('115-1', 4.0)]);
    });

    test('rounds to two decimals, as the transcript does', () {
      // (4.3·3 + 3.7·3 + 3.0·3) / 9 = 3.6666…
      expect(gpaOf([course('a', 3, 'A+'), course('a', 3, 'A-'), course('a', 3, 'B')]), 3.67);
    });
  });

  group('earned credits', () {
    test('only passed courses, by the degree\'s pass mark', () {
      final all = [course('a', 3, 'A'), course('a', 2, 'C'), course('a', 2, 'F'), course('a', 1, kGradePass)];
      expect(earnedCredits(all, DegreeLevel.bachelor), 6);
      expect(earnedCredits(all, DegreeLevel.graduate), 4);
    });
  });

  group('what the rest must average', () {
    test('reachable', () {
      // 3 credits of A (12 points) + 3 pending; 3.8 over 6 credits needs 22.8,
      // so the pending 3 credits must average 3.6
      final outcome = requiredAverage(3.8, [course('a', 3, 'A'), course('b', 3, null)]);
      expect(outcome, isA<TargetNeeds>());
      expect((outcome as TargetNeeds).average, 3.6);
      expect(outcome.credits, 3);
    });

    test('out of reach says the best possible', () {
      final outcome = requiredAverage(4.2, [course('a', 9, 'B'), course('b', 3, null)]);
      expect(outcome, isA<TargetOutOfReach>());
      // (27 + 12.9) / 12 = 3.325
      expect((outcome as TargetOutOfReach).best, 3.32);
    });

    test('already met, and nothing left to change', () {
      expect(requiredAverage(1.0, [course('a', 9, 'A+'), course('b', 1, null)]), isA<TargetAlreadyMet>());
      expect(requiredAverage(3.0, [course('a', 3, 'A')]), isA<TargetNoCourses>());
    });
  });
}
