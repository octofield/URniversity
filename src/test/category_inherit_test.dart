import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';

import 'helpers/pump_app.dart';

// Linking a target to a vision hands the vision's categories to a target that
// has none of its own (system_design.md UC4), and never overwrites ones the
// user already picked
void main() {
  setUp(() => setUpTestSupabase());

  test('an uncategorised target takes the linked vision categories', () {
    final c = testContainer();
    c.read(futureGoalsProvider.notifier).addGoal(
      title: 'Exchange',
      categories: const [FutureCategories.exchange],
    );
    final visionId = c.read(futureGoalsProvider).single.id;
    final targetId =
        c.read(semesterGoalsProvider.notifier).addGoal('TOEFL', '115-1');

    c.read(semesterGoalsProvider.notifier).linkFutureGoal(targetId, visionId);

    final target = c.read(semesterGoalsProvider).single;
    expect(target.futureGoalId, visionId);
    expect(target.categories, [FutureCategories.exchange]);
  });

  test('a target with its own categories keeps them', () {
    final c = testContainer();
    c.read(futureGoalsProvider.notifier).addGoal(
      title: 'Exchange',
      categories: const [FutureCategories.exchange],
    );
    final visionId = c.read(futureGoalsProvider).single.id;
    final targetId = c.read(semesterGoalsProvider.notifier).addGoal(
      'TOEFL',
      '115-1',
      categories: const [FutureCategories.certification],
    );

    c.read(semesterGoalsProvider.notifier).linkFutureGoal(targetId, visionId);

    expect(c.read(semesterGoalsProvider).single.categories,
        [FutureCategories.certification]);
  });

  test('unlinking leaves the categories alone', () {
    final c = testContainer();
    c.read(futureGoalsProvider.notifier).addGoal(
      title: 'Exchange',
      categories: const [FutureCategories.exchange],
    );
    final visionId = c.read(futureGoalsProvider).single.id;
    final notifier = c.read(semesterGoalsProvider.notifier);
    final targetId = notifier.addGoal('TOEFL', '115-1');
    notifier.linkFutureGoal(targetId, visionId);

    notifier.linkFutureGoal(targetId, null);

    final target = c.read(semesterGoalsProvider).single;
    expect(target.futureGoalId, isNull);
    expect(target.categories, [FutureCategories.exchange]);
  });
}
