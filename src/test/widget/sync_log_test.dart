import 'dart:io' show SocketException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/synced_list_notifier.dart';
import 'package:urniversity/screens/sync_log_screen.dart';

import '../helpers/pump_app.dart';

// "Sync failed" came and went with nothing to trace (reported 2026-09-27). Each
// failure now says where it happened and is kept for the developer-mode log
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  // A provider-side reporter, the way sync_provider and friends call it
  final reporter = Provider<void Function(Object, String)>(
    (ref) => (error, where) => reportSyncError(ref, error, where: where),
  );

  test('a failure names where it happened, newest first, the last 20 kept', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final report = c.read(reporter);
    for (var i = 0; i < 25; i++) {
      report(PostgrestException(message: 'boom $i', code: '23514'), 'courses upsert');
    }
    final log = c.read(syncLogProvider);
    expect(log.length, kSyncLogSize);
    expect(describeSyncError(log.first), 'courses upsert: code=23514 | boom 24');
    expect(describeSyncError(log.last), contains('boom 5'));
    // The snack bar reads the same object, so it names the table too
    expect(describeSyncError(c.read(syncErrorProvider)!), startsWith('courses upsert: '));
  });

  testWidgets('the developer-mode page lists them', (tester) async {
    final c = testContainer();
    await pumpScreen(tester, const SyncLogScreen(), container: c);
    expect(find.text(zh.syncLogEmpty), findsOneWidget);

    c.read(reporter)(const PostgrestException(message: 'new row violates check', code: '23514'),
        'user_settings term_starts save');
    await tester.pumpAndSettle();
    expect(find.textContaining('user_settings term_starts save'), findsOneWidget);
    expect(find.textContaining('code=23514 | new row violates check'), findsOneWidget);
    expect(find.byTooltip(zh.syncLogCopy), findsOneWidget);
  });

  group('reports to the admin backend', () {
    late List<Map<String, dynamic>> sent;
    setUp(() {
      sent = [];
      resetErrorUploads();
      errorReportUser = () => 'u1';
      errorReportSender = (row) async => sent.add(row);
    });
    tearDown(() {
      errorReportUser = () => null;
      resetErrorUploads();
    });

    test('ten a launch at most, with where it happened', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      for (var i = 0; i < 12; i++) {
        c.read(reporter)(PostgrestException(message: 'boom $i', code: '23514'), 'courses upsert');
      }
      expect(sent.length, kMaxErrorUploads);
      expect(sent.first['where'], 'courses upsert');
      expect(sent.first['code'], '23514');
      expect(sent.first['user_id'], 'u1');
    });

    test('not the network kind, and not for a guest', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(reporter)(const SocketException('offline'), 'tasks upsert');
      expect(sent, isEmpty);
      errorReportUser = () => null;
      c.read(reporter)(const PostgrestException(message: 'x', code: '42501'), 'tasks upsert');
      expect(sent, isEmpty);
    });

    test('a report that fails to send is not itself reported', () async {
      errorReportSender = (row) async => throw Exception('no network');
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(reporter)(const PostgrestException(message: 'x', code: '42501'), 'tasks upsert');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(syncLogProvider).length, 1);
    });
  });
}
