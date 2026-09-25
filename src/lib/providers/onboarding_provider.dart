import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// One chapter per tab, in tab order: HomeScreen starts kTourChapters[i] the
// first time tab i is shown
const kTourChapters = ['today', 'semester', 'future', 'me'];

// Which tour chapters have run. Device-local on purpose: it says something
// about this install, not about the person, so it does not belong in
// user_settings and must not travel through the guest merge. Seeing the tour
// on a phone should not skip it on a laptop, where the layout is different.
//
// It is deliberately NOT in _GuestModeNotifier._dataKeys either: leaving guest
// mode clears the guest's data, and replaying the tour at that point would be
// wrong — they have just finished using the app.
Set<String> _initialDone = {};

Future<void> preloadOnboarding() async {
  final p = await SharedPreferences.getInstance();
  _initialDone = (p.getStringList(_OnboardingNotifier.key) ?? const []).toSet();
}

class _OnboardingNotifier extends StateNotifier<Set<String>> {
  static const key = 'onboarding_done';

  _OnboardingNotifier() : super(_initialDone);

  Future<void> markDone(String chapter) async {
    if (state.contains(chapter)) return;
    // Set first: the chapter is already closing, and waiting on the disk write
    // would let a rebuild in between start it over
    state = {...state, chapter};
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, state.toList());
  }
}

final onboardingProvider =
    StateNotifierProvider<_OnboardingNotifier, Set<String>>((ref) => _OnboardingNotifier());

// Set by the guide in Settings to replay one chapter; HomeScreen consumes it
// and puts it back to null, the same way it handles pendingTabProvider
final tourReplayProvider = StateProvider<String?>((ref) => null);
