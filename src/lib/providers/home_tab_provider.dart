import 'package:flutter_riverpod/flutter_riverpod.dart';

// Which of the four main tabs to show next, set by something that is not the
// tab bar — today the graph's "see the tasks" button, which filters the task
// list and then has to actually land the user on it. HomeScreen consumes it
// and puts it back to null; nothing is persisted.
final pendingTabProvider = StateProvider<int?>((ref) => null);
