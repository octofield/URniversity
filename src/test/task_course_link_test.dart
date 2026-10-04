import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/models/task.dart';

// A task's course (2026-10-03): written only once it has had one, so a
// database without the column still takes every other task
void main() {
  final task = Task(id: 't', title: '寫作業', createdAt: DateTime(2026, 10, 3));

  test('a task that never had a course leaves the key out', () {
    expect(task.toJson().containsKey('linked_course_id'), isFalse);
  });

  test('linked, and then unlinked, it is written each time', () {
    final linked = task.copyWith(linkedCourseId: 'calc');
    expect(linked.toJson()['linked_course_id'], 'calc');
    expect(linked.courseId, 'calc');

    final unlinked = linked.copyWith(linkedCourseId: '');
    expect(unlinked.toJson()['linked_course_id'], '');
    expect(unlinked.courseId, isNull);
    expect(Task.fromJson(unlinked.toJson()).courseId, isNull);
  });
}
