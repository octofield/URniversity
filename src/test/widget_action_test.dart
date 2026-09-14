import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/core/widget_snapshot.dart';

// The action URIs are the whole contract between the native widget and Dart.
// Kotlin builds some of them by hand, so the shapes are pinned here: a renamed
// host or parameter would otherwise only show up as a tap that does nothing.
void main() {
  group('action URIs', () {
    test('toggling carries the task and the day', () {
      final uri = Uri.parse(
        WidgetAction.toggleDone(taskId: 'abc', date: DateTime(2026, 1, 5)),
      );
      expect(uri.host, 'toggle');
      expect(uri.queryParameters['id'], 'abc');
      // Zero padded so it parses back the same way the task model writes it
      expect(uri.queryParameters['date'], '2026-01-05');
    });

    test('switching mode names the mode', () {
      final uri = Uri.parse(WidgetAction.switchMode(WidgetMode.targets));
      expect(uri.host, 'mode');
      expect(uri.queryParameters['value'], 'targets');
    });

    test('switching period names the period', () {
      final uri = Uri.parse(WidgetAction.switchPeriod(WidgetPeriod.month));
      expect(uri.host, 'period');
      expect(uri.queryParameters['value'], 'month');
    });

    test('clearing the filter sends no id at all', () {
      final uri = Uri.parse(WidgetAction.setFilter());
      expect(uri.host, 'filter');
      expect(uri.queryParameters['kind'], 'none');
      expect(uri.queryParameters.containsKey('id'), isFalse);
    });

    test('setting a filter carries kind and id', () {
      final uri = Uri.parse(
        WidgetAction.setFilter(kind: WidgetFilterKind.goal, id: 'v1'),
      );
      expect(uri.queryParameters['kind'], 'goal');
      expect(uri.queryParameters['id'], 'v1');
    });

    test('opening an item is the only host the app reacts to', () {
      final uri = Uri.parse(WidgetAction.openItem(kind: 'task', id: 't1'));
      // WidgetActionReceiver routes on exactly this host to decide whether to
      // bring the app forward, so it must not drift
      expect(uri.host, 'open');
      expect(uri.queryParameters['kind'], 'task');
      expect(uri.queryParameters['id'], 't1');
    });

    test('every action shares one scheme', () {
      final all = [
        WidgetAction.toggleDone(taskId: 'a', date: DateTime(2026, 1, 1)),
        WidgetAction.switchMode(WidgetMode.tasks),
        WidgetAction.switchPeriod(WidgetPeriod.day),
        WidgetAction.setFilter(),
        WidgetAction.openItem(kind: 'task', id: 'a'),
      ];
      for (final raw in all) {
        expect(Uri.parse(raw).scheme, WidgetAction.scheme, reason: raw);
      }
    });
  });
}
