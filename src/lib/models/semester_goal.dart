import 'dart:convert';

class SemesterGoal {
  final String id;
  final String? parentId;
  final String title;
  final String semester;
  final List<String> categories;
  final String? futureGoalId;
  final String? notes;
  final bool isDone;
  final int sortOrder;

  const SemesterGoal({
    required this.id,
    this.parentId,
    required this.title,
    required this.semester,
    this.categories = const [],
    this.futureGoalId,
    this.notes,
    this.isDone = false,
    this.sortOrder = 0,
  });

  factory SemesterGoal.fromJson(Map<String, dynamic> j) {
    List<String> cats;
    final raw = j['category'] as String? ?? 'other';
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      cats = list.isEmpty ? ['other'] : list;
    } catch (_) {
      cats = [raw];
    }
    return SemesterGoal(
      id: j['id'] as String,
      parentId: j['parent_id'] as String?,
      title: j['title'] as String,
      semester: j['semester'] as String,
      categories: cats,
      futureGoalId: j['future_goal_id'] as String?,
      notes: j['notes'] as String?,
      isDone: j['is_done'] as bool? ?? false,
      sortOrder: j['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_id': parentId,
    'title': title,
    'semester': semester,
    'category': jsonEncode(categories.isEmpty ? ['other'] : categories),
    'future_goal_id': futureGoalId,
    'notes': notes,
    'is_done': isDone,
    'sort_order': sortOrder,
  };

  SemesterGoal copyWith({
    Object? parentId = _sgSentinel,
    String? title,
    String? semester,
    List<String>? categories,
    Object? futureGoalId = _sgSentinel,
    Object? notes = _sgSentinel,
    bool? isDone,
    int? sortOrder,
  }) => SemesterGoal(
    id: id,
    parentId: parentId == _sgSentinel ? this.parentId : parentId as String?,
    title: title ?? this.title,
    semester: semester ?? this.semester,
    categories: categories ?? this.categories,
    futureGoalId: futureGoalId == _sgSentinel ? this.futureGoalId : futureGoalId as String?,
    notes: notes == _sgSentinel ? this.notes : notes as String?,
    isDone: isDone ?? this.isDone,
    sortOrder: sortOrder ?? this.sortOrder,
  );
}

const Object _sgSentinel = Object();
