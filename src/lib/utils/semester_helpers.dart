import '../l10n/app_strings.dart';
import '../providers/settings_provider.dart';

// The k-th break (1..count) is always the long break before next year's
// semester 1 restarts ("summer"); the remaining (count-1) slots use
// conventional Taiwan break names, matched to how each semester count is
// normally spoken aloud (e.g. 3-semester: 寒假/春假/暑假).
String breakName(int k, int count, AppStrings s) {
  if (k == count) return s.summerBreak;
  const namesByCount = {
    2: ['winter'],
    3: ['winter', 'spring'],
    4: ['autumn', 'winter', 'spring'],
  };
  final names = namesByCount[count] ?? const ['winter'];
  final key = (k - 1 >= 0 && k - 1 < names.length) ? names[k - 1] : 'winter';
  switch (key) {
    case 'spring':  return s.springBreak;
    case 'autumn':  return s.autumnBreak;
    default:        return s.winterBreak;
  }
}

// Formats a semester token for display. Regular semesters render unchanged
// ("114-1"); break tokens ("114-B2") render as "114 暑假", using the current
// semester count to resolve which break name position 2 refers to.
String formatSemester(String token, SemesterSettings settings, AppStrings s) {
  final parts = token.split('-');
  if (parts.length != 2 || !parts[1].startsWith('B')) return token;
  final k = int.tryParse(parts[1].substring(1));
  if (k == null) return token;
  return '${parts[0]} ${breakName(k, settings.count, s)}';
}
