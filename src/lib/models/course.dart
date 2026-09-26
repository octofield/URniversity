// A course taken in one semester (data_dictionary.md D27). Its weekly meetings
// travel inside the same row (a jsonb array), so a course and its times are
// one write: two rows written in the background could land in either order,
// and a meeting arriving before its course would be rejected. Grade and the
// GPA switch belong to Phase 6.
class Course {
  final String id;
  // "115-1", the same tokens as semester goals
  final String semester;
  final String title;
  final String? teacher;
  final String? courseCode;
  final String? serialNo;
  final double credits;
  // A letter grade ("A+"), a pass/fail/withdrawn marker, or null before one
  // is known (core/grade_scale.dart)
  final String? grade;
  final bool countsInGpa;
  // ARGB
  final int color;
  // The catalog row it was added from, if any. Not a foreign key: the catalog
  // is reloaded every semester
  final String? catalogId;
  final List<CourseSession> sessions;
  final DateTime createdAt;

  const Course({
    required this.id,
    required this.semester,
    required this.title,
    this.teacher,
    this.courseCode,
    this.serialNo,
    this.credits = 0,
    this.grade,
    this.countsInGpa = true,
    required this.color,
    this.catalogId,
    this.sessions = const [],
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        semester: j['semester'] as String,
        title: j['title'] as String,
        teacher: j['teacher'] as String?,
        courseCode: j['course_code'] as String?,
        serialNo: j['serial_no'] as String?,
        credits: (j['credits'] as num?)?.toDouble() ?? 0,
        grade: j['grade'] as String?,
        countsInGpa: j['counts_in_gpa'] as bool? ?? true,
        color: (j['color'] as num?)?.toInt() ?? 0xFF4A90C4,
        catalogId: j['catalog_id'] as String?,
        sessions: [
          for (final s in (j['sessions'] as List<dynamic>? ?? const []))
            CourseSession.fromJson((s as Map).cast<String, dynamic>()),
        ],
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'semester': semester,
        'title': title,
        'teacher': teacher,
        'course_code': courseCode,
        'serial_no': serialNo,
        'credits': credits,
        'grade': grade,
        'counts_in_gpa': countsInGpa,
        'color': color,
        'catalog_id': catalogId,
        'sessions': [for (final s in sessions) s.toJson()],
        'created_at': createdAt.toIso8601String(),
      };

  // Fields that can be cleared take a function, so "set to null" and "leave
  // alone" are different calls
  Course copyWith({
    String? title,
    String? Function()? teacher,
    double? credits,
    String? Function()? grade,
    bool? countsInGpa,
    int? color,
    String? semester,
    List<CourseSession>? sessions,
  }) =>
      Course(
        id: id,
        semester: semester ?? this.semester,
        title: title ?? this.title,
        teacher: teacher != null ? teacher() : this.teacher,
        courseCode: courseCode,
        serialNo: serialNo,
        credits: credits ?? this.credits,
        grade: grade != null ? grade() : this.grade,
        countsInGpa: countsInGpa ?? this.countsInGpa,
        color: color ?? this.color,
        catalogId: catalogId,
        sessions: sessions ?? this.sessions,
        createdAt: createdAt,
      );
}

// One weekly meeting of a course
class CourseSession {
  // DateTime.monday (1) … DateTime.sunday (7)
  final int weekday;
  // Minutes since midnight; end is after start
  final int startMinute;
  final int endMinute;
  final String? location;

  const CourseSession({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
    this.location,
  });

  factory CourseSession.fromJson(Map<String, dynamic> j) => CourseSession(
        weekday: (j['weekday'] as num).toInt(),
        startMinute: (j['start_minute'] as num).toInt(),
        endMinute: (j['end_minute'] as num).toInt(),
        location: j['location'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start_minute': startMinute,
        'end_minute': endMinute,
        'location': location,
      };
}
