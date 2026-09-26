// NTU's grading (system_design.md §3-T), from the registrar's two tables:
// 〈等第制成績定義與等第績分表〉 and 〈等第績分平均(GPA)單向轉換為百分制成績對照表〉.
// Other schools can differ; the app says so where it shows a GPA.

// Grade points for every letter grade. X is "absent from the final" and counts
// like an F
const kGradePoints = <String, double>{
  'A+': 4.3, 'A': 4.0, 'A-': 3.7,
  'B+': 3.3, 'B': 3.0, 'B-': 2.7,
  'C+': 2.3, 'C': 2.0, 'C-': 1.7,
  'F': 0, 'X': 0,
};

// Grades outside the letter scale: never in a GPA
const kGradePass = 'pass';
const kGradeFail = 'fail';
const kGradeWithdrawn = 'withdrawn';
const kGradeMarkers = [kGradePass, kGradeFail, kGradeWithdrawn];

enum DegreeLevel { bachelor, graduate }

DegreeLevel degreeLevelFromName(String? name) =>
    DegreeLevel.values.where((d) => d.name == name).firstOrNull ?? DegreeLevel.bachelor;

bool isLetterGrade(String? grade) => kGradePoints.containsKey(grade);

// Whether a course earns its credits: C- or better for undergraduates, B- or
// better for graduate students (the registrar's note under the table); "pass"
// always; fail and withdrawn never
bool isPassing(String grade, DegreeLevel level) {
  if (grade == kGradePass) return true;
  final points = kGradePoints[grade];
  if (points == null) return false;
  return points >= (level == DegreeLevel.graduate ? 2.7 : 1.7);
}

// The registrar's GPA → percentage table is straight lines between these
// points, each value rounded half-up to two decimals. Below 1.70 it has no
// entries, and neither does this
const _percentAnchors = <(int gpaHundredths, int percent)>[
  (430, 100), (400, 89), (370, 84), (330, 79), (300, 76),
  (270, 72), (230, 69), (200, 66), (170, 60),
];

double? gpaToPercent(double gpa) {
  // Hundredths as an integer, so 3.69 is exactly 369 and the rounding below
  // matches the printed table rather than floating-point noise
  final g = (gpa * 100).round();
  if (g > 430 || g < 170) return null;
  for (var i = 0; i < _percentAnchors.length - 1; i++) {
    final (hiG, hiP) = _percentAnchors[i];
    final (loG, loP) = _percentAnchors[i + 1];
    if (g > hiG || g < loG) continue;
    // loP + (g - loG) · (hiP - loP) / (hiG - loG), in hundredths of a point,
    // rounded half up
    final num = (g - loG) * (hiP - loP) * 100;
    final den = hiG - loG;
    return (loP * 100 + (2 * num + den) ~/ (2 * den)) / 100;
  }
  return null;
}
