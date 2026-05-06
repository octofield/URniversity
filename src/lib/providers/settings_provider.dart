import 'package:flutter_riverpod/flutter_riverpod.dart';
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

String formatDate(DateTime date, DateDisplayFormat format) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');

  switch (format) {
    case DateDisplayFormat.mmddWeekday:
      return '$mm/$dd（${weekdays[date.weekday - 1]}）';
    case DateDisplayFormat.mmdd:
      return '$mm/$dd';
    case DateDisplayFormat.yyyymmdd:
      return '${date.year}/$mm/$dd';
    case DateDisplayFormat.longDate:
      return '${months[date.month - 1]} ${date.day}';
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
