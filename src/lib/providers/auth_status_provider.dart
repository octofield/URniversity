import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'guest_provider.dart';

// Where the router sends someone (system_design.md §1-A): to the login page,
// or into the app. A guest counts as in, unless they asked to sign in.
//
// "unknown" is a stored session that has expired and is still being
// refreshed. Treating it as signed in is what showed the tasks for a moment
// before the login page took over (reported 2026-10-03), so the wait screen
// shows instead — for a few seconds at most, because offline the refresh never
// answers and the stored session is all there is to go on
enum AuthStatus { unknown, signedIn, signedOut }

const kAuthSettleWait = Duration(seconds: 4);

final _authSettleWaitOverProvider = FutureProvider<bool>(
  (ref) => Future<bool>.delayed(kAuthSettleWait, () => true),
);

final authStatusProvider = Provider<AuthStatus>((ref) {
  if (ref.watch(guestModeProvider)) {
    return ref.watch(pendingGuestLoginProvider) ? AuthStatus.signedOut : AuthStatus.signedIn;
  }
  // Re-read on every sign-in, sign-out and token refresh
  ref.watch(authStateProvider);
  final session = Supabase.instance.client.auth.currentSession;
  if (session == null) return AuthStatus.signedOut;
  if (session.isExpired && !(ref.watch(_authSettleWaitOverProvider).value ?? false)) return AuthStatus.unknown;
  return AuthStatus.signedIn;
});
