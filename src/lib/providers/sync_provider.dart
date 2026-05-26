import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'tasks_provider.dart';
import 'future_goals_provider.dart';
import 'semester_goals_provider.dart';
import 'trash_provider.dart';
import 'categories_provider.dart';

final syncProvider = Provider<void>((ref) {
  ref.listen(authStateProvider, (_, next) {
    next.whenData((authState) {
      final session = authState.session;
      if (session != null) {
        final uid = session.user.id;
        ref.read(tasksProvider.notifier).load(uid);
        ref.read(futureGoalsProvider.notifier).load(uid);
        ref.read(semesterGoalsProvider.notifier).load(uid);
        ref.read(trashProvider.notifier).load(uid);
        ref.read(categoriesProvider.notifier).load(uid);
      } else {
        ref.read(tasksProvider.notifier).clear();
        ref.read(futureGoalsProvider.notifier).clear();
        ref.read(semesterGoalsProvider.notifier).clear();
        ref.read(trashProvider.notifier).clear();
        ref.read(categoriesProvider.notifier).reset();
      }
    });
  });
});
