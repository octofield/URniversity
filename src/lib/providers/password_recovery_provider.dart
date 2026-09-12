import 'package:flutter_riverpod/flutter_riverpod.dart';

// True while the user arrived through a password-reset link. Supabase hands out
// a real session for recovery, so without this flag _AuthGate would drop them
// straight onto HomeScreen and they would never get to set a new password.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);
