import 'course.dart';
import 'task.dart';
import 'semester_goal.dart';
import 'future_goal.dart';

enum TrashItemType { task, semesterGoal, futureGoal, course }

class TrashItem {
  final String id;
  final DateTime deletedAt;
  final Task? task;
  final SemesterGoal? semesterGoal;
  final FutureGoal? futureGoal;
  // With its meetings, which live in the same row
  final Course? course;

  TrashItem._({
    required this.id,
    required this.deletedAt,
    this.task,
    this.semesterGoal,
    this.futureGoal,
    this.course,
  });

  TrashItem.fromTask(Task t)
      : id = 'trash_${t.id}_${DateTime.now().millisecondsSinceEpoch}',
        deletedAt = DateTime.now(),
        task = t,
        semesterGoal = null,
        futureGoal = null,
        course = null;

  TrashItem.fromSemesterGoal(SemesterGoal g)
      : id = 'trash_${g.id}_${DateTime.now().millisecondsSinceEpoch}',
        deletedAt = DateTime.now(),
        task = null,
        semesterGoal = g,
        futureGoal = null,
        course = null;

  TrashItem.fromFutureGoal(FutureGoal g)
      : id = 'trash_${g.id}_${DateTime.now().millisecondsSinceEpoch}',
        deletedAt = DateTime.now(),
        task = null,
        semesterGoal = null,
        futureGoal = g,
        course = null;

  TrashItem.fromCourse(Course c)
      : id = 'trash_${c.id}_${DateTime.now().millisecondsSinceEpoch}',
        deletedAt = DateTime.now(),
        task = null,
        semesterGoal = null,
        futureGoal = null,
        course = c;

  factory TrashItem.fromRow(Map<String, dynamic> row) {
    final itemType = row['item_type'] as String;
    final data = row['item_data'] as Map<String, dynamic>;
    return TrashItem._(
      id: row['id'] as String,
      deletedAt: DateTime.parse(row['deleted_at'] as String),
      task: itemType == 'task' ? Task.fromJson(data) : null,
      semesterGoal: itemType == 'semester_goal' ? SemesterGoal.fromJson(data) : null,
      futureGoal: itemType == 'future_goal' ? FutureGoal.fromJson(data) : null,
      course: itemType == 'course' ? Course.fromJson(data) : null,
    );
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'deleted_at': deletedAt.toIso8601String(),
    'item_type': switch (type) {
      TrashItemType.task => 'task',
      TrashItemType.semesterGoal => 'semester_goal',
      TrashItemType.futureGoal => 'future_goal',
      TrashItemType.course => 'course',
    },
    'item_data': switch (type) {
      TrashItemType.task => task!.toJson(),
      TrashItemType.semesterGoal => semesterGoal!.toJson(),
      TrashItemType.futureGoal => futureGoal!.toJson(),
      TrashItemType.course => course!.toJson(),
    },
  };

  TrashItemType get type {
    if (task != null) return TrashItemType.task;
    if (semesterGoal != null) return TrashItemType.semesterGoal;
    if (course != null) return TrashItemType.course;
    return TrashItemType.futureGoal;
  }

  String get title {
    return task?.title ?? semesterGoal?.title ?? futureGoal?.title ?? course?.title ?? '';
  }
}
