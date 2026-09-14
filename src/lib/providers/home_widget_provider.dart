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

// Keeps the home screen widget in step with the data while the app is running.
//
// The snapshot carries every view the widget can show, so it no longer depends
// on which tab the user left the widget on — that state lives on the native
// side, which switches without waking Dart
final homeWidgetSyncProvider = Provider<void>((ref) {
  if (!HomeWidgetService.isSupported) return;

  final snapshot = buildWidgetSnapshot(
    tasks: ref.watch(tasksProvider),
    semesterGoals: ref.watch(semesterGoalsProvider),
    futureGoals: ref.watch(futureGoalsProvider),
    categories: ref.watch(categoriesProvider),
    semesterSettings: ref.watch(semesterSettingsProvider),
    s: ref.watch(stringsProvider),
    now: DateTime.now(),
  );

  unawaited(HomeWidgetService.instance
      .push(snapshot, languageCode: ref.watch(languageProvider).name));
});

// The + button names the kind it belongs to; these are the destinations
// _handlePendingOpen in main.dart knows how to open
const _newKinds = {
  'task': 'newTask',
  'semesterGoal': 'newSemesterGoal',
  'futureGoal': 'newFutureGoal',
};

// Routes the widget taps that open the app: a row, or the + button. Everything
// silent is handled natively or in the background engine and never gets here
final homeWidgetLaunchProvider = Provider<void>((ref) {
  if (!HomeWidgetService.isSupported) return;

  void route(Uri? uri) {
    if (uri == null) return;
    final kind = uri.queryParameters['kind'];
    if (kind == null) return;

    switch (uri.host) {
      case 'open':
        final id = uri.queryParameters['id'];
        if (id == null) return;
        ref.read(pendingOpenProvider.notifier).state = (kind: kind, id: id);
      case 'new':
        final target = _newKinds[kind];
        if (target == null) return;
        ref.read(pendingOpenProvider.notifier).state = (kind: target, id: '');
    }
  }

  // A microtask, not a Future: a timer left pending is one a widget test will
  // trip over. A cold start misses the stream — the app was not listening when
  // the tap launched it — so the launching URI has to be asked for
  unawaited(Future.microtask(() async {
    route(await HomeWidget.initiallyLaunchedFromHomeWidget());
    await HomeWidget.registerInteractivityCallback(handleWidgetAction);
  }));

  final sub = HomeWidget.widgetClicked.listen(route);
  ref.onDispose(sub.cancel);
});
