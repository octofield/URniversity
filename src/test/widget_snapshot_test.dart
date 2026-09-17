import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/widget_snapshot.dart';
import 'package:urniversity/l10n/strings_en.dart';
import 'package:urniversity/models/category.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/utils/category_helpers.dart';

// buildWidgetSnapshot decides everything the home screen widget can show. Every
// view is computed up front so the native side switches instantly, which makes
// this the whole feature's logic and none of it needs a device.
void main() {
  const s = StringsEn();
  const semSettings = SemesterSettings(count: 2, startMonths: [8, 2]);
  // A Monday
  final now = DateTime(2026, 9, 14, 10, 0);

  final categories = [
    CategoryEntry(
      id: 'exchange',
      color: defaultCatColor('exchange'),
      icon: defaultCatIcon('exchange'),
    ),
  ];

  Task task({
    String id = 't1',
    String title = 'Task',
    DateTime? dueTime,
    bool isCompleted = false,
    RecurrenceRule? recurrence,
    String? parentTaskId,
    String? linkedTargetId,
    String? linkedGoalId,
    List<String> completedDates = const [],
    int sortOrder = 0,
  }) =>
      Task(
        id: id,
        title: title,
        dueTime: dueTime,
        isCompleted: isCompleted,
        recurrence: recurrence,
        parentTaskId: parentTaskId,
        linkedTargetId: linkedTargetId,
        linkedGoalId: linkedGoalId,
        completedDates: completedDates,
        sortOrder: sortOrder,
        createdAt: DateTime(2026, 9, 1),
      );

  SemesterGoal target({
    String id = 'g1',
    String title = 'Target',
    String semester = '115-1',
    String? parentId,
    bool isDone = false,
  }) =>
      SemesterGoal(
        id: id,
        title: title,
        semester: semester,
        parentId: parentId,
        isDone: isDone,
        categories: const ['exchange'],
      );

  FutureGoal vision({
    String id = 'v1',
    String title = 'Vision',
    String? parentId,
    bool isDone = false,
  }) =>
      FutureGoal(
        id: id,
        title: title,
        parentId: parentId,
        isDone: isDone,
        categories: const ['exchange'],
      );

  WidgetSnapshot build({
    List<Task> tasks = const [],
    List<SemesterGoal> semesterGoals = const [],
    List<FutureGoal> futureGoals = const [],
    DateTime? at,
  }) =>
      buildWidgetSnapshot(
        tasks: tasks,
        semesterGoals: semesterGoals,
        futureGoals: futureGoals,
        categories: categories,
        semesterSettings: semSettings,
        s: s,
        now: at ?? now,
      );

  List<WidgetRow> view(WidgetSnapshot snapshot, WidgetMode mode,
          [WidgetPeriod period = WidgetPeriod.day]) =>
      snapshot.views[WidgetSnapshot.viewKey(mode, period)]!;

  test('every view is present, so the native side never waits for Dart', () {
    final keys = build().views.keys.toSet();
    expect(keys, {
      'tasks_all',
      'tasks_day',
      'tasks_week',
      'tasks_month',
      'targets',
      'goals',
      'filter_picker',
    });
  });

  group('the all-tasks view', () {
    test('lists a task that has no due time and no recurrence at all', () {
      // Every other period is built by walking days, so a task that never lands
      // on one can only appear here
      final snapshot = build(tasks: [task()]);
      expect(view(snapshot, WidgetMode.tasks, WidgetPeriod.all), hasLength(1));
      expect(view(snapshot, WidgetMode.tasks), isEmpty);
      expect(view(snapshot, WidgetMode.tasks, WidgetPeriod.month), isEmpty);
    });

    test('a dateless task already ticked off is not listed', () {
      // A task with no recurrence carries one flag, not a list of days
      final rows = view(
        build(tasks: [task(isCompleted: true)]),
        WidgetMode.tasks,
        WidgetPeriod.all,
      );
      expect(rows, isEmpty);
    });

    test('dated tasks come first, dateless ones after', () {
      final rows = view(
        build(tasks: [
          task(id: 'none', title: 'Someday'),
          task(id: 'dated', title: 'Friday', dueTime: DateTime(2026, 9, 18, 9, 0)),
        ]),
        WidgetMode.tasks,
        WidgetPeriod.all,
      );
      expect(rows.map((r) => r.title), ['Friday', 'Someday']);
    });

    test('a dateless row has no subtitle and ticks off against today', () {
      final row = view(build(tasks: [task()]), WidgetMode.tasks, WidgetPeriod.all).single;
      expect(row.subtitle, isNull);
      expect(row.checkAction, contains('date=2026-09-14'));
    });

    test('reaches further out than a month', () {
      final rows = view(
        build(tasks: [task(dueTime: DateTime(2026, 12, 24, 9, 0))]),
        WidgetMode.tasks,
        WidgetPeriod.all,
      );
      expect(rows, hasLength(1));
    });
  });

  group('task views', () {
    test('show a task due today', () {
      final rows = view(
          build(tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))]), WidgetMode.tasks);
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Task');
      expect(rows.single.check, WidgetCheck.unchecked);
    });

    test('a completed task is gone', () {
      final rows = view(
          build(tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0), isCompleted: true)]),
          WidgetMode.tasks);
      expect(rows, isEmpty);
    });

    test('a subtask does not get its own row', () {
      final rows = view(
          build(tasks: [
            task(id: 'p', dueTime: DateTime(2026, 9, 14, 9, 0)),
            task(id: 'c', parentTaskId: 'p', dueTime: DateTime(2026, 9, 14, 9, 0)),
          ]),
          WidgetMode.tasks);
      expect(rows, hasLength(1));
    });

    test('the three periods are computed together and do not bleed', () {
      final snapshot = build(tasks: [
        task(id: 'today', dueTime: DateTime(2026, 9, 14, 9, 0)),
        task(id: 'sunday', dueTime: DateTime(2026, 9, 20, 9, 0)),
        // Day eight: outside the week, inside the month
        task(id: 'next-monday', dueTime: DateTime(2026, 9, 21, 9, 0)),
        task(id: 'october', dueTime: DateTime(2026, 10, 1, 9, 0)),
      ]);
      expect(view(snapshot, WidgetMode.tasks, WidgetPeriod.day), hasLength(1));
      expect(view(snapshot, WidgetMode.tasks, WidgetPeriod.week), hasLength(2));
      expect(view(snapshot, WidgetMode.tasks, WidgetPeriod.month), hasLength(3));
    });

    test('a recurring task takes one row, not one per day', () {
      final rows = view(
          build(tasks: [
            task(
              dueTime: DateTime(2026, 9, 1, 21, 0),
              recurrence: const RecurrenceRule(type: RecurrenceType.daily),
            ),
          ]),
          WidgetMode.tasks,
          WidgetPeriod.month);
      expect(rows, hasLength(1));
    });

    test('a recurring task points at its soonest outstanding day', () {
      final rows = view(
          build(tasks: [
            task(
              dueTime: DateTime(2026, 9, 1, 21, 0),
              recurrence: const RecurrenceRule(type: RecurrenceType.daily),
              completedDates: const ['2026-09-14', '2026-09-15'],
            ),
          ]),
          WidgetMode.tasks,
          WidgetPeriod.week);
      expect(rows.single.subtitle, contains('9/16'));
    });

    test("today's row does not repeat the date", () {
      final rows = view(
          build(tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))]), WidgetMode.tasks);
      expect(rows.single.subtitle, '15:00');
    });

    test('nothing to say is null, not an empty string', () {
      // The native side hides a null subtitle so the title centres; anything
      // else would leave an empty line or print "null"
      final rows = view(
          build(tasks: [
            task(recurrence: const RecurrenceRule(type: RecurrenceType.daily)),
          ]),
          WidgetMode.tasks);
      expect(rows.single.subtitle, isNull);
      expect(rows.single.toJson()['subtitle'], isNull);
    });

    test('rows are ordered by the day they are due', () {
      final rows = view(
          build(tasks: [
            task(id: 'late', title: 'Late', dueTime: DateTime(2026, 9, 18, 9, 0)),
            task(id: 'soon', title: 'Soon', dueTime: DateTime(2026, 9, 15, 9, 0)),
          ]),
          WidgetMode.tasks,
          WidgetPeriod.week);
      expect(rows.map((r) => r.title), ['Soon', 'Late']);
    });
  });

  group('filter keys on task rows', () {
    test('a task counts under the target it links to', () {
      final rows = view(
          build(
            tasks: [task(dueTime: DateTime(2026, 9, 14, 9, 0), linkedTargetId: 'g1')],
            semesterGoals: [target()],
          ),
          WidgetMode.tasks);
      expect(rows.single.filters, ['g1']);
    });

    test('a task under a milestone also counts under every ancestor', () {
      final rows = view(
          build(
            tasks: [task(dueTime: DateTime(2026, 9, 14, 9, 0), linkedTargetId: 'grandchild')],
            semesterGoals: [
              target(),
              target(id: 'child', parentId: 'g1'),
              target(id: 'grandchild', parentId: 'child'),
            ],
          ),
          WidgetMode.tasks);
      // Picking the top target must still catch this task, or the filter
      // silently hides the work done under its milestones
      expect(rows.single.filters, containsAll(['grandchild', 'child', 'g1']));
    });

    test('vision links are included the same way', () {
      final rows = view(
          build(
            tasks: [task(dueTime: DateTime(2026, 9, 14, 9, 0), linkedGoalId: 'sub')],
            futureGoals: [vision(), vision(id: 'sub', parentId: 'v1')],
          ),
          WidgetMode.tasks);
      expect(rows.single.filters, containsAll(['sub', 'v1']));
    });

    test('an unlinked task counts under nothing', () {
      final rows = view(
          build(tasks: [task(dueTime: DateTime(2026, 9, 14, 9, 0))]), WidgetMode.tasks);
      expect(rows.single.filters, isEmpty);
    });

    test('a parent loop does not hang', () {
      final rows = view(
          build(
            tasks: [task(dueTime: DateTime(2026, 9, 14, 9, 0), linkedTargetId: 'a')],
            semesterGoals: [target(id: 'a', parentId: 'b'), target(id: 'b', parentId: 'a')],
          ),
          WidgetMode.tasks);
      expect(rows.single.filters, containsAll(['a', 'b']));
    });

    test('the filter button can name any target or vision', () {
      final snapshot = build(
        semesterGoals: [target(title: 'Exchange programme')],
        futureGoals: [vision(title: 'Work abroad')],
      );
      expect(snapshot.filterLabels['g1'], 'Exchange programme');
      expect(snapshot.filterLabels['v1'], 'Work abroad');
      expect(snapshot.filterDefaultLabel, s.filters);
    });
  });

  group('target and vision views', () {
    test('only top-level items are listed', () {
      final rows = view(
          build(semesterGoals: [target(), target(id: 'child', parentId: 'g1')]),
          WidgetMode.targets);
      expect(rows, hasLength(1));
    });

    test('the subtitle carries the progress of the direct children', () {
      final rows = view(
          build(semesterGoals: [
            target(),
            target(id: 'c1', parentId: 'g1', isDone: true),
            target(id: 'c2', parentId: 'g1'),
          ]),
          WidgetMode.targets);
      expect(rows.single.subtitle, contains(s.goalProgress(1, 2)));
    });

    test('tapping a target opens it rather than ticking it', () {
      final rows = view(build(semesterGoals: [target()]), WidgetMode.targets);
      expect(rows.single.tapAction, contains('kind=semesterGoal'));
      expect(rows.single.checkAction, isNull);
    });

    test('a vision without children has no subtitle', () {
      final rows = view(build(futureGoals: [vision()]), WidgetMode.goals);
      expect(rows.single.subtitle, isNull);
      expect(rows.single.tapAction, contains('kind=futureGoal'));
    });
  });

  group('the filter picker', () {
    test('clearing the filter is always the first row', () {
      final rows = view(build(semesterGoals: [target()]), WidgetMode.filterPicker);
      expect(rows.first.tapAction, contains('kind=none'));
    });

    test('targets are grouped under a semester header', () {
      final rows = view(build(semesterGoals: [target()]), WidgetMode.filterPicker);
      final header = rows.firstWhere((r) => r.isHeader);
      expect(header.title, contains('115'));
      // A header is a label, not a choice
      expect(header.tapAction, isNull);
    });

    test('a finished semester is left out', () {
      final rows = view(
          // 114-1 ended before 114-2 began, i.e. 2026-01-31
          build(semesterGoals: [target(id: 'old', semester: '114-1')]),
          WidgetMode.filterPicker);
      expect(rows.where((r) => r.isHeader), isEmpty);
      expect(rows, hasLength(1), reason: 'only the clear row remains');
    });

    test('visions get their own section and are not grouped by semester', () {
      final rows = view(build(futureGoals: [vision()]), WidgetMode.filterPicker);
      final headers = rows.where((r) => r.isHeader).toList();
      expect(headers, hasLength(1));
      expect(headers.single.title, s.goals);
    });

    test('picking a target produces a filter action carrying its id', () {
      final rows = view(build(semesterGoals: [target()]), WidgetMode.filterPicker);
      final choice = rows.firstWhere((r) => r.title == 'Target');
      expect(choice.tapAction, contains('kind=target'));
      expect(choice.tapAction, contains('id=g1'));
    });
  });

  test('the snapshot serialises every view for the native side', () {
    final json = build(tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))]).toJson();
    final views = json['views'] as Map<String, dynamic>;
    expect((views['tasks_day'] as List).single, containsPair('title', 'Task'));
    expect(json['empty'], containsPair('tasks', s.noTasks));
  });
}
