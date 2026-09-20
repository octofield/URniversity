import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/tasks_provider.dart';

// The task list can be ordered by something other than the drag order. Ties
// fall back to the order the list already had, so a rebuild never reshuffles
// two tasks that compare equal.
void main() {
  final base = DateTime(2026, 9, 20, 8);

  Task task(
    String id, {
    String? title,
    DateTime? created,
    DateTime? due,
    String? targetId,
    int sortOrder = 0,
  }) =>
      Task(
        id: id,
        title: title ?? id,
        createdAt: created ?? base,
        dueTime: due,
        linkedTargetId: targetId,
        sortOrder: sortOrder,
      );

  List<String> ids(List<Task> tasks) => [for (final t in tasks) t.id];

  test('the manual order is the drag order, as before', () {
    final tasks = [
      task('a', sortOrder: 0),
      task('b', sortOrder: -1000),
      task('c', sortOrder: 500),
    ];
    expect(ids(applyTaskSort(tasks, TaskSort.manual)), ['b', 'a', 'c']);
  });

  test('by date added puts the newest first', () {
    final tasks = [
      task('old', created: base.subtract(const Duration(days: 2))),
      task('new', created: base),
      task('middle', created: base.subtract(const Duration(days: 1))),
    ];
    expect(ids(applyTaskSort(tasks, TaskSort.created)), ['new', 'middle', 'old']);
  });

  test('A-Z ignores case', () {
    final tasks = [
      task('1', title: 'beta'),
      task('2', title: 'Alpha'),
      task('3', title: 'Gamma'),
    ];
    expect(ids(applyTaskSort(tasks, TaskSort.title)), ['2', '1', '3']);
  });

  test('by target groups them, with the unlinked last', () {
    final titles = {'t1': '多益 850', 't2': '交換申請'};
    final tasks = [
      task('loose'),
      task('a', targetId: 't1'),
      task('b', targetId: 't2'),
      task('c', targetId: 't1'),
    ];

    expect(
      ids(applyTaskSort(tasks, TaskSort.target, targetTitles: titles)),
      ['b', 'a', 'c', 'loose'],
    );
  });

  test('by due time puts the soonest first and the undated last', () {
    final tasks = [
      task('none'),
      task('later', due: base.add(const Duration(days: 3))),
      task('soon', due: base.add(const Duration(hours: 2))),
    ];
    expect(ids(applyTaskSort(tasks, TaskSort.due)), ['soon', 'later', 'none']);
  });

  test('a tie keeps the order the list already had', () {
    final tasks = [
      task('first', due: base, title: 'same'),
      task('second', due: base, title: 'same'),
    ];

    for (final sort in [TaskSort.due, TaskSort.title, TaskSort.created]) {
      expect(ids(applyTaskSort(tasks, sort)), ['first', 'second'],
          reason: '$sort must be stable');
    }
  });

  test('a target that no longer exists counts as unlinked', () {
    final tasks = [
      task('gone', targetId: 'deleted'),
      task('kept', targetId: 't1'),
    ];
    expect(
      ids(applyTaskSort(tasks, TaskSort.target, targetTitles: {'t1': '目標'})),
      ['kept', 'gone'],
    );
  });
}
