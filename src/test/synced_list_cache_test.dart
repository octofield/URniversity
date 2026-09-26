import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/synced_list_notifier.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import 'helpers/pump_app.dart';

// The signed-in cache (data_dictionary.md D24): the last-seen rows are drawn
// before the query returns, only ever for the account that owns them. The
// query itself fails here — widget tests answer every request with 400 — which
// doubles as the offline case: the cached rows stay on screen
void main() {
  final cachedTask = Task(id: 't1', title: '交報告', createdAt: DateTime(2026, 9, 20));

  Future<void> seedCache(String owner) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(kCacheOwnerKey, owner);
    await p.setString('cache_tasks', jsonEncode([cachedTask.toJson()]));
  }

  setUp(() => setUpTestSupabase(guest: false));

  testWidgets('the owner sees the cached rows even with no network', (tester) async {
    await seedCache('u1');
    final scope = testContainer();
    await tester.runAsync(() => scope.read(tasksProvider.notifier).load('u1'));

    expect(scope.read(tasksProvider).map((t) => t.title), ['交報告']);
  });

  testWidgets('another account never sees them', (tester) async {
    await seedCache('u1');
    final scope = testContainer();
    await tester.runAsync(() => scope.read(tasksProvider.notifier).load('u2'));

    expect(scope.read(tasksProvider), isEmpty);
  });

  testWidgets('changes are written back, and signing out removes them', (tester) async {
    final scope = testContainer();
    final notifier = scope.read(tasksProvider.notifier);
    await tester.runAsync(() async {
      // With no network a load never succeeds, so the account is set the other
      // way a signed-in list gets one: merging (an empty list sends nothing)
      await notifier.mergeToUser('u1');
      notifier.state = [cachedTask];
      await Future<void>.delayed(Duration.zero);
    });
    final p = await SharedPreferences.getInstance();
    final written = (jsonDecode(p.getString('cache_tasks')!) as List).map((j) => (j as Map)['title']);
    expect(written, ['交報告']);
    expect(p.getString(kCacheOwnerKey), 'u1');

    notifier.clear();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(p.getString('cache_tasks'), isNull);
  });

  testWidgets('guest mode writes no cache', (tester) async {
    final scope = testContainer();
    final notifier = scope.read(tasksProvider.notifier);
    await tester.runAsync(() async {
      await notifier.loadGuest();
      notifier.add('訪客的任務');
      await Future<void>.delayed(Duration.zero);
    });
    final p = await SharedPreferences.getInstance();
    expect(p.getString('cache_tasks'), isNull);
    expect(p.getString(kCacheOwnerKey), isNull);
  });
}
