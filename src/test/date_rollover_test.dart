import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/providers/date_provider.dart';

// The app used to hold "today" from the moment it started, so one left open
// past midnight kept showing yesterday. The date being shown follows the day
// over — but only when it was actually sitting on today.
void main() {
  test('the shown date follows the day over', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(dateProvider.notifier);

    final today = DateTime(2026, 9, 19);
    notifier.goToToday(today);
    notifier.rollOverTo(DateTime(2026, 9, 20, 0, 0, 1));

    expect(container.read(dateProvider), DateTime(2026, 9, 20));
  });

  test('a date the user picked is left alone', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(dateProvider.notifier);

    notifier.goToToday(DateTime(2026, 9, 19));
    notifier.setDate(DateTime(2026, 9, 12));
    notifier.rollOverTo(DateTime(2026, 9, 20, 0, 0, 1));

    expect(container.read(dateProvider), DateTime(2026, 9, 12),
        reason: 'browsing an older day should survive midnight');
  });

  test('the same day changes nothing', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(dateProvider.notifier);

    notifier.goToToday(DateTime(2026, 9, 19));
    notifier.rollOverTo(DateTime(2026, 9, 19, 23, 59));

    expect(container.read(dateProvider), DateTime(2026, 9, 19));
  });
}
