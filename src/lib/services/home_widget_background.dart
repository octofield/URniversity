import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/notification_payload.dart';
import '../core/widget_snapshot.dart';
import '../models/category.dart';
import '../models/future_goal.dart';
import '../models/semester_goal.dart';
import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../utils/category_helpers.dart';
import 'background_task_writer.dart';
import 'home_widget_service.dart';

// Handles every tap on the home screen widget that must NOT open the app.
//
// Runs in a separate Flutter engine, so there are no providers: the data is
// loaded from scratch each time, the same way notification_background.dart
// does. What to display is still decided by buildWidgetSnapshot(), so the
// widget can never disagree with itself depending on which isolate ran.
@pragma('vm:entry-point')
Future<void> handleWidgetAction(Uri? uri) async {
  DartPluginRegistrant.ensureInitialized();
  if (uri == null) return;
  try {
    await applyWidgetAction(uri);
  } catch (e) {
    // Nothing above this catches, and a broken tap must not leave the widget
    // frozen. The write path reports its own failures through the action log
    debugPrint('[widget] action failed: $uri — $e');
  }
}

// Separated from the entry point so it can be driven directly in a test.
//
// Only writes reach Dart now. Switching tab, period or filter is handled by the
// native side against views that are already computed, so it never wakes this
// engine — that round trip is what used to take over a second per tap
Future<void> applyWidgetAction(Uri uri) async {
  if (uri.host != 'toggle') {
    debugPrint('[widget] not a background action: $uri');
    return;
  }
  final payload = TaskNotificationPayload.decode(
      '${uri.queryParameters['id']}|${uri.queryParameters['date']}');
  if (payload == null) {
    debugPrint('[widget] unusable toggle payload: $uri');
    return;
  }
  final error = await toggleTaskFromBackground(payload);
  if (error != null) {
    // The native side already ticked the row. There may be no network to
    // rebuild from, so take the tick back directly; the app reports the
    // failure itself on its next launch
    await HomeWidgetService.instance.untick(
        WidgetAction.toggleDone(taskId: payload.taskId, date: payload.date));
    return;
  }
  // Rebuilt from storage so the ticked row drops out of every view
  await refreshWidgetFromStorage();
}

// Loads the current data and pushes a freshly built snapshot.
//
// Guest data lives in SharedPreferences; a signed-in user's lives in Supabase
// and is fetched in one go. Either way this is a cold read — the background
// engine holds nothing between invocations
Future<void> refreshWidgetFromStorage() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  final isGuest = prefs.getBool('is_guest_mode') ?? false;
  final data = isGuest
      ? _loadGuestData(prefs, await HomeWidgetService.instance.readLanguageCode())
      : await _loadCloudData();
  if (data == null) return;

  final snapshot = buildWidgetSnapshot(
    tasks: data.tasks,
    semesterGoals: data.semesterGoals,
    futureGoals: data.futureGoals,
    categories: data.categories,
    semesterSettings: data.semesterSettings,
    s: stringsFor(data.language),
    now: DateTime.now(),
  );
  await HomeWidgetService.instance.push(snapshot);
}

class _WidgetData {
  final List<Task> tasks;
  final List<SemesterGoal> semesterGoals;
  final List<FutureGoal> futureGoals;
  final List<CategoryEntry> categories;
  final SemesterSettings semesterSettings;
  final AppLanguage language;

  const _WidgetData({
    required this.tasks,
    required this.semesterGoals,
    required this.futureGoals,
    required this.categories,
    required this.semesterSettings,
    required this.language,
  });
}

List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    return (jsonDecode(raw) as List)
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e) {
    // A malformed mirror costs this refresh, not the app
    debugPrint('[widget] could not decode stored rows: $e');
    return const [];
  }
}

// A guest has no cloud row and no stored categories, so the built-in palette is
// the only thing there is to use
_WidgetData _loadGuestData(SharedPreferences prefs, String? languageCode) =>
    _WidgetData(
      tasks: _decodeList(prefs.getString('guest_tasks'), Task.fromJson),
      semesterGoals:
          _decodeList(prefs.getString('guest_sem_goals'), SemesterGoal.fromJson),
      futureGoals:
          _decodeList(prefs.getString('guest_future_goals'), FutureGoal.fromJson),
      categories: _builtInCategories(),
      semesterSettings: SemesterSettings.defaultSettings,
      language: _languageByCode(languageCode),
    );

Future<_WidgetData?> _loadCloudData() async {
  if (!await ensureBackgroundSupabase()) {
    debugPrint('[widget] no signed-in session; leaving the widget as it is');
    return null;
  }
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;

  final tasks = await db.from('tasks').select().eq('user_id', uid);
  final semGoals = await db.from('semester_goals').select().eq('user_id', uid);
  final futGoals = await db.from('future_goals').select().eq('user_id', uid);
  final settingsRow = await db
      .from('user_settings')
      .select('language, semester_count, semester_start_months')
      .eq('user_id', uid)
      .maybeSingle();
  final catRow = await db
      .from('user_categories')
      .select('ordered_list, styles')
      .eq('user_id', uid)
      .maybeSingle();

  return _WidgetData(
    tasks: [for (final r in tasks) Task.fromJson(r)],
    semesterGoals: [for (final r in semGoals) SemesterGoal.fromJson(r)],
    futureGoals: [for (final r in futGoals) FutureGoal.fromJson(r)],
    categories: _categoriesFromRow(catRow),
    semesterSettings: _settingsFromRow(settingsRow),
    language: _languageFromRow(settingsRow),
  );
}

List<CategoryEntry> _builtInCategories() => [
      for (final id in FutureCategories.builtIns)
        CategoryEntry(id: id, color: defaultCatColor(id), icon: defaultCatIcon(id)),
    ];

List<CategoryEntry> _categoriesFromRow(Map<String, dynamic>? row) {
  if (row == null) return _builtInCategories();
  try {
    final ids = (row['ordered_list'] as List<dynamic>).cast<String>();
    final styles = (row['styles'] as Map<String, dynamic>?) ?? {};
    return [
      for (final id in ids)
        styles[id] != null
            ? CategoryEntry.fromJson(id, styles[id] as Map<String, dynamic>)
            : CategoryEntry(
                id: id, color: defaultCatColor(id), icon: defaultCatIcon(id)),
    ];
  } catch (e) {
    debugPrint('[widget] could not read categories: $e');
    return _builtInCategories();
  }
}

SemesterSettings _settingsFromRow(Map<String, dynamic>? row) {
  if (row == null) return SemesterSettings.defaultSettings;
  final count = row['semester_count'] as int?;
  final months = (row['semester_start_months'] as List<dynamic>?)?.cast<int>();
  if (count == null || months == null || months.length != count) {
    return SemesterSettings.defaultSettings;
  }
  return SemesterSettings(count: count, startMonths: months);
}

AppLanguage _languageFromRow(Map<String, dynamic>? row) =>
    _languageByCode(row?['language'] as String?);

AppLanguage _languageByCode(String? code) => switch (code) {
      'en' => AppLanguage.en,
      'jp' => AppLanguage.jp,
      _ => AppLanguage.zhTw,
    };
