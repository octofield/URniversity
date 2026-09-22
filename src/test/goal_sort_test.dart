import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/providers/future_goals_provider.dart';
import 'package:urniversity/providers/semester_goals_provider.dart';

// The targets and visions pages sort one level of their tree at a time
// (system_design.md, sorting). Manual is the drag order; every other key falls
// back to it on a tie so rows sharing a key keep a stable place.
void main() {
  SemesterGoal target(String id, String title,
          {int order = 0, String? vision, bool done = false}) =>
      SemesterGoal(
        id: id,
        title: title,
        semester: '115-1',
        futureGoalId: vision,
        isDone: done,
        sortOrder: order,
      );

  FutureGoal vision(String id, String title,
          {int order = 0, String? start, String? end}) =>
      FutureGoal(
        id: id,
        title: title,
        startSemester: start,
        endSemester: end,
        sortOrder: order,
      );

  List<String> ids(List<dynamic> goals) =>
      [for (final g in goals) (g as dynamic).id as String];

  group('applyTargetSort', () {
    final rows = [
      target('c', 'Gamma', order: 3, vision: 'v2'),
      target('a', 'alpha', order: 1, done: true),
      target('b', 'Beta', order: 2, vision: 'v1'),
    ];
    const titles = {'v1': 'Exchange', 'v2': 'Career'};

    test('manual is the drag order', () {
      expect(ids(applyTargetSort(rows, TargetSort.manual)), ['a', 'b', 'c']);
    });

    test('A-Z ignores case', () {
      expect(ids(applyTargetSort(rows, TargetSort.title)), ['a', 'b', 'c']);
    });

    test('by vision groups by its name and puts unlinked ones last', () {
      expect(
        ids(applyTargetSort(rows, TargetSort.vision, visionTitles: titles)),
        ['c', 'b', 'a'],
      );
    });

    test('unfinished first keeps the drag order within each half', () {
      expect(ids(applyTargetSort(rows, TargetSort.undoneFirst)), ['b', 'c', 'a']);
    });

    test('a tie falls back to the drag order', () {
      final tied = [
        target('y', 'Same', order: 2),
        target('x', 'Same', order: 1),
      ];
      expect(ids(applyTargetSort(tied, TargetSort.title)), ['x', 'y']);
    });
  });

  group('applyVisionSort', () {
    final rows = [
      vision('late', 'Zeta', order: 1, start: '116-1', end: '116-2'),
      vision('none', 'alpha', order: 2),
      vision('early', 'Mid', order: 3, start: '114-2', end: '117-1'),
    ];

    test('manual is the drag order', () {
      expect(ids(applyVisionSort(rows, VisionSort.manual)),
          ['late', 'none', 'early']);
    });

    test('A-Z ignores case', () {
      expect(ids(applyVisionSort(rows, VisionSort.title)),
          ['none', 'early', 'late']);
    });

    test('start semester puts the earliest first and unset ones last', () {
      expect(ids(applyVisionSort(rows, VisionSort.startSemester)),
          ['early', 'late', 'none']);
    });

    test('end semester orders by where each one finishes', () {
      expect(ids(applyVisionSort(rows, VisionSort.endSemester)),
          ['late', 'early', 'none']);
    });
  });
}
