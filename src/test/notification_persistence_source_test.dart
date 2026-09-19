@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// notification_service.dart talks to the platform, so no test can run it —
// there is no platform channel under flutter test. What broke here was not
// timing but three flags, and those can be read out of the source: a reminder
// used to vanish the moment anything rescheduled the batch, and again the
// moment the user tapped it.
void main() {
  // Comment lines go first: the ones above each flag name what is being
  // looked for
  final code = File('lib/services/notification_service.dart')
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .toList();

  String bodyOf(String signature, String end) {
    final start = code.indexWhere((line) => line.contains(signature));
    expect(start, isNot(-1), reason: '$signature is gone');
    final stop = code.indexWhere((line) => line.trimRight() == end, start + 1);
    return code.sublist(start, stop).join('\n');
  }

  test('rescheduling takes down only what has not fired', () {
    final apply = bodyOf('Future<void> apply(', '  }');

    expect(apply, contains('pendingNotificationRequests()'));
    expect(
      apply,
      isNot(contains('cancelAll()')),
      reason: 'cancelAll() also wipes the reminders already in the shade',
    );
  });

  test('a reminder stays on screen when it is tapped', () {
    expect(code.any((line) => line.contains('autoCancel: false')), isTrue);
    expect(
      code.any((line) => line.contains('autoCancel: true')),
      isFalse,
      reason: 'the reminder stands for work still to do',
    );
  });

  test('ticking the box from the widget takes it down too', () {
    // The home screen widget and the notification's own button both write
    // through background_task_writer, which is a different isolate from the
    // app's own toggle — it has to clear the shade itself
    final background = File('lib/services/background_task_writer.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    // The call, not just the function: a guard that only looks for the name
    // stays green when the write path stops calling it
    expect(background, contains('await cancelShownReminder(payload.taskId)'));
    expect(background, contains('notificationIdsForTask'));
  });

  test('completing the task is what takes the reminder down', () {
    final cancelForTask = bodyOf('Future<void> cancelForTask(', '  }');

    expect(cancelForTask, contains('getActiveNotifications()'));
    expect(cancelForTask, contains('_plugin.cancel('));
  });
}
