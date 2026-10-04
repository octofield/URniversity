import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/realtime_sync.dart';
import 'package:urniversity/providers/tasks_provider.dart';

import 'helpers/pump_app.dart';

// Keeping a signed-in account current (system_design.md §3-I, 2026-10-04):
// a refetch and a pushed change bring in what other devices wrote, and never
// undo a write of this device's that the server has not confirmed yet
class _Server {
  final rows = <String, Map<String, dynamic>>{};
  // Set: every write fails with a schema error (not retried)
  bool failing = false;
  // Set: writes wait for it before landing
  Completer<void>? hold;
  // Set: a fetch reads the rows at once but answers only when completed
  Completer<void>? fetchHold;
  int upserts = 0;
}

class _FakeTasks extends TasksNotifier {
  _FakeTasks(super.ref, this.server);
  final _Server server;

  @override
  Future<List<Map<String, dynamic>>> fetchRows(String userId) async {
    final snapshot = [...server.rows.values];
    await server.fetchHold?.future;
    return snapshot;
  }

  @override
  Future<void> sendUpsert(Map<String, dynamic> row) async {
    server.upserts++;
    await server.hold?.future;
    if (server.failing) throw const PostgrestException(message: 'rejected', code: '23514');
    server.rows[row['id'] as String] = row;
  }

  @override
  Future<void> sendDelete(String id) async {
    await server.hold?.future;
    if (server.failing) throw const PostgrestException(message: 'rejected', code: '23514');
    server.rows.remove(id);
  }
}

void main() {
  setUp(() => setUpTestSupabase(guest: false));

  Map<String, dynamic> row(String id, String title) =>
      {...Task(id: id, title: title, createdAt: DateTime(2026, 10, 1)).toJson(), 'user_id': 'u1'};

  Future<(_FakeTasks, _Server)> signedIn(List<Map<String, dynamic>> onServer) async {
    final server = _Server()..rows.addAll({for (final r in onServer) r['id'] as String: r});
    final c = testContainer(overrides: [tasksProvider.overrideWith((ref) => _FakeTasks(ref, server))]);
    final tasks = c.read(tasksProvider.notifier) as _FakeTasks;
    await tasks.load('u1');
    return (tasks, server);
  }

  List<String> titles(_FakeTasks tasks) => [for (final t in tasks.state) t.title]..sort();

  test('a refresh brings in what another device wrote', () async {
    final (tasks, server) = await signedIn([row('a', '交報告')]);
    server.rows['b'] = row('b', '另一台加的');
    server.rows['a'] = row('a', '交報告（改）');
    await tasks.refresh();
    expect(titles(tasks), ['交報告（改）', '另一台加的']);
  });

  test('a write that failed survives a refresh, and is sent again', () async {
    final (tasks, server) = await signedIn([]);
    server.failing = true;
    tasks.add('離線時加的');
    await pumpEventQueue();
    expect(server.rows, isEmpty, reason: 'it failed');

    server.failing = false;
    await tasks.refresh();
    expect(titles(tasks), ['離線時加的'], reason: 'not wiped by the server\'s empty list');
    await pumpEventQueue();
    expect(server.rows.values.single['title'], '離線時加的', reason: 'sent again');
  });

  test('a write still on its way is not undone by a refresh', () async {
    final (tasks, server) = await signedIn([row('a', '舊標題')]);
    server.hold = Completer<void>();
    tasks.update(tasks.state.single.copyWith(title: '新標題'));
    await tasks.refresh();
    expect(titles(tasks), ['新標題']);

    server.hold!.complete();
    await pumpEventQueue();
    await tasks.refresh();
    expect(titles(tasks), ['新標題'], reason: 'confirmed, and now the server agrees');
  });

  test('a write confirmed while a fetch is out is not undone by its older rows', () async {
    final (tasks, server) = await signedIn([row('a', '舊標題')]);
    server.fetchHold = Completer<void>();
    final refreshing = tasks.refresh();
    await pumpEventQueue();
    // The server has answered with the old title; the edit lands after that
    tasks.update(tasks.state.single.copyWith(title: '新標題'));
    await pumpEventQueue();
    expect(server.rows['a']!['title'], '新標題', reason: 'confirmed');
    server.fetchHold!.complete();
    await refreshing;
    expect(titles(tasks), ['新標題']);
  });

  test('a delete on its way keeps the row gone', () async {
    final (tasks, server) = await signedIn([row('a', '要刪的')]);
    server.hold = Completer<void>();
    tasks.remove('a');
    await tasks.refresh();
    expect(tasks.state, isEmpty);
    server.hold!.complete();
  });

  group('pushed changes', () {
    test('an insert, an update and a delete from elsewhere land', () async {
      final (tasks, _) = await signedIn([row('a', '交報告')]);
      LiveSync.apply(tasks, PostgresChangeEvent.insert, row('b', '新的'), const {});
      LiveSync.apply(tasks, PostgresChangeEvent.update, row('a', '交報告（改）'), const {});
      expect(titles(tasks), ['交報告（改）', '新的']);
      LiveSync.apply(tasks, PostgresChangeEvent.delete, const {}, const {'id': 'b'});
      expect(titles(tasks), ['交報告（改）']);
    });

    test('a row with a write of this device\'s on its way keeps that write', () async {
      final (tasks, server) = await signedIn([row('a', '舊標題')]);
      server.hold = Completer<void>();
      tasks.update(tasks.state.single.copyWith(title: '我的新標題'));
      // The echo of an older version, or another device's edit, arriving now
      LiveSync.apply(tasks, PostgresChangeEvent.update, row('a', '舊標題'), const {});
      expect(titles(tasks), ['我的新標題']);
      LiveSync.apply(tasks, PostgresChangeEvent.delete, const {}, const {'id': 'a'});
      expect(titles(tasks), ['我的新標題']);
      server.hold!.complete();
    });

    test('a guest takes no pushes', () async {
      final server = _Server();
      final c = testContainer(overrides: [tasksProvider.overrideWith((ref) => _FakeTasks(ref, server))]);
      final tasks = c.read(tasksProvider.notifier) as _FakeTasks;
      await tasks.loadGuest();
      LiveSync.apply(tasks, PostgresChangeEvent.insert, row('b', '新的'), const {});
      expect(tasks.state, isEmpty);
    });
  });
}
