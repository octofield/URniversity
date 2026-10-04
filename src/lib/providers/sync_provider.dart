import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_style_provider.dart';
import 'auth_provider.dart';
import 'courses_provider.dart';
import 'grade_settings_provider.dart';
import '../core/grade_scale.dart';
import 'synced_list_notifier.dart';
import 'tasks_provider.dart';
import 'future_goals_provider.dart';
import 'semester_goals_provider.dart';
import 'trash_provider.dart';
import 'categories_provider.dart';
import 'inspirations_provider.dart';
import 'journal_provider.dart';
import 'profile_provider.dart';
import 'reviews_provider.dart';
import 'timetable_style_provider.dart';
import 'guest_provider.dart';
import 'settings_provider.dart';
import '../models/user_profile.dart';

final syncProvider = Provider<void>((ref) {
  if (ref.read(guestModeProvider)) {
    _loadGuest(ref);
  }

  ref.listen<bool>(guestModeProvider, (_, isGuest) {
    if (isGuest) {
      _loadGuest(ref);
    } else {
      _clearAll(ref);
    }
  });

  // Auto-populate username from Google name on first login (when no username set).
  ref.listen<UserProfile?>(profileProvider, (_, profile) {
    if (profile == null || profile.username?.isNotEmpty == true) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || ref.read(guestModeProvider)) return;
    final provider = user.appMetadata['provider'] as String?;
    final googleName = user.userMetadata?['full_name'] as String?;
    if (provider == 'google' && googleName != null) {
      ref.read(profileProvider.notifier).updateUsername(googleName);
    }
  });

  // Persist settings changes to Supabase whenever they change.
  ref.listen(languageProvider, (prev, next) => _saveSettings(ref));
  ref.listen(settingsProvider, (prev, next) => _saveSettings(ref));
  ref.listen(semesterSettingsProvider, (prev, next) => _saveSettings(ref));
  ref.listen(defaultTaskViewProvider, (prev, next) => _saveSettings(ref));
  ref.listen(showDayCounterProvider, (prev, next) => _saveSettings(ref));
  // The choice, not the style in use: a random launch drawing a new style is
  // not a change of setting
  ref.listen(appStyleChoiceProvider, (prev, next) => _saveStyle(ref));
  ref.listen(timetableStyleProvider, (prev, next) => _saveTimetableStyle(ref));
  ref.listen(termsProvider, (prev, next) => _saveTerms(ref));
  ref.listen(gradeSettingsProvider, (prev, next) {
    _saveGradeSettings(ref);
    _saveCreditCategories(ref);
  });

  var handlingGuestLogin = false;

  ref.listen(authStateProvider, (_, next) {
    next.whenData((authState) {
      final session = authState.session;
      final isGuest = ref.read(guestModeProvider);

      // User logged in while in guest mode — merge or discard, then switch.
      if (session != null && isGuest) {
        if (handlingGuestLogin) return;
        handlingGuestLogin = true;
        _handleGuestLogin(ref, session.user.id)
            .then((_) => handlingGuestLogin = false);
        return;
      }

      if (isGuest) return;

      if (session != null) {
        final uid = session.user.id;
        ref.read(tasksProvider.notifier).load(uid);
        ref.read(futureGoalsProvider.notifier).load(uid);
        ref.read(semesterGoalsProvider.notifier).load(uid);
        ref.read(trashProvider.notifier).load(uid);
        ref.read(categoriesProvider.notifier).load(uid);
        ref.read(inspirationsProvider.notifier).load(uid);
        ref.read(journalProvider.notifier).load(uid);
        ref.read(reviewsProvider.notifier).load(uid);
        ref.read(coursesProvider.notifier).load(uid);
        ref.read(profileProvider.notifier).load(uid);
        _loadSettings(ref, uid);
        _loadStyle(ref, uid);
        _loadTimetableStyle(ref, uid);
        _loadTerms(ref, uid);
        _loadGradeSettings(ref, uid);
        _loadCreditCategories(ref, uid);
        _recordActivity(uid);
      } else {
        _clearAll(ref);
      }
    });
  });
});

