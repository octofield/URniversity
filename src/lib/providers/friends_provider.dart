import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend.dart';
import 'auth_provider.dart';
import 'realtime_sync.dart';
import 'remote_config_provider.dart';
import 'synced_list_notifier.dart';

// Friends (system_design.md §3-V, data_dictionary.md D8-C, D40). Everything
// comes from the functions in supabase/friends.sql, only while signed in: a
// guest has no account a friend could be linked to. Not a SyncedListNotifier —
// nothing is kept on the device or written in the background; each action
// waits for the server and the list is fetched again

// An interface so widget tests, which never reach Supabase, hand in their own
abstract class FriendsSource {
  Future<List<FriendEntry>> list();
  Future<String> myCode();
  Future<FriendPreview?> owner(String code);
  // 'pending', or 'accepted' when they had already asked the caller
  Future<String> request(String code);
  Future<void> respond(String friendshipId, bool accept);
  // Cancelling a request, declining by the sender's side, or unfriending
  Future<void> remove(String friendshipId);
  Future<FriendShares> myShares();
  Future<void> saveShares(FriendShares shares);
  Future<FriendTimetable?> timetable(String friendId, String semester);
}

class SupabaseFriendsSource implements FriendsSource {
  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<List<FriendEntry>> list() async {
    final rows = await _db.rpc('friend_list');
    return [for (final r in rows as List<dynamic>) FriendEntry.fromJson((r as Map).cast<String, dynamic>())];
  }

  @override
  Future<String> myCode() async => await _db.rpc('my_friend_code') as String;

  @override
  Future<FriendPreview?> owner(String code) async {
    final rows = await _db.rpc('friend_code_owner', params: {'code': code}) as List<dynamic>;
    return rows.isEmpty ? null : FriendPreview.fromJson((rows.first as Map).cast<String, dynamic>());
  }

  @override
  Future<String> request(String code) async => await _db.rpc('request_friend', params: {'code': code}) as String;

  @override
  Future<void> respond(String friendshipId, bool accept) =>
      _db.rpc('respond_friend', params: {'friendship': friendshipId, 'accept': accept});

  @override
  Future<void> remove(String friendshipId) => _db.from('friendships').delete().eq('id', friendshipId);

  // The three columns alone, read and written on their own like app_style:
  // until friends.sql runs only these fail
  @override
  Future<FriendShares> myShares() async {
    final uid = _uid;
    if (uid == null) return const FriendShares();
    final row = await readWithRetry(() => _db
        .from('user_settings')
        .select('share_graph, share_rates, share_timetable')
        .eq('user_id', uid)
        .maybeSingle());
    return row == null ? const FriendShares() : FriendShares.fromJson(row);
  }

  @override
  Future<void> saveShares(FriendShares shares) async {
    final uid = _uid;
    if (uid == null) return;
    await runWithRetry(() => _db.from('user_settings').upsert({'user_id': uid, ...shares.toJson()}));
  }

  @override
  Future<FriendTimetable?> timetable(String friendId, String semester) async {
    final data = await _db.rpc('friend_timetable', params: {'friend': friendId, 'semester': semester});
    return data == null ? null : FriendTimetable.fromJson((data as Map).cast<String, dynamic>(), semester);
  }
}

final friendsSourceProvider = Provider<FriendsSource>((ref) => SupabaseFriendsSource());

// Signed in with an account, and not switched off from the admin backend
final friendsAvailableProvider = Provider<bool>(
  (ref) => ref.watch(canSyncProvider) && ref.watch(featureOnProvider('friends')),
);

// Friends and requests both ways. Fetched at sign-in, on every sync
// (LiveSync.refreshAll invalidates it: the five-minute timer, a pull, "sync
// now") and when the friends page opens; there is no push. While it fetches
// again, the last list stays on screen
final friendListProvider = FutureProvider<List<FriendEntry>>((ref) async {
  if (!ref.watch(friendsAvailableProvider)) return const [];
  // Another account signed in: a different list
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(friendsSourceProvider).list();
});

// Requests waiting for the user's answer: the red dot on the Me tab and 👥
final incomingInviteCountProvider = Provider<int>((ref) =>
    ref.watch(friendListProvider).valueOrNull?.where((f) => f.status == FriendStatus.incoming).length ?? 0);

final myFriendCodeProvider = FutureProvider<String?>((ref) async {
  if (!ref.watch(friendsAvailableProvider)) return null;
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(friendsSourceProvider).myCode();
});

final friendTimetableProvider = FutureProvider.family<FriendTimetable?, (String, String)>((ref, key) async {
  if (!ref.watch(friendsAvailableProvider)) return null;
  return ref.watch(friendsSourceProvider).timetable(key.$1, key.$2);
});

final friendPreviewProvider = FutureProvider.autoDispose.family<FriendPreview?, String>((ref, code) async {
  if (!ref.watch(friendsAvailableProvider)) return null;
  return ref.watch(friendsSourceProvider).owner(code);
});

// The actions. Each waits for the server, then fetches the list again; a
// failure is thrown on to the caller, which says why (friend_failure.dart)
class FriendActions {
  final Ref _ref;
  FriendActions(this._ref);

  FriendsSource get _source => _ref.read(friendsSourceProvider);

  Future<String> request(String code) async {
    final result = await _source.request(code);
    _ref.invalidate(friendListProvider);
    return result;
  }

  Future<void> respond(String friendshipId, bool accept) async {
    await _source.respond(friendshipId, accept);
    _ref.invalidate(friendListProvider);
  }

  Future<void> remove(String friendshipId) async {
    await _source.remove(friendshipId);
    _ref.invalidate(friendListProvider);
  }
}

final friendActionsProvider = Provider<FriendActions>((ref) => FriendActions(ref));

// The user's own three switches. A switch moves at once; if the write fails it
// moves back and the failure shows like any other sync error
class ShareSettingsNotifier extends AsyncNotifier<FriendShares> {
  @override
  Future<FriendShares> build() async {
    if (!ref.watch(friendsAvailableProvider)) return const FriendShares();
    ref.watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(friendsSourceProvider).myShares();
  }

  Future<void> set(FriendShares next) async {
    final previous = state.valueOrNull ?? const FriendShares();
    state = AsyncData(next);
    try {
      await ref.read(friendsSourceProvider).saveShares(next);
    } catch (e) {
      debugPrint('[friends] share save failed: $e');
      state = AsyncData(previous);
      reportSyncError(ref, e, where: 'user_settings share save');
    }
  }
}

final shareSettingsProvider = AsyncNotifierProvider<ShareSettingsNotifier, FriendShares>(ShareSettingsNotifier.new);
