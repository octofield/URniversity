import 'package:flutter_riverpod/flutter_riverpod.dart';

class DateNotifier extends StateNotifier<DateTime> {
  DateNotifier() : super(_stripTime(DateTime.now()));

  static DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void prev() => state = state.subtract(const Duration(days: 1));
  void next() => state = state.add(const Duration(days: 1));
  void setDate(DateTime date) => state = _stripTime(date);
  void goToToday() => state = _stripTime(DateTime.now());
}

final dateProvider = StateNotifierProvider<DateNotifier, DateTime>(
  (ref) => DateNotifier(),
);
