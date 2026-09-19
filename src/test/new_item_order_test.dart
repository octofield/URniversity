import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/widgets/drag_reorder.dart';

import 'helpers/pump_app.dart';

// New items land on top of their own group (system_design.md §3-C), and a
// row the user dragged keeps its place however many are added after it.
void main() {
  setUp(() => setUpTestSupabase());

  group('tasks', () {
    test('the newest task is listed first', () {
      final c = testContainer();
      c.read(taskViewProvider.notifier).state = 0;
      final tasks = c.read(tasksProvider.notifier);
      tasks.add('first');
      tasks.add('second');
      tasks.add('third');

      expect(c.read(filteredTasksProvider).map((t) => t.title), ['third', 'second', 'first']);
    });

    test('a dragged task keeps its place when more are added', () {
      final c = testContainer();
      c.read(taskViewProvider.notifier).state = 0;
      final tasks = c.read(tasksProvider.notifier);
      tasks.add('a');
      tasks.add('b');
      tasks.add('c');
      // Listed c, b, a; drag a in between c and b
      Iterable<int> orderOf(String title) =>
          c.read(tasksProvider).where((t) => t.title == title).map((t) => t.sortOrder);
      final a = c.read(tasksProvider).firstWhere((t) => t.title == 'a');
      tasks.reorderTask(a.id, orderBetween(orderOf('c').single, orderOf('b').single));

      tasks.add('d');

      expect(c.read(filteredTasksProvider).map((t) => t.title), ['d', 'c', 'a', 'b']);
    });

    test('the very first task starts from nothing', () {
      final c = testContainer();
      c.read(tasksProvider.notifier).add('first ever');
      expect(c.read(tasksProvider).single.sortOrder, -1000);
    });
  });

  test('a new semester goal goes on top of its own semester only', () {
    final c = testContainer();
    final goals = c.read(semesterGoalsProvider.notifier);
    goals.addGoal('older', '115-1');
    goals.addGoal('newer', '115-1');
    goals.addGoal('other semester', '115-2');

    int orderOf(String title) =>
        c.read(semesterGoalsProvider).firstWhere((g) => g.title == title).sortOrder;
    expect(orderOf('newer'), lessThan(orderOf('older')));
    expect(orderOf('other semester'), -1000);
  });

  test('a new vision goes on top of its siblings', () {
    final c = testContainer();
    final goals = c.read(futureGoalsProvider.notifier);
    goals.addGoal(title: 'older');
    goals.addGoal(title: 'newer');
    final older = c.read(futureGoalsProvider).firstWhere((g) => g.title == 'older');
    goals.addGoal(title: 'child', parentId: older.id);

    int orderOf(String title) =>
        c.read(futureGoalsProvider).firstWhere((g) => g.title == title).sortOrder;
    expect(orderOf('newer'), lessThan(orderOf('older')));
    expect(orderOf('child'), -1000);
  });
}
