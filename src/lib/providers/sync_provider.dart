import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'tasks_provider.dart';
import 'future_goals_provider.dart';
import 'semester_goals_provider.dart';
import 'trash_provider.dart';
import 'categories_provider.dart';
import 'inspirations_provider.dart';
import 'journal_provider.dart';
import 'profile_provider.dart';
import 'guest_provider.dart';

final syncProvider = Provider<void>((ref) {
  // If the app starts in guest mode, load from local storage immediately.
  if (ref.read(guestModeProvider)) {
    _loadGuest(ref);
  }

  // React to guest-mode toggle.
  ref.listen<bool>(guestModeProvider, (_, isGuest) {
    if (isGuest) {
      _loadGuest(ref);
    } else {
      _clearAll(ref);
    }
  });

  // React to Supabase auth changes (skipped entirely when in guest mode).
  ref.listen(authStateProvider, (_, next) {
    next.whenData((authState) {
      if (ref.read(guestModeProvider)) return;
      final session = authState.session;
      if (session != null) {
        final uid = session.user.id;
        ref.read(tasksProvider.notifier).load(uid);
        ref.read(futureGoalsProvider.notifier).load(uid);
        ref.read(semesterGoalsProvider.notifier).load(uid);
        ref.read(trashProvider.notifier).load(uid);
        ref.read(categoriesProvider.notifier).load(uid);
        ref.read(inspirationsProvider.notifier).load(uid);
        ref.read(journalProvider.notifier).load(uid);
        ref.read(profileProvider.notifier).load(uid);
      } else {
        _clearAll(ref);
      }
    });
  });
});

void _loadGuest(Ref ref) {
  ref.read(tasksProvider.notifier).loadGuest();
  ref.read(futureGoalsProvider.notifier).loadGuest();
  ref.read(semesterGoalsProvider.notifier).loadGuest();
  ref.read(inspirationsProvider.notifier).loadGuest();
  ref.read(journalProvider.notifier).loadGuest();
  ref.read(profileProvider.notifier).loadGuest();
}

void _clearAll(Ref ref) {
  ref.read(tasksProvider.notifier).clear();
  ref.read(futureGoalsProvider.notifier).clear();
  ref.read(semesterGoalsProvider.notifier).clear();
  ref.read(trashProvider.notifier).clear();
  ref.read(categoriesProvider.notifier).reset();
  ref.read(inspirationsProvider.notifier).clear();
  ref.read(journalProvider.notifier).clear();
  ref.read(profileProvider.notifier).clear();
}
