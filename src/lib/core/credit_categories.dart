import '../models/course.dart';
import 'grade_scale.dart';

// Credits by category (system_design.md §3-T): where a course's credits count
// toward graduation. Opt-in, and the numbers to reach come from the school's
// published requirements where there are any (D33). Pure functions, tested on
// their own like gpa_stats.dart

enum CreditCategory { required, elective, general, excluded }

CreditCategory? creditCategoryFromName(String? name) =>
    CreditCategory.values.where((c) => c.name == name).firstOrNull;

// Where an added catalog course files for a student whose department the
// catalog calls [catalogDepartment]. The school's own marking comes first —
// general education (with the common Chinese and English), or not counted at
// all (physical education) — then compulsory for their department, and
// everything else is an elective
CreditCategory classifyCourse({
  String? kind,
  List<String> requiredFor = const [],
  String? catalogDepartment,
}) {
  if (kind == 'general') return CreditCategory.general;
  if (kind == 'excluded') return CreditCategory.excluded;
  if (catalogDepartment != null && requiredFor.contains(catalogDepartment)) return CreditCategory.required;
  return CreditCategory.elective;
}

// Passed credits in each category, the pass mark being the degree's
// (isPassing). A course not yet filed counts under null
Map<CreditCategory?, double> creditsByCategory(List<Course> courses, DegreeLevel level) {
  final out = <CreditCategory?, double>{};
  for (final c in courses) {
    if (c.grade == null || !isPassing(c.grade!, level)) continue;
    final category = creditCategoryFromName(c.category);
    out[category] = (out[category] ?? 0) + c.credits;
  }
  return out;
}

// The ROC academic year the student entered: in year 2 as of 2026 (academic
// year 115), they entered in 114. [gradeSetYear] is the Western year the
// grade was given in, as the profile stores it
int? entryYearFrom(int? grade, int? gradeSetYear) =>
    grade == null || gradeSetYear == null ? null : gradeSetYear - (grade - 1) - 1911;

// A first guess at how the catalog names the user's department — it abbreviates
// ("資訊工程學系" is "資工系") — so the list to pick from opens on a likely one.
// The name sharing the most characters wins; nothing shared, no guess
String? guessCatalogDepartment(String? department, List<String> names) {
  if (department == null || department.isEmpty) return null;
  // What every department name has, and so says nothing about which one
  const generic = {'學', '系', '所', '院', '程', '位', '士', '班'};
  final wanted = department.split('').toSet().difference(generic);
  String? best;
  var bestScore = 0;
  for (final name in names) {
    final score = name.split('').toSet().intersection(wanted).length;
    if (score > bestScore) {
      best = name;
      bestScore = score;
    }
  }
  return best;
}