Future<void> _handleGuestLogin(Ref ref, String uid) async {
  if (ref.read(shouldMergeGuestDataProvider)) {
    // Order matters: these are real foreign keys, not logical ones.
    //   tasks.linked_target_id  -> semester_goals.id
    //   tasks.linked_goal_id    -> future_goals.id
    //   semester_goals.future_goal_id -> future_goals.id
    // A referencing row sent first is rejected and silently lost, so every
    // table a row points at has to be merged before it
    await ref.read(futureGoalsProvider.notifier).mergeToUser(uid);
    await ref.read(semesterGoalsProvider.notifier).mergeToUser(uid);
    await ref.read(tasksProvider.notifier).mergeToUser(uid);
    await ref.read(inspirationsProvider.notifier).mergeToUser(uid);
    await ref.read(journalProvider.notifier).mergeToUser(uid);
    // No foreign keys: a review's focus targets are plain ids, shown only if
    // they still exist
    await ref.read(reviewsProvider.notifier).mergeToUser(uid);
    // A course carries its own meetings, so it has no rows to order around
    await ref.read(coursesProvider.notifier).mergeToUser(uid);
    await ref.read(profileProvider.notifier).mergeToUser(uid);
  }
  // disable() clears SharedPreferences and sets isGuest = false,
  // which triggers _clearAll via the guestModeProvider listener.
  await ref.read(guestModeProvider.notifier).disable();
  // Reload from Supabase (state was just cleared by _clearAll).
  // Fired in parallel on purpose: each list loads independently and the UI
  // fills in as they arrive, so awaiting them in sequence would only be slower
  unawaited(ref.read(tasksProvider.notifier).load(uid));
  unawaited(ref.read(futureGoalsProvider.notifier).load(uid));
  unawaited(ref.read(semesterGoalsProvider.notifier).load(uid));
  unawaited(ref.read(trashProvider.notifier).load(uid));
  unawaited(ref.read(categoriesProvider.notifier).load(uid));
  unawaited(ref.read(inspirationsProvider.notifier).load(uid));
  unawaited(ref.read(journalProvider.notifier).load(uid));
  unawaited(ref.read(reviewsProvider.notifier).load(uid));
  unawaited(ref.read(coursesProvider.notifier).load(uid));
  unawaited(ref.read(profileProvider.notifier).load(uid));
  unawaited(_loadSettings(ref, uid));
  unawaited(_loadStyle(ref, uid));
  unawaited(_loadTimetableStyle(ref, uid));
  unawaited(_loadTerms(ref, uid));
  unawaited(_loadGradeSettings(ref, uid));
  unawaited(_loadCreditCategories(ref, uid));
  unawaited(_recordActivity(uid));
}

void _loadGuest(Ref ref) {
  ref.read(tasksProvider.notifier).loadGuest();
  ref.read(futureGoalsProvider.notifier).loadGuest();
  ref.read(semesterGoalsProvider.notifier).loadGuest();
  ref.read(inspirationsProvider.notifier).loadGuest();
  ref.read(journalProvider.notifier).loadGuest();
  ref.read(reviewsProvider.notifier).loadGuest();
  ref.read(coursesProvider.notifier).loadGuest();
  ref.read(profileProvider.notifier).loadGuest();
}

void _clearAll(Ref ref) {
  ref.read(tasksProvider.notifier).clear();
  ref.read(futureGoalsProvider.notifier).clear();
  ref.read(semesterGoalsProvider.notifier).clear();
  ref.read(trashProvider.notifier).clear();
  ref.read(categoriesProvider.notifier).reset();
  ref.read(inspirationsProvider.notifier).clear();
  ref.read(journalProvider.notifier).clear();
  ref.read(reviewsProvider.notifier).clear();
  ref.read(coursesProvider.notifier).clear();
  ref.read(profileProvider.notifier).clear();
  // Each list dropped its own cache_* rows above; signed out, none are left
  SharedPreferences.getInstance().then((p) => p.remove(kCacheOwnerKey));
}

// ── Settings sync ──────────────────────────────────────────────────────────────

Future<void> _loadSettings(Ref ref, String uid) async {
  try {
    final row = await readWithRetry(() => Supabase.instance.client
        .from('user_settings')
        .select('language, date_format, semester_count, semester_start_months, default_task_view, show_day_counter')
        .eq('user_id', uid)
        .maybeSingle());
    if (row == null) return;

    final langStr = row['language'] as String?;
    if (langStr != null) {
      ref.read(languageProvider.notifier).setLanguage(_langFromString(langStr));
    }

    final fmtStr = row['date_format'] as String?;
    if (fmtStr != null) {
      ref.read(settingsProvider.notifier).setDateFormat(_fmtFromString(fmtStr));
    }

    final semCount = row['semester_count'] as int?;
    final rawMonths = row['semester_start_months'];
    final semMonths = rawMonths is List ? rawMonths.cast<int>() : null;
    if (semCount != null) {
      ref.read(semesterSettingsProvider.notifier).setCount(semCount);
    }
    if (semMonths != null) {
      for (int i = 0; i < semMonths.length; i++) {
        ref.read(semesterSettingsProvider.notifier).setStartMonth(i, semMonths[i]);
      }
    }

    final taskView = row['default_task_view'] as int?;
    if (taskView != null) {
      ref.read(defaultTaskViewProvider.notifier).state = taskView;
    }

    final showCounter = row['show_day_counter'] as bool?;
    if (showCounter != null) {
      ref.read(showDayCounterProvider.notifier).state = showCounter;
    }
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings load');
  }
}

