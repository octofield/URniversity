import 'package:flutter_riverpod/flutter_riverpod.dart';

class DateNotifier extends StateNotifier<DateTime> {
  DateNotifier() : super(_stripTime(DateTime.now()));

  static DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void prev() => state = state.subtract(const Duration(days: 1));
  void next() => state = state.add(const Duration(days: 1));
  void setDate(DateTime date) => state = _stripTime(date);
  void goToToday([DateTime? now]) {
    state = _stripTime(now ?? DateTime.now());
    _shownToday = state;
  }

  // What "today" was when this notifier last looked. Kept so the day rolling
  // over can move the selection with it
  DateTime _shownToday = _stripTime(DateTime.now());

  // Called when the clock crosses midnight or the app returns to the
  // foreground. Only moves the selection if it was sitting on the old today —
  // someone browsing last Tuesday should stay on last Tuesday
  void rollOverTo(DateTime now) {
    final today = _stripTime(now);
    if (today == _shownToday) return;
    final wasOnToday = state == _shownToday;
    _shownToday = today;
    if (wasOnToday) state = today;
  }
}

final dateProvider = StateNotifierProvider<DateNotifier, DateTime>(
  (ref) => DateNotifier(),
);
