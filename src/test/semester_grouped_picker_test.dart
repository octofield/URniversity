import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/widgets/semester_grouped_picker.dart';

// The link pickers' grouping and where they open (system_design.md §3-C)
void main() {
  SemesterPickerItem item(String id, String? semester, {String? parent, int order = 0}) =>
      SemesterPickerItem(
        id: id,
        title: id,
        semester: semester,
        parentId: parent,
        sortOrder: order,
      );

  group('groupBySemester', () {
    test('runs from the earliest semester, with no semester last', () {
      final groups = groupBySemester([
        item('a', '115-1'),
        item('undated', null),
        item('b', '114-2'),
        item('c', '114-B1'),
        item('d', '115-1'),
      ]);
      // A break sorts between the term before it and the one after
      expect(groups.map((g) => g.semester), ['114-B1', '114-2', '115-1', null]);
    });

    test('puts the newest on top and children under their parent', () {
      final rows = groupBySemester([
        item('old', '115-1', order: 0),
        item('new', '115-1', order: -1000),
        item('old child', '115-1', parent: 'new', order: 0),
        item('new child', '115-1', parent: 'new', order: -1000),
      ]).single.rows;

      expect(rows.map((r) => r.item.id), ['new', 'new child', 'old child', 'old']);
      expect(rows.map((r) => r.depth), [0, 1, 1, 0]);
    });

    test('a child whose parent is in another semester still shows', () {
      final groups = groupBySemester([
        item('parent', '114-1'),
        item('child', '115-1', parent: 'parent'),
      ]);
      expect(groups.last.rows.single.item.id, 'child');
      expect(groups.last.rows.single.depth, 0);
    });
  });

  group('startGroupIndex', () {
    final groups = groupBySemester([
      item('a', '114-1'),
      item('b', '115-1'),
      item('c', '116-1'),
      item('undated', null),
    ]);

    test('opens on the current semester', () {
      expect(groups[startGroupIndex(groups, '115-1')].semester, '115-1');
    });

    test('falls forward to the nearest later semester', () {
      expect(groups[startGroupIndex(groups, '115-2')].semester, '116-1');
    });

    test('falls back to the latest when everything is in the past', () {
      expect(groups[startGroupIndex(groups, '120-1')].semester, '116-1');
    });

    test('only undated items open at the top', () {
      expect(startGroupIndex(groupBySemester([item('x', null)]), '115-1'), 0);
    });
  });
}