Future<void> _saveSettings(Ref ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  if (ref.read(guestModeProvider)) return;
  try {
    final sem = ref.read(semesterSettingsProvider);
    await runWithRetry(() => Supabase.instance.client.from('user_settings').upsert({
      'user_id': uid,
      'language': _langToString(ref.read(languageProvider)),
      'date_format': _fmtToString(ref.read(settingsProvider)),
      'semester_count': sem.count,
      'semester_start_months': sem.startMonths,
      'default_task_view': ref.read(defaultTaskViewProvider),
      'show_day_counter': ref.read(showDayCounterProvider),
    }));
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings save');
  }
}

// ── Style sync ─────────────────────────────────────────────────────────────────
//
// Read and written on its own rather than as part of _loadSettings' select and
// _saveSettings' upsert: user_settings.app_style is added by
// supabase/app_style.sql, and until that has been run a query naming the
// column fails. Kept apart, only the style stops syncing (and says so) while
// language, date format and the rest carry on

Future<void> _loadStyle(Ref ref, String uid) async {
  try {
    final row = await readWithRetry(() => Supabase.instance.client
        .from('user_settings')
        .select('app_style')
        .eq('user_id', uid)
        .maybeSingle());
    final name = row?['app_style'] as String?;
    // Nothing stored yet: keep what this device already shows, and the first
    // change writes it up
    if (name == null) return;
    await ref.read(appStyleProvider.notifier).applyChoice(name);
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings app_style load');
  }
}

Future<void> _saveStyle(Ref ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  if (ref.read(guestModeProvider)) return;
  try {
    // Only these two columns: an upsert updates just the columns it names, so
    // the rest of the row is left as it is
    await runWithRetry(() => Supabase.instance.client.from('user_settings').upsert({
      'user_id': uid,
      'app_style': ref.read(appStyleChoiceProvider),
    }));
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings app_style save');
  }
}

// ── Timetable style ────────────────────────────────────────────────────────────
//
// On its own for the same reason as the app style: user_settings.timetable_style
// is added by supabase/timetable_style.sql, and a query naming it fails until
// that runs

Future<void> _loadTimetableStyle(Ref ref, String uid) async {
  try {
    final row = await readWithRetry(() => Supabase.instance.client
        .from('user_settings')
        .select('timetable_style')
        .eq('user_id', uid)
        .maybeSingle());
    final name = row?['timetable_style'] as String?;
    // Nothing stored yet: keep this device's choice; the first change writes it
    if (name == null) return;
    final style = timetableStyleFromName(name);
    if (style != ref.read(timetableStyleProvider)) await ref.read(timetableStyleProvider.notifier).set(style);
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings timetable_style load');
  }
}

Future<void> _saveTimetableStyle(Ref ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  if (ref.read(guestModeProvider)) return;
  try {
    await runWithRetry(() => Supabase.instance.client.from('user_settings').upsert({
      'user_id': uid,
      'timetable_style': ref.read(timetableStyleProvider).name,
    }));
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings timetable_style save');
  }
}

// ── First days of classes ──────────────────────────────────────────────────────
//
// On their own for the same reason as the style: user_settings.term_starts is
// added by supabase/courses.sql, and a query naming it fails until that runs

Future<void> _loadTerms(Ref ref, String uid) async {
  try {
    final cloud = await fetchCloudTerms(uid);
    if (cloud.isNotEmpty) await ref.read(termsProvider.notifier).merge(cloud);
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings term_starts load');
  }
}

Future<void> _saveTerms(Ref ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  if (ref.read(guestModeProvider)) return;
  final terms = ref.read(termsProvider);
  if (terms.isEmpty) return;
  try {
    await runWithRetry(() => Supabase.instance.client.from('user_settings').upsert({
      'user_id': uid,
      'term_starts': {for (final e in terms.entries) e.key: e.value.toJson()},
    }));
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings term_starts save');
  }
}

// ── Degree: credits to graduate, pass mark ─────────────────────────────────────
//
// Separate for the same reason: the columns come with supabase/courses.sql

Future<void> _loadGradeSettings(Ref ref, String uid) async {
  try {
    final row = await readWithRetry(() => Supabase.instance.client
        .from('user_settings')
        .select('graduation_credits, degree_level')
        .eq('user_id', uid)
        .maybeSingle());
    final credits = row?['graduation_credits'] as int?;
    if (credits == null) return;
    // copyWith: credits by category arrive on their own and must survive this
    await ref.read(gradeSettingsProvider.notifier).set(ref.read(gradeSettingsProvider).copyWith(
          graduationCredits: credits,
          level: degreeLevelFromName(row?['degree_level'] as String?),
        ));
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings graduation_credits load');
  }
}

