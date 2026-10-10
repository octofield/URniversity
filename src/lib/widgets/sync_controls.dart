import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/recent_picks.dart' show formatClock;
import '../l10n/app_strings.dart';
import '../providers/realtime_sync.dart';
import '../providers/settings_provider.dart';

// Syncing by hand (system_design.md §3-I, 2026-10-10): pulling a tab down from
// its top, or "sync now" in the side menu. Both fetch every list again at once
// and wait for it; a guest has nothing on the server, so neither appears

// "Synced just now", "… 3 minutes ago", or the time of day once it is an hour
String lastSyncedLabel(DateTime? at, DateTime now, AppStrings s) {
  if (at == null) return s.syncNever;
  final minutes = now.difference(at).inMinutes;
  if (minutes < 1) return s.syncedJustNow;
  if (minutes < 60) return s.syncedMinutesAgo(minutes);
  return s.syncedAt(formatClock(at));
}

// A tab pulled down from its top syncs. Its lists can be pulled even when they
// fit on screen: otherwise a short tab would have nothing to drag
class PullToSync extends ConsumerWidget {
  final Widget child;
  const PullToSync({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canSyncProvider)) return child;
    final behavior = ScrollConfiguration.of(context);
    return RefreshIndicator(
      // The tab's own list, wherever it sits under the header
      notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
      onRefresh: () => ref.read(liveSyncProvider).refreshAll(),
      child: ScrollConfiguration(
        behavior: behavior.copyWith(
          physics: AlwaysScrollableScrollPhysics(parent: behavior.getScrollPhysics(context)),
        ),
        child: child,
      ),
    );
  }
}

// The side menu's row: "sync now", with when it last did
class SyncNowTile extends ConsumerWidget {
  const SyncNowTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canSyncProvider)) return const SizedBox.shrink();
    final s = ref.watch(stringsProvider);
    final syncing = ref.watch(syncingProvider);
    return ListTile(
      leading: syncing
          ? const SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(2), child: CircularProgressIndicator(strokeWidth: 2)))
          : const Icon(Icons.sync),
      title: Text(s.syncNow),
      subtitle: Text(syncing ? s.syncing : lastSyncedLabel(ref.watch(lastSyncedProvider), DateTime.now(), s)),
      onTap: syncing ? null : () => ref.read(liveSyncProvider).refreshAll(),
    );
  }
}
