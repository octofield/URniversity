import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Set by preloadGuestMode() in main() before runApp, so the notifier
// starts with the correct initial value and avoids a login-screen flash.
bool _initialGuestMode = false;

Future<void> preloadGuestMode() async {
  final p = await SharedPreferences.getInstance();
  _initialGuestMode = p.getBool(_GuestModeNotifier._key) ?? false;
}

class _GuestModeNotifier extends StateNotifier<bool> {
  static const _key = 'is_guest_mode';
  static const _dataKeys = [
    'guest_inspirations',
    'guest_journals',
    'guest_profile',
    'guest_tasks',
    'guest_sem_goals',
    'guest_future_goals',
  ];

  _GuestModeNotifier() : super(_initialGuestMode);

  Future<void> enable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, true);
    state = true;
  }

  Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    for (final k in _dataKeys) {
      await p.remove(k);
    }
    state = false;
  }
}

final guestModeProvider = StateNotifierProvider<_GuestModeNotifier, bool>(
  (ref) => _GuestModeNotifier(),
);

// True when user chose to merge guest data into the account on login.
final shouldMergeGuestDataProvider = StateProvider<bool>((ref) => false);

// True when the user taps "登入" from guest mode — _AuthGate shows LoginScreen.
final pendingGuestLoginProvider = StateProvider<bool>((ref) => false);
