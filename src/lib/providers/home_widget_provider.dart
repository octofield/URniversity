import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../core/widget_snapshot.dart';
import '../services/home_widget_background.dart';
import '../services/home_widget_service.dart';
import 'categories_provider.dart';
import 'future_goals_provider.dart';
import 'notification_action_provider.dart';
import 'semester_goals_provider.dart';
import 'settings_provider.dart';
import 'tasks_provider.dart';

// What the widget is currently showing. Read back from storage on startup so
// the app does not reset the mode the user left it on
final widgetStateProvider = StateProvider<WidgetState>((ref) => const WidgetState());

// Keeps the home screen widget in step with the data while the app is running.
//
// The background engine covers taps made while the app is closed; this covers
// the other direction — a task added or ticked in the app has to reach the
// widget too. Both call the same buildWidgetSnapshot()
final homeWidgetSyncProvider = Provider<void>((ref) {
  if (!HomeWidgetService.isSupported) return;

  final snapshot = buildWidgetSnapshot(
    tasks: ref.watch(tasksProvider),
    semesterGoals: ref.watch(semesterGoalsProvider),
    futureGoals: ref.watch(futureGoalsProvider),
    categories: ref.watch(categoriesProvider),
    state: ref.watch(widgetStateProvider),
    semesterSettings: ref.watch(semesterSettingsProvider),
    s: ref.watch(stringsProvider),
    now: DateTime.now(),
  );

  unawaited(HomeWidgetService.instance
      .push(snapshot, languageCode: ref.watch(languageProvider).name));
});

// Routes taps that DO open the app. The silent ones never get here — they are
// handled entirely in the background engine
final homeWidgetLaunchProvider = Provider<void>((ref) {
  if (!HomeWidgetService.isSupported) return;

  void route(Uri? uri) {
    if (uri == null || uri.host != 'open') return;
    final kind = uri.queryParameters['kind'];
    final id = uri.queryParameters['id'];
    if (kind == null || id == null) return;
    ref.read(pendingOpenProvider.notifier).state = (kind: kind, id: id);
  }

  // Restored here rather than in the sync provider, which re-runs on every data
  // change and would keep resetting the mode the user chose. A microtask, not a
  // Future: a timer left pending is one a widget test will trip over
  unawaited(Future.microtask(() async {
    ref.read(widgetStateProvider.notifier).state =
        await HomeWidgetService.instance.readState();

    // A cold start misses the stream: the app was not listening when the tap
    // launched it, so the launching URI has to be asked for
    route(await HomeWidget.initiallyLaunchedFromHomeWidget());
    await HomeWidget.registerInteractivityCallback(handleWidgetAction);
  }));

  final sub = HomeWidget.widgetClicked.listen(route);
  ref.onDispose(sub.cancel);
});
