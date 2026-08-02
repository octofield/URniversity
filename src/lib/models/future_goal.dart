class FutureCategories {
  static const exchange = 'exchange';
  static const intern = 'intern';
  static const competition = 'competition';
  static const certification = 'certification';
  static const performance = 'performance';
  static const other = 'other';

  static const builtIns = <String>[
    exchange, intern, competition, certification, performance, other,
  ];
}

// Compare semester strings like "114-1" < "114-B1" < "114-2" < ... < "115-1".
// Regular semesters use a plain numeric index ("114-1"); breaks use "B" plus
// the index of the semester they directly follow ("114-B1" = the break right
// after semester 1). The break following the last semester ("B{count}") is
// always the long break before next year's semester 1 restarts.
int compareSemesters(String a, String b) {
  final pa = a.split('-');
  final pb = b.split('-');
  final yearDiff = int.parse(pa[0]) - int.parse(pb[0]);
  if (yearDiff != 0) return yearDiff;
  return _semesterWeight(pa[1]) - _semesterWeight(pb[1]);
}

int _semesterWeight(String token) {
  if (token.startsWith('B')) return int.parse(token.substring(1)) * 2;
  return int.parse(token) * 2 - 1;
}

bool isBreakToken(String semester) {
  final parts = semester.split('-');
  return parts.length == 2 && parts[1].startsWith('B');
}

class FutureGoal {
  final String id;
  final String? parentId;         // null = top-level goal
  final String title;
  final List<String> categories;  // multiple categories
  final String? startSemester;
  final String? endSemester;
  final String? notes;
  final bool isDone;
  final int sortOrder;

  const FutureGoal({
    required this.id,
    this.parentId,
    required this.title,
    this.categories = const [FutureCategories.other],
    this.startSemester,
    this.endSemester,
    this.notes,
    this.isDone = false,
    this.sortOrder = 0,
  });

  factory FutureGoal.fromJson(Map<String, dynamic> j) => FutureGoal(
    id: j['id'] as String,
    parentId: j['parent_id'] as String?,
    title: j['title'] as String,
    categories: (j['categories'] as List<dynamic>).cast<String>(),
    startSemester: j['start_semester'] as String?,
    endSemester: j['end_semester'] as String?,
    notes: j['notes'] as String?,
    isDone: j['is_done'] as bool? ?? false,
    sortOrder: j['sort_order'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_id': parentId,
    'title': title,
    'categories': categories,
    'start_semester': startSemester,
    'end_semester': endSemester,
    'notes': notes,
    'is_done': isDone,
    'sort_order': sortOrder,
  };

  FutureGoal copyWith({
    Object? parentId = _sentinel,
    String? title,
    List<String>? categories,
    Object? startSemester = _sentinel,
    Object? endSemester = _sentinel,
    Object? notes = _sentinel,
    bool? isDone,
    int? sortOrder,
  }) {
    return FutureGoal(
      id: id,
      parentId: parentId == _sentinel ? this.parentId : parentId as String?,
      title: title ?? this.title,
      categories: categories ?? this.categories,
      startSemester: startSemester == _sentinel ? this.startSemester : startSemester as String?,
      endSemester: endSemester == _sentinel ? this.endSemester : endSemester as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

const Object _sentinel = Object();
