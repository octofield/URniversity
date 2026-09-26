import '../models/course.dart';
import 'grade_scale.dart';

// The numbers on the grades page (system_design.md §3-T). Pure functions over
// the courses list, like history_stats.dart. "No grades yet" is null, never 0,
// following rateBetween's convention: an empty GPA is unknown, not zero.

// Whether a course counts towards a GPA: a letter grade, and not switched off
// (service learning, a course taken pass/fail)
bool countsInGpa(Course c) => c.countsInGpa && isLetterGrade(c.grade) && c.credits > 0;

// Credit-weighted GPA of [courses]; F and X count, at zero, in the denominator
double? gpaOf(Iterable<Course> courses) {
  var points = 0.0;
  var credits = 0.0;
  for (final c in courses.where(countsInGpa)) {
    points += kGradePoints[c.grade]! * c.credits;
    credits += c.credits;
  }
  if (credits == 0) return null;
  // Two decimals, as the transcript prints it
  return (points / credits * 100).round() / 100;
}

double? semesterGpa(List<Course> courses, String semester) =>
    gpaOf(courses.where((c) => c.semester == semester));

double? cumulativeGpa(List<Course> courses) => gpaOf(courses);

// Credits actually earned: passed courses only
double earnedCredits(List<Course> courses, DegreeLevel level) => courses
    .where((c) => c.grade != null && isPassing(c.grade!, level))
    .fold(0.0, (sum, c) => sum + c.credits);

// Every semester with at least one graded course, oldest first, with its GPA —
// the trend line
List<(String semester, double gpa)> gpaBySemester(List<Course> courses) {
  final semesters = {for (final c in courses) if (countsInGpa(c)) c.semester}.toList()..sort();
  return [
    for (final s in semesters) (s, semesterGpa(courses, s)!),
  ];
}

// What the ungraded courses must average for the cumulative GPA to reach
// [target]. Ungraded means no grade yet and counting towards the GPA
sealed class TargetOutcome {
  const TargetOutcome();
}

// Already there even if every remaining course is an F
class TargetAlreadyMet extends TargetOutcome {
  const TargetAlreadyMet();
}

class TargetNeeds extends TargetOutcome {
  final double average;
  final double credits;
  const TargetNeeds(this.average, this.credits);
}

// Out of reach: the best possible, all A+, is [best]
class TargetOutOfReach extends TargetOutcome {
  final double best;
  final double credits;
  const TargetOutOfReach(this.best, this.credits);
}

// Nothing left ungraded to move the number
class TargetNoCourses extends TargetOutcome {
  const TargetNoCourses();
}

TargetOutcome requiredAverage(double target, List<Course> courses) {
  final pending = courses.where((c) => c.grade == null && c.countsInGpa && c.credits > 0);
  final pendingCredits = pending.fold(0.0, (sum, c) => sum + c.credits);
  if (pendingCredits == 0) return const TargetNoCourses();

  var points = 0.0;
  var credits = 0.0;
  for (final c in courses.where(countsInGpa)) {
    points += kGradePoints[c.grade]! * c.credits;
    credits += c.credits;
  }
  final total = credits + pendingCredits;
  final needed = (target * total - points) / pendingCredits;
  if (needed <= 0) return const TargetAlreadyMet();
  if (needed > 4.3) {
    final best = ((points + 4.3 * pendingCredits) / total * 100).floor() / 100;
    return TargetOutOfReach(best, pendingCredits);
  }
  // Up to the next hundredth: "3.87" must be enough, not a hair short
  return TargetNeeds((needed * 100).ceil() / 100, pendingCredits);
}
