import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';

// One course as its school lists it (course_catalog, D29), filled once a
// semester by scripts/catalog/fetch_catalog.py. Read-only, and readable
// without an account, so a guest can search too
class CatalogCourse {
  final String id;
  final String school;
  final String semester;
  final String? serialNo;
  final String? courseCode;
  final String title;
  final String? teacher;
  final double? credits;
  final String? required;
  // The school's own wording ("三6,7 (基醫508)", "BMES醫環618 W2W3W4"), shown
  // as is; the meetings themselves come ready in [sessions]
  final String? timeText;
  final List<CourseSession> sessions;
  // The departments, as the school names them, it is compulsory for; and
  // 'general' / 'excluded' when the school marks it so (credits by category)
  final List<String> requiredFor;
  final String? kind;

  const CatalogCourse({
    required this.id,
    required this.school,
    required this.semester,
    this.serialNo,
    this.courseCode,
    required this.title,
    this.teacher,
    this.credits,
    this.required,
    this.timeText,
    this.sessions = const [],
    this.requiredFor = const [],
    this.kind,
  });

  factory CatalogCourse.fromJson(Map<String, dynamic> j) => CatalogCourse(
        id: j['id'] as String,
        school: j['school'] as String,
        semester: j['semester'] as String,
        serialNo: j['serial_no'] as String?,
        courseCode: j['course_code'] as String?,
        title: j['title'] as String,
        teacher: j['teacher'] as String?,
        credits: (j['credits'] as num?)?.toDouble(),
        required: j['required'] as String?,
        timeText: j['time_text'] as String?,
        sessions: [
          for (final s in (j['sessions'] as List<dynamic>? ?? const []))
            CourseSession.fromJson(s as Map<String, dynamic>),
        ],
        requiredFor: [for (final a in (j['required_for'] as List<dynamic>? ?? const [])) a as String],
        kind: j['kind'] as String?,
      );
}

// A school whose catalog can be searched, and for which semesters
// (catalog_schools, D32). The script adds the row, so a new school shows up
// without a new build of the app
class CatalogSchool {
  final String code;
  // As the profile stores it (taiwan_universities.dart), to put the user's
  // own school first
  final String name;
  final String shortName;
  final List<String> semesters;
  // Every department name the catalog files required courses under, for the
  // user to pick their own from
  final List<String> audiences;

  const CatalogSchool({
    required this.code,
    required this.name,
    required this.shortName,
    this.semesters = const [],
    this.audiences = const [],
  });

  factory CatalogSchool.fromJson(Map<String, dynamic> j) => CatalogSchool(
        code: j['code'] as String,
        name: j['name'] as String,
        shortName: j['short_name'] as String,
        semesters: [for (final s in (j['semesters'] as List<dynamic>? ?? const [])) s as String],
        audiences: [for (final a in (j['audiences'] as List<dynamic>? ?? const [])) a as String],
      );
}

// One department's credits to graduate for one entry year (D33), as the
// school publishes them
class DegreeRequirement {
  final String department;
  final int required;
  final int general;
  final int elective;
  final int total;

  const DegreeRequirement({
    required this.department,
    required this.required,
    required this.general,
    required this.elective,
    required this.total,
  });

  factory DegreeRequirement.fromJson(Map<String, dynamic> j) => DegreeRequirement(
        department: j['department'] as String,
        required: (j['required'] as num).toInt(),
        general: (j['general'] as num).toInt(),
        elective: (j['elective'] as num).toInt(),
        total: (j['total'] as num).toInt(),
      );
}

// Where the schools and search results come from. An interface so widget
// tests, which never reach Supabase, can hand in their own
abstract class CatalogSource {
  Future<List<CatalogSchool>> schools();
  Future<List<CatalogCourse>> search(String school, String semester, String query);
  // Catalog rows by id, for filing courses added before credits by category
  Future<List<CatalogCourse>> byIds(List<String> ids);
  // Every department's requirements at a school for an entry year
  Future<List<DegreeRequirement>> requirements(String school, int entryYear);
}

class SupabaseCatalogSource implements CatalogSource {
  static const limit = 40;

  @override
  Future<List<CatalogSchool>> schools() async {
    final rows = await Supabase.instance.client.from('catalog_schools').select().order('code');
    return [for (final r in rows as List<dynamic>) CatalogSchool.fromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<List<CatalogCourse>> search(String school, String semester, String query) async {
    // PostgREST's or=() filter is comma- and parenthesis-delimited, so those
    // cannot come from the user; neither can the wildcard characters
    final q = query.replaceAll(RegExp(r'[,()*%\\]'), ' ').trim();
    if (q.isEmpty) return const [];
    final rows = await Supabase.instance.client
        .from('course_catalog')
        .select()
        .eq('school', school)
        .eq('semester', semester)
        .or('title.ilike.*$q*,teacher.ilike.*$q*,course_code.ilike.*$q*,serial_no.eq.$q')
        .order('title')
        .limit(limit);
    return [for (final r in rows as List<dynamic>) CatalogCourse.fromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<List<CatalogCourse>> byIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await Supabase.instance.client.from('course_catalog').select().inFilter('id', ids);
    return [for (final r in rows as List<dynamic>) CatalogCourse.fromJson(r as Map<String, dynamic>)];
  }

  @override
  Future<List<DegreeRequirement>> requirements(String school, int entryYear) async {
    final rows = await Supabase.instance.client
        .from('degree_requirements')
        .select()
        .eq('school', school)
        .eq('entry_year', entryYear)
        .order('department');
    return [for (final r in rows as List<dynamic>) DegreeRequirement.fromJson(r as Map<String, dynamic>)];
  }
}

final catalogSourceProvider = Provider<CatalogSource>((ref) => SupabaseCatalogSource());

// Fetched once per launch: the list changes a few times a year
final catalogSchoolsProvider = FutureProvider<List<CatalogSchool>>(
  (ref) => ref.watch(catalogSourceProvider).schools(),
);

final catalogSearchProvider = FutureProvider.autoDispose
    .family<List<CatalogCourse>, ({String school, String semester, String query})>(
  (ref, args) => ref.watch(catalogSourceProvider).search(args.school, args.semester, args.query),
);

final degreeRequirementsProvider = FutureProvider.autoDispose
    .family<List<DegreeRequirement>, ({String school, int entryYear})>(
  (ref, args) => ref.watch(catalogSourceProvider).requirements(args.school, args.entryYear),
);
