import '../l10n/app_strings.dart';
import '../providers/settings_provider.dart';

// The calendar date a semester token starts on.
//
// Tokens are "{rocYear}-{term}" or "{rocYear}-B{term}" for the break that
// follows that term. An academic year rolls into the next calendar year
// whenever a term starts in a month at or before the previous term's, which is
// what yearOffset counts.
//
// A break token has no derivable start of its own — nothing in
// SemesterSettings says when classes end — so it reports its own semester's
// start and relies on semesterEnd() for the boundary that matters.
DateTime semesterStart(String token, SemesterSettings settings) {
  final parts = token.split('-');
  final rocYear = int.parse(parts[0]);
  final termIndex =
      int.parse(parts[1].replaceFirst('B', '')).clamp(1, settings.startMonths.length) - 1;

  var yearOffset = 0;
  for (var i = 1; i <= termIndex; i++) {
    if (settings.startMonths[i] <= settings.startMonths[i - 1]) yearOffset++;
  }
  return DateTime(rocYear + 1911 + yearOffset, settings.startMonths[termIndex]);
}

// The last day a semester's goals are still "this semester".
//
// SemesterSettings only carries start months, so there is no data for when
// classes end and the break begins. A term therefore runs right up to the next
// term's start, break included — that is the only boundary the data supports,
// and it is the one a deadline reminder should use anyway
DateTime semesterEnd(String token, SemesterSettings settings) {
  final parts = token.split('-');
  final rocYear = int.parse(parts[0]);
  final term = int.parse(parts[1].replaceFirst('B', ''));
  final isLastTerm = term >= settings.startMonths.length;

  final nextToken = isLastTerm ? '${rocYear + 1}-1' : '$rocYear-${term + 1}';
  return semesterStart(nextToken, settings).subtract(const Duration(days: 1));
}

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
