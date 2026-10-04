import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'courses_provider.dart';
import 'future_goals_provider.dart';
import 'guest_provider.dart';
import 'inspirations_provider.dart';
import 'journal_provider.dart';
import 'reviews_provider.dart';
import 'semester_goals_provider.dart';
import 'synced_list_notifier.dart';
import 'tasks_provider.dart';
import 'trash_provider.dart';

// Keeping a signed-in account current while the app is open (system_design.md
// §3-I, 2026-10-04). Before this the lists were read once, at sign-in, and a
// change made on another device showed only after a restart.
//
// - Pushed: Supabase Realtime sends each change to the account's rows as it
//   happens (supabase/realtime.sql adds the tables to its publication; until
//   that has been run nothing arrives, and the rest still works).
// - Asked for: coming back to the app — or to the browser tab — fetches every
//   list again, at most every [kResumeRefreshGap]; so does reconnecting, which
//   covers whatever was pushed while the connection was down.
//
// Rows this device wrote and the server has not confirmed are kept over both
// (SyncedListNotifier._pending). Guests have nothing on the server to follow
const kResumeRefreshGap = Duration(seconds: 30);

final liveSyncProvider = Provider<LiveSync>((ref) {
  final live = LiveSync(ref);
  ref.onDispose(live.stop);
  void follow() {
    final uid = ref.read(guestModeProvider) ? null : Supabase.instance.client.auth.currentUser?.id;
    live.follow(uid);
  }

  ref.listen(authStateProvider, (_, _) => follow());
  ref.listen<bool>(guestModeProvider, (_, _) => follow());
  follow();
  return live;
});

class LiveSync {
  LiveSync(this.ref);

  final Ref ref;
  String? _uid;
  RealtimeChannel? _channel;
  bool _subscribedOnce = false;
  DateTime? _lastRefresh;

  // Table → the list that holds it
  Map<String, SyncedListNotifier<dynamic>> get _lists => {
        'tasks': ref.read(tasksProvider.notifier),
        'semester_goals': ref.read(semesterGoalsProvider.notifier),
        'future_goals': ref.read(futureGoalsProvider.notifier),
        'inspirations': ref.read(inspirationsProvider.notifier),
        'journals': ref.read(journalProvider.notifier),
        'reviews': ref.read(reviewsProvider.notifier),
        'courses': ref.read(coursesProvider.notifier),
      };

  void follow(String? uid) {
    if (uid == _uid) return;
    stop();
    _uid = uid;
    if (uid == null) return;
    final client = Supabase.instance.client;
    final channel = client.channel('lists:$uid');
    for (final MapEntry(key: table, value: list) in _lists.entries) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
        callback: (change) => apply(list, change.eventType, change.newRecord, change.oldRecord),
      );
    }
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Back after a drop: anything pushed meanwhile was missed
        if (_subscribedOnce) refreshAll();
        _subscribedOnce = true;
      } else if (error != null) {
        debugPrint('[sync] realtime $status - $error');
      }
    });
    _channel = channel;
  }

  // One pushed change into its list
  static void apply(
    SyncedListNotifier<dynamic> list,
    PostgresChangeEvent event,
    Map<String, dynamic> newRecord,
    Map<String, dynamic> oldRecord,
  ) {
    switch (event) {
      case PostgresChangeEvent.insert:
      case PostgresChangeEvent.update:
        list.applyRemote(row: newRecord);
      case PostgresChangeEvent.delete:
        final id = oldRecord['id'];
        if (id != null) list.applyRemote(deletedId: '$id');
      case PostgresChangeEvent.all:
        break;
    }
  }

  // Skipped within [minGap] of the last one: switching apps back and forth is
  // not a reason to ask again
  void refreshAll({Duration minGap = Duration.zero}) {
    if (_uid == null) return;
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!) < minGap) return;
    _lastRefresh = now;
    for (final list in _lists.values) {
      unawaited(list.refresh());
    }
    unawaited(ref.read(trashProvider.notifier).refresh());
  }

  void stop() {
    final channel = _channel;
    _channel = null;
    _subscribedOnce = false;
    _lastRefresh = null;
    _uid = null;
    if (channel != null) unawaited(Supabase.instance.client.removeChannel(channel));
  }
}
