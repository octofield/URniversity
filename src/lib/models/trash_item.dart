import 'task.dart';
import 'semester_goal.dart';
import 'future_goal.dart';

enum TrashItemType { task, semesterGoal, futureGoal }

class TrashItem {
  final String id;
  final DateTime deletedAt;
  final Task? task;
  final SemesterGoal? semesterGoal;
  final FutureGoal? futureGoal;

  TrashItem.fromTask(Task t)
      : id = 'trash_${t.id}_${DateTime.now().millisecondsSinceEpoch}',
        deletedAt = DateTime.now(),
        task = t,
        semesterGoal = null,
        futureGoal = null;

  TrashItem.fromSemesterGoal(SemesterGoal g)
      : id = 'trash_${g.id}_${DateTime.now().millisecondsSinceEpoch}',
        deletedAt = DateTime.now(),
        task = null,
        semesterGoal = g,
        futureGoal = null;

  TrashItem.fromFutureGoal(FutureGoal g)
      : id = 'trash_${g.id}_${DateTime.now().millisecondsSinceEpoch}',
        deletedAt = DateTime.now(),
        task = null,
        semesterGoal = null,
        futureGoal = g;

  TrashItemType get type {
    if (task != null) return TrashItemType.task;
    if (semesterGoal != null) return TrashItemType.semesterGoal;
    return TrashItemType.futureGoal;
  }

  String get title {
    return task?.title ?? semesterGoal?.title ?? futureGoal?.title ?? '';
  }
}