Future<void> _saveGradeSettings(Ref ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  if (ref.read(guestModeProvider)) return;
  if (!ref.read(gradeSettingsProvider.notifier).confirmed) return;
  final settings = ref.read(gradeSettingsProvider);
  try {
    await runWithRetry(() => Supabase.instance.client.from('user_settings').upsert({
      'user_id': uid,
      'graduation_credits': settings.graduationCredits,
      'degree_level': settings.level.name,
    }));
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings graduation_credits save');
  }
}

// ── Credits by category ────────────────────────────────────────────────────────
//
// Separate again: the columns come with the 2026-09-27 courses.sql, and are
// only ever written once the user has switched the feature on
// (GradeSettingsNotifier.categoriesTouched)

const _creditCategoryColumns =
    'credit_categories_enabled, entry_year, requirement_department, catalog_department, '
    'credits_required, credits_general, credits_elective';

Future<void> _loadCreditCategories(Ref ref, String uid) async {
  try {
    final row = await readWithRetry(() => Supabase.instance.client
        .from('user_settings')
        .select(_creditCategoryColumns)
        .eq('user_id', uid)
        .maybeSingle());
    final enabled = row?['credit_categories_enabled'] as bool?;
    // Never switched on for this account: keep this device's choice
    if (enabled == null) return;
    await ref.read(gradeSettingsProvider.notifier).set(ref.read(gradeSettingsProvider).copyWith(
          categoriesEnabled: enabled,
          entryYear: () => row!['entry_year'] as int?,
          requirementDepartment: () => row!['requirement_department'] as String?,
          catalogDepartment: () => row!['catalog_department'] as String?,
          requiredCredits: () => row!['credits_required'] as int?,
          generalCredits: () => row!['credits_general'] as int?,
          electiveCredits: () => row!['credits_elective'] as int?,
        ));
  } on PostgrestException catch (e) {
    // 42703, no such column: courses.sql has not been re-run, so no account
    // has these settings to load. Not a failure worth a message at every
    // sign-in to someone who never switched the feature on
    if (e.code == '42703') return;
    reportSyncError(ref, e, where: 'user_settings credit categories load');
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings credit categories load');
  }
}

Future<void> _saveCreditCategories(Ref ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  if (ref.read(guestModeProvider)) return;
  if (!ref.read(gradeSettingsProvider.notifier).categoriesTouched) return;
  final s = ref.read(gradeSettingsProvider);
  try {
    await runWithRetry(() => Supabase.instance.client.from('user_settings').upsert({
      'user_id': uid,
      'credit_categories_enabled': s.categoriesEnabled,
      'entry_year': s.entryYear,
      'requirement_department': s.requirementDepartment,
      'catalog_department': s.catalogDepartment,
      'credits_required': s.requiredCredits,
      'credits_general': s.generalCredits,
      'credits_elective': s.electiveCredits,
    }));
  } catch (e) {
    reportSyncError(ref, e, where: 'user_settings credit categories save');
  }
}

AppLanguage _langFromString(String s) {
  switch (s) {
    case 'en': return AppLanguage.en;
    case 'jp': return AppLanguage.jp;
    default: return AppLanguage.zhTw;
  }
}

String _langToString(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.zhTw: return 'zh_tw';
    case AppLanguage.en: return 'en';
    case AppLanguage.jp: return 'jp';
  }
}

DateDisplayFormat _fmtFromString(String s) {
  switch (s) {
    case 'mmdd': return DateDisplayFormat.mmdd;
    case 'yyyymmdd': return DateDisplayFormat.yyyymmdd;
    case 'longDate': return DateDisplayFormat.longDate;
    default: return DateDisplayFormat.mmddWeekday;
  }
}

String _fmtToString(DateDisplayFormat fmt) {
  switch (fmt) {
    case DateDisplayFormat.mmddWeekday: return 'mmddWeekday';
    case DateDisplayFormat.mmdd: return 'mmdd';
    case DateDisplayFormat.yyyymmdd: return 'yyyymmdd';
    case DateDisplayFormat.longDate: return 'longDate';
  }
}

// ── Activity, for the admin backend (D36) ──────────────────────────────────────
//
// One row a day per signed-in account that opened the app, for the daily,
// weekly and monthly active counts. Nothing about what was done. A day already
// recorded on this device is not sent again (D38 activity_day)

const _activityDayKey = 'activity_day';

Future<void> _recordActivity(String uid) async {
  final now = DateTime.now();
  final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final p = await SharedPreferences.getInstance();
  if (p.getString(_activityDayKey) == '$uid $day') return;
  try {
    await Supabase.instance.client.from('user_activity').upsert({'user_id': uid, 'day': day});
    await p.setString(_activityDayKey, '$uid $day');
  } catch (e) {
    // Not a sync failure: nothing of the user's failed to save, and before
    // admin.sql has run it would fail at every launch (hard rule 2 exception)
    debugPrint('[activity] not recorded: $e');
  }
}
