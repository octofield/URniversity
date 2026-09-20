import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Set while a Google account is away being re-authenticated for deletion.
//
// Deliberately NOT persisted: if the app is killed during the trip to Google,
// coming back should not find the app still intending to delete the account.
final pendingAccountDeletionProvider = StateProvider<bool>((ref) => false);

final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});
