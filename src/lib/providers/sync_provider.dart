import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'tasks_provider.dart';
import 'future_goals_provider.dart';
import 'semester_goals_provider.dart';
import 'trash_provider.dart';
import 'categories_provider.dart';
import 'inspirations_provider.dart';
import 'journal_provider.dart';
import 'profile_provider.dart';
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
        ref.read(profileProvider.notifier).load(uid);
        _loadSettings(ref, uid);
      } else {
        _clearAll(ref);
      }
    });
  });
});

Future<void> _handleGuestLogin(Ref ref, String uid) async {
  if (ref.read(shouldMergeGuestDataProvider)) {
    await ref.read(tasksProvider.notifier).mergeToUser(uid);
    await ref.read(inspirationsProvider.notifier).mergeToUser(uid);
    await ref.read(journalProvider.notifier).mergeToUser(uid);
    await ref.read(profileProvider.notifier).mergeToUser(uid);
    await ref.read(semesterGoalsProvider.notifier).mergeToUser(uid);
    await ref.read(futureGoalsProvider.notifier).mergeToUser(uid);
  }
  // disable() clears SharedPreferences and sets isGuest = false,
  // which triggers _clearAll via the guestModeProvider listener.
  await ref.read(guestModeProvider.notifier).disable();
  // Reload from Supabase (state was just cleared by _clearAll).
  ref.read(tasksProvider.notifier).load(uid);
  ref.read(futureGoalsProvider.notifier).load(uid);
  ref.read(semesterGoalsProvider.notifier).load(uid);
  ref.read(trashProvider.notifier).load(uid);
  ref.read(categoriesProvider.notifier).load(uid);
  ref.read(inspirationsProvider.notifier).load(uid);
  ref.read(journalProvider.notifier).load(uid);
  ref.read(profileProvider.notifier).load(uid);
  _loadSettings(ref, uid);
}

void _loadGuest(Ref ref) {
  ref.read(tasksProvider.notifier).loadGuest();
  ref.read(futureGoalsProvider.notifier).loadGuest();
  ref.read(semesterGoalsProvider.notifier).loadGuest();
  ref.read(inspirationsProvider.notifier).loadGuest();
  ref.read(journalProvider.notifier).loadGuest();
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
  ref.read(profileProvider.notifier).clear();
}

// ── Settings sync ──────────────────────────────────────────────────────────────

Future<void> _loadSettings(Ref ref, String uid) async {
  try {
    final row = await Supabase.instance.client
        .from('user_settings')
        .select('language, date_format, semester_count, semester_start_months, default_task_view, show_day_counter')
        .eq('user_id', uid)
        .maybeSingle();
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
  } catch (_) {}
}

Future<void> _saveSettings(Ref ref) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;
  if (ref.read(guestModeProvider)) return;
  try {
    final sem = ref.read(semesterSettingsProvider);
    await Supabase.instance.client.from('user_settings').upsert({
      'user_id': uid,
      'language': _langToString(ref.read(languageProvider)),
      'date_format': _fmtToString(ref.read(settingsProvider)),
      'semester_count': sem.count,
      'semester_start_months': sem.startMonths,
      'default_task_view': ref.read(defaultTaskViewProvider),
      'show_day_counter': ref.read(showDayCounterProvider),
    });
  } catch (_) {}
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
