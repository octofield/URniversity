// What the task sheet offers as one-tap suggestions.
//
// Both lists are "most recently used first, no duplicates": the newest pick
// goes to the front and any earlier copy of it is dropped. Kept as pure
// functions so the ordering and the roll-over to tomorrow can be tested without
// a provider or SharedPreferences.

// How many picks are remembered. Three are shown; the rest are the stock that
// survives deleting a goal or two
const int kRecentPicksKept = 8;

List<String> withRecentPick(List<String> current, String pick, {int keep = kRecentPicksKept}) =>
    [pick, ...current.where((e) => e != pick)].take(keep).toList();

// Suggestions in recent order, skipping anything that no longer exists (a
// deleted goal) so the chips can never point at a missing row
List<T> resolveRecent<T>(List<String> ids, Map<String, T> byId, int limit) => [
      for (final id in ids)
        if (byId[id] != null) byId[id] as T,
    ].take(limit).toList();

String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

// A remembered time applied to today, or to tomorrow when today's has already
// gone by — suggesting a due time in the past would never be what was meant
DateTime suggestedDueDate(String clock, DateTime now) {
  final parts = clock.split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  return today.isAfter(now) ? today : today.add(const Duration(days: 1));
}
