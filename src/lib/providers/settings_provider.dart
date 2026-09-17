import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../l10n/strings_zh_tw.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_jp.dart';

// ── Language ──────────────────────────────────────────────────────────────────

enum AppLanguage { zhTw, en, jp }

AppStrings stringsFor(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.zhTw: return const StringsZhTw();
    case AppLanguage.en:   return const StringsEn();
    case AppLanguage.jp:   return const StringsJp();
  }
}

String languageLabel(AppLanguage lang, AppStrings s) {
  switch (lang) {
    case AppLanguage.zhTw: return s.langZhTw;
    case AppLanguage.en:   return s.langEn;
    case AppLanguage.jp:   return s.langJp;
  }
}

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.zhTw);
  void setLanguage(AppLanguage lang) => state = lang;
}

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>(
  (ref) => LanguageNotifier(),
);

final stringsProvider = Provider<AppStrings>(
  (ref) => stringsFor(ref.watch(languageProvider)),
);

// ── Date format ───────────────────────────────────────────────────────────────

enum DateDisplayFormat { mmddWeekday, mmdd, yyyymmdd, longDate }

String formatDate(DateTime date, DateDisplayFormat format, AppStrings s) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');

  switch (format) {
    case DateDisplayFormat.mmddWeekday:
      return s.dateWithWeekday('$mm/$dd', s.weekdayShort(date.weekday));
    case DateDisplayFormat.mmdd:
      return '$mm/$dd';
    case DateDisplayFormat.yyyymmdd:
      return '${date.year}/$mm/$dd';
    case DateDisplayFormat.longDate:
      return s.dateLongDate(date.month, date.day);
  }
}

String dateFormatLabel(DateDisplayFormat format, AppStrings s) {
  switch (format) {
    case DateDisplayFormat.mmddWeekday: return s.fmtMmddWeekday;
    case DateDisplayFormat.mmdd:        return s.fmtMmdd;
    case DateDisplayFormat.yyyymmdd:    return s.fmtYyyymmdd;
    case DateDisplayFormat.longDate:    return s.fmtLongDate;
  }
}

class SettingsNotifier extends StateNotifier<DateDisplayFormat> {
  SettingsNotifier() : super(DateDisplayFormat.mmddWeekday);
  void setDateFormat(DateDisplayFormat f) => state = f;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, DateDisplayFormat>(
  (ref) => SettingsNotifier(),
);

// ── Default task view ─────────────────────────────────────────────────────────

// 0 = all, 1 = daily, 2 = weekly
final defaultTaskViewProvider = StateProvider<int>((ref) => 0);

// ── Day counter toggle ────────────────────────────────────────────────────────

final showDayCounterProvider = StateProvider<bool>((ref) => true);

// ── Task completion effect ────────────────────────────────────────────────────

// How loudly ticking a task off is celebrated. Device-local like the
// notification settings: it is about this device's feel, not account data
enum TaskCompletionEffect { off, basic, celebrate }

String completionEffectLabel(TaskCompletionEffect effect, AppStrings s) {
  switch (effect) {
    case TaskCompletionEffect.off:       return s.effectOff;
    case TaskCompletionEffect.basic:     return s.effectBasic;
    case TaskCompletionEffect.celebrate: return s.effectCelebrate;
  }
}

class CompletionEffectNotifier extends StateNotifier<TaskCompletionEffect> {
  CompletionEffectNotifier() : super(TaskCompletionEffect.celebrate) {
    _restore();
  }

  static const prefsKey = 'task_completion_effect';

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(prefsKey);
    if (stored == null) return;
    state = TaskCompletionEffect.values
        .where((e) => e.name == stored)
        // A value this build does not know just falls back to the default
        .firstOrNull ?? TaskCompletionEffect.celebrate;
  }

  Future<void> set(TaskCompletionEffect effect) async {
    state = effect;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, effect.name);
  }
}

final completionEffectProvider =
    StateNotifierProvider<CompletionEffectNotifier, TaskCompletionEffect>(
  (ref) => CompletionEffectNotifier(),
);

// ── Developer mode ────────────────────────────────────────────────────────────

class DevModeState {
  final bool enabled;
  final DateTime? customTime;
  const DevModeState({this.enabled = false, this.customTime});
}

class DevModeNotifier extends StateNotifier<DevModeState> {
  DevModeNotifier() : super(const DevModeState());
  void enable() => state = DevModeState(enabled: true, customTime: state.customTime);
  void disable() => state = const DevModeState();
  void setCustomTime(DateTime? t) => state = DevModeState(enabled: state.enabled, customTime: t);
}

final devModeProvider = StateNotifierProvider<DevModeNotifier, DevModeState>(
  (ref) => DevModeNotifier(),
);

// Effective "now" — returns customTime if dev mode is active, else real time
final effectiveNowProvider = Provider<DateTime>((ref) {
  final dev = ref.watch(devModeProvider);
  if (dev.enabled && dev.customTime != null) return dev.customTime!;
  return DateTime.now();
});

// The academic-year number for a given date (the calendar year of the last
// semester-1 start before or on that date).
int academicYear(DateTime date, SemesterSettings settings) {
  final sem1Month = settings.startMonths[0];
  return date.month >= sem1Month ? date.year : date.year - 1;
}

// Compute the grade displayed to the user, accounting for elapsed academic years.
int computedGrade(int baseGrade, int gradeSetYear, DateTime effectiveNow, SemesterSettings settings) {
  final currentYear = academicYear(effectiveNow, settings);
  return (baseGrade + (currentYear - gradeSetYear)).clamp(1, 7);
}

// ── Semester settings ─────────────────────────────────────────────────────────

class SemesterSettings {
  final int count;             // 2, 3, or 4 semesters per year
  final List<int> startMonths; // start month for each semester (index 0 = sem 1)

  const SemesterSettings({required this.count, required this.startMonths});

  // Taiwan default: sem 1 starts Aug, sem 2 starts Feb
  static const defaultSettings = SemesterSettings(
    count: 2,
    startMonths: [8, 2],
  );

  SemesterSettings copyWith({int? count, List<int>? startMonths}) {
    return SemesterSettings(
      count: count ?? this.count,
      startMonths: startMonths ?? this.startMonths,
    );
  }
}

class SemesterSettingsNotifier extends StateNotifier<SemesterSettings> {
  SemesterSettingsNotifier() : super(SemesterSettings.defaultSettings);

  void setCount(int count) {
    final current = state.startMonths;
    List<int> newStarts;
    if (count <= current.length) {
      newStarts = current.sublist(0, count);
    } else {
      const defaults = [8, 2, 6, 12];
      newStarts = [
        ...current,
        for (int i = current.length; i < count; i++) defaults[i % defaults.length],
      ];
    }
    state = SemesterSettings(count: count, startMonths: newStarts);
  }

  void setStartMonth(int semIdx, int month) {
    final updated = List<int>.from(state.startMonths);
    updated[semIdx] = month;
    state = state.copyWith(startMonths: updated);
  }

  void reset() => state = SemesterSettings.defaultSettings;
}

final semesterSettingsProvider =
    StateNotifierProvider<SemesterSettingsNotifier, SemesterSettings>(
  (ref) => SemesterSettingsNotifier(),
);
