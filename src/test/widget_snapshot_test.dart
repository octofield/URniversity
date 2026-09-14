import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/widget_snapshot.dart';
import 'package:urniversity/l10n/strings_en.dart';
import 'package:urniversity/models/category.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/utils/category_helpers.dart';

// buildWidgetSnapshot decides everything the home screen widget shows. The
// native side only renders the rows it produces, so this is the whole feature's
// logic and none of it needs a device.
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
    WidgetState state = const WidgetState(),
    DateTime? at,
  }) =>
      buildWidgetSnapshot(
        tasks: tasks,
        semesterGoals: semesterGoals,
        futureGoals: futureGoals,
        categories: categories,
        state: state,
        semesterSettings: semSettings,
        s: s,
        now: at ?? now,
      );

  group('task mode', () {
    test('shows a task due today', () {
      final snapshot = build(tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))]);
      expect(snapshot.rows, hasLength(1));
      expect(snapshot.rows.single.title, 'Task');
      expect(snapshot.rows.single.check, WidgetCheck.unchecked);
    });

    test('a completed task is gone', () {
      final snapshot = build(
        tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0), isCompleted: true)],
      );
      expect(snapshot.rows, isEmpty);
    });

    test('a subtask does not get its own row', () {
      final snapshot = build(tasks: [
        task(id: 'p', dueTime: DateTime(2026, 9, 14, 9, 0)),
        task(id: 'c', parentTaskId: 'p', dueTime: DateTime(2026, 9, 14, 9, 0)),
      ]);
      expect(snapshot.rows, hasLength(1));
    });

    test('the day period excludes tomorrow', () {
      final snapshot = build(tasks: [
        task(id: 'a', dueTime: DateTime(2026, 9, 14, 9, 0)),
        task(id: 'b', dueTime: DateTime(2026, 9, 15, 9, 0)),
      ]);
      expect(snapshot.rows, hasLength(1));
    });

    test('the week period covers the next seven days', () {
      final snapshot = build(
        tasks: [
          task(id: 'a', dueTime: DateTime(2026, 9, 20, 9, 0)),
          // Day eight — outside
          task(id: 'b', dueTime: DateTime(2026, 9, 21, 9, 0)),
        ],
        state: const WidgetState(period: WidgetPeriod.week),
      );
      expect(snapshot.rows, hasLength(1));
    });

    test('the month period runs to the last day of this month', () {
      final snapshot = build(
        tasks: [
          task(id: 'a', dueTime: DateTime(2026, 9, 30, 9, 0)),
          task(id: 'b', dueTime: DateTime(2026, 10, 1, 9, 0)),
        ],
        state: const WidgetState(period: WidgetPeriod.month),
      );
      expect(snapshot.rows, hasLength(1));
    });

    test('a recurring task takes one row, not one per day', () {
      final snapshot = build(
        tasks: [
          task(
            dueTime: DateTime(2026, 9, 1, 21, 0),
            recurrence: const RecurrenceRule(type: RecurrenceType.daily),
          ),
        ],
        state: const WidgetState(period: WidgetPeriod.month),
      );
      // A daily task over a month would otherwise fill the list by itself
      expect(snapshot.rows, hasLength(1));
    });

    test('a recurring task points at its soonest outstanding day', () {
      final snapshot = build(
        tasks: [
          task(
            dueTime: DateTime(2026, 9, 1, 21, 0),
            recurrence: const RecurrenceRule(type: RecurrenceType.daily),
            completedDates: const ['2026-09-14', '2026-09-15'],
          ),
        ],
        state: const WidgetState(period: WidgetPeriod.week),
      );
      expect(snapshot.rows.single.subtitle, contains('9/16'));
    });

    test("today's row does not repeat the date", () {
      final snapshot = build(tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))]);
      expect(snapshot.rows.single.subtitle, '15:00');
    });

    test('rows are ordered by the day they are due', () {
      final snapshot = build(
        tasks: [
          task(id: 'late', title: 'Late', dueTime: DateTime(2026, 9, 18, 9, 0)),
          task(id: 'soon', title: 'Soon', dueTime: DateTime(2026, 9, 15, 9, 0)),
        ],
        state: const WidgetState(period: WidgetPeriod.week),
      );
      expect(snapshot.rows.map((r) => r.title), ['Soon', 'Late']);
    });
  });

  group('filtering', () {
    test('a target filter keeps only what links to it', () {
      final snapshot = build(
        tasks: [
          task(id: 'a', dueTime: DateTime(2026, 9, 14, 9, 0), linkedTargetId: 'g1'),
          task(id: 'b', dueTime: DateTime(2026, 9, 14, 9, 0)),
        ],
        semesterGoals: [target()],
        state: const WidgetState(
            filterKind: WidgetFilterKind.target, filterId: 'g1'),
      );
      expect(snapshot.rows, hasLength(1));
    });

    test('filtering by a target also catches its milestones', () {
      final snapshot = build(
        tasks: [
          task(id: 'a', dueTime: DateTime(2026, 9, 14, 9, 0), linkedTargetId: 'child'),
        ],
        semesterGoals: [target(), target(id: 'child', parentId: 'g1')],
        state: const WidgetState(
            filterKind: WidgetFilterKind.target, filterId: 'g1'),
      );
      // Hiding work done under a milestone would make the filter useless
      expect(snapshot.rows, hasLength(1));
    });

    test('a vision filter works the same way', () {
      final snapshot = build(
        tasks: [
          task(id: 'a', dueTime: DateTime(2026, 9, 14, 9, 0), linkedGoalId: 'v1'),
          task(id: 'b', dueTime: DateTime(2026, 9, 14, 9, 0)),
        ],
        futureGoals: [vision()],
        state:
            const WidgetState(filterKind: WidgetFilterKind.goal, filterId: 'v1'),
      );
      expect(snapshot.rows, hasLength(1));
    });

    test('the header shows the filter name, not a generic label', () {
      final snapshot = build(
        semesterGoals: [target(title: 'Exchange programme')],
        state: const WidgetState(
            filterKind: WidgetFilterKind.target, filterId: 'g1'),
      );
      expect(snapshot.filterLabel, 'Exchange programme');
    });

    test('no filter falls back to the generic label', () {
      expect(build().filterLabel, s.filters);
    });
  });

  group('target and vision modes', () {
    test('only top-level items are listed', () {
      final snapshot = build(
        semesterGoals: [target(), target(id: 'child', parentId: 'g1')],
        state: const WidgetState(mode: WidgetMode.targets),
      );
      expect(snapshot.rows, hasLength(1));
    });

    test('the subtitle carries the progress of the direct children', () {
      final snapshot = build(
        semesterGoals: [
          target(),
          target(id: 'c1', parentId: 'g1', isDone: true),
          target(id: 'c2', parentId: 'g1'),
        ],
        state: const WidgetState(mode: WidgetMode.targets),
      );
      expect(snapshot.rows.single.subtitle, contains(s.goalProgress(1, 2)));
    });

    test('tapping a target opens it rather than ticking it', () {
      final snapshot = build(
        semesterGoals: [target()],
        state: const WidgetState(mode: WidgetMode.targets),
      );
      expect(snapshot.rows.single.tapAction, contains('kind=semesterGoal'));
      expect(snapshot.rows.single.checkAction, isNull);
    });

    test('visions list the same way', () {
      final snapshot = build(
        futureGoals: [vision(), vision(id: 'child', parentId: 'v1')],
        state: const WidgetState(mode: WidgetMode.goals),
      );
      expect(snapshot.rows, hasLength(1));
      expect(snapshot.rows.single.tapAction, contains('kind=futureGoal'));
    });
  });

  group('the filter picker', () {
    const pickerState = WidgetState(mode: WidgetMode.filterPicker);

    test('clearing the filter is always the first row', () {
      final snapshot = build(semesterGoals: [target()], state: pickerState);
      expect(snapshot.rows.first.tapAction, contains('kind=none'));
    });

    test('targets are grouped under a semester header', () {
      final snapshot = build(semesterGoals: [target()], state: pickerState);
      final header = snapshot.rows.firstWhere((r) => r.isHeader);
      expect(header.title, contains('115'));
      // A header is a label, not a choice
      expect(header.tapAction, isNull);
    });

    test('a finished semester is left out', () {
      final snapshot = build(
        // 114-1 ended before 114-2 began, i.e. 2026-01-31
        semesterGoals: [target(id: 'old', semester: '114-1')],
        state: pickerState,
      );
      expect(snapshot.rows.where((r) => r.isHeader), isEmpty);
      expect(snapshot.rows, hasLength(1), reason: 'only the clear row remains');
    });

    test('visions get their own section and are not grouped by semester', () {
      final snapshot = build(futureGoals: [vision()], state: pickerState);
      final headers = snapshot.rows.where((r) => r.isHeader).toList();
      expect(headers, hasLength(1));
      expect(headers.single.title, s.goals);
    });

    test('picking a target produces a filter action carrying its id', () {
      final snapshot = build(semesterGoals: [target()], state: pickerState);
      final choice = snapshot.rows.firstWhere((r) => r.title == 'Target');
      expect(choice.tapAction, contains('kind=target'));
      expect(choice.tapAction, contains('id=g1'));
    });
  });

  group('WidgetState', () {
    test('round trips', () {
      const original = WidgetState(
        mode: WidgetMode.goals,
        period: WidgetPeriod.month,
        filterKind: WidgetFilterKind.target,
        filterId: 'g1',
      );
      final back = WidgetState.decode(original.encode());
      expect(back.mode, original.mode);
      expect(back.period, original.period);
      expect(back.filterKind, original.filterKind);
      expect(back.filterId, original.filterId);
    });

    test('an unreadable state falls back to the defaults', () {
      // Parsed in a background isolate, where throwing has nowhere to go
      for (final bad in [null, '', 'not json', '{"mode":"nonsense"}']) {
        expect(WidgetState.decode(bad).mode, WidgetMode.tasks, reason: '$bad');
      }
    });
  });

  test('the snapshot serialises rows for the native side', () {
    final snapshot = build(tasks: [task(dueTime: DateTime(2026, 9, 14, 15, 0))]);
    final json = snapshot.toJson();
    expect(json['mode'], 'tasks');
    expect((json['rows'] as List).single, containsPair('title', 'Task'));
  });
}
