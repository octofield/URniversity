import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/realtime_sync.dart';
import 'package:urniversity/widgets/sync_controls.dart';

import '../helpers/pump_app.dart';

// Syncing on a timer and by hand (system_design.md §3-I, 2026-10-10): every
// five minutes while the app is in front, pulling a tab down, "sync now" in
// the side menu. A guest has nothing to sync and sees none of it
class _CountingSync extends LiveSync {
  _CountingSync(super.ref);
  int calls = 0;

  @override
  Future<void> refreshAll({Duration minGap = Duration.zero}) async {
    calls++;
    ref.read(lastSyncedProvider.notifier).state = DateTime.now();
  }
}

void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  group('every five minutes', () {
    testWidgets('ticks while in front, not in the background, not after stopping', (tester) async {
      var ticks = 0;
      final auto = AutoSync(kAutoSyncInterval, () => ticks++)..start();
      addTearDown(auto.stop);
      await tester.pump(kAutoSyncInterval);
      expect(ticks, 1);

      auto.setForeground(false);
      await tester.pump(kAutoSyncInterval * 3);
      expect(ticks, 1, reason: 'nothing while in the background');

      auto.setForeground(true);
      await tester.pump(kAutoSyncInterval);
      expect(ticks, 2);

      auto.stop();
      await tester.pump(kAutoSyncInterval * 2);
      expect(ticks, 2, reason: 'signed out');
      expect(auto.active, isFalse);
    });

    testWidgets('never runs before it is started (a guest, or signed out)', (tester) async {
      var ticks = 0;
      final auto = AutoSync(kAutoSyncInterval, () => ticks++)..setForeground(true);
      await tester.pump(kAutoSyncInterval * 2);
      expect(ticks, 0);
      expect(auto.active, isFalse);
    });
  });

  group('by hand', () {
    late _CountingSync sync;
    ProviderContainer signedIn({bool can = true}) => testContainer(overrides: [
          canSyncProvider.overrideWithValue(can),
          liveSyncProvider.overrideWith((ref) => sync = _CountingSync(ref)),
        ]);

    Widget tab() => PullToSync(
          // Not primary, as a tab's list with its own controller: such a list
          // is not pullable when it fits unless told to be
          child: Scaffold(body: ListView(primary: false, children: const [ListTile(title: Text('一列'))])),
        );

    testWidgets('pulling a tab down from its top syncs, even a short one', (tester) async {
      final c = signedIn();
      await pumpScreen(tester, tab(), container: c);
      await tester.fling(find.text('一列'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(sync.calls, 1);
    });

    testWidgets('"sync now" syncs and says when', (tester) async {
      final c = signedIn();
      await pumpScreen(tester, const Scaffold(body: SyncNowTile()), container: c);
      expect(find.text(zh.syncNever), findsOneWidget);
      await tester.tap(find.text(zh.syncNow));
      await tester.pumpAndSettle();
      expect(sync.calls, 1);
      expect(find.text(zh.syncedJustNow), findsOneWidget);
    });

    testWidgets('a guest gets neither', (tester) async {
      final c = signedIn(can: false);
      await pumpScreen(tester, tab(), container: c);
      expect(find.byType(RefreshIndicator), findsNothing);
      await pumpScreen(tester, const Scaffold(body: SyncNowTile()), container: c);
      expect(find.text(zh.syncNow), findsNothing);
    });
  });

  test('the last sync reads as a person would say it', () {
    final now = DateTime(2026, 10, 10, 15, 30);
    expect(lastSyncedLabel(null, now, zh), zh.syncNever);
    expect(lastSyncedLabel(now.subtract(const Duration(seconds: 20)), now, zh), zh.syncedJustNow);
    expect(lastSyncedLabel(now.subtract(const Duration(minutes: 3)), now, zh), zh.syncedMinutesAgo(3));
    expect(lastSyncedLabel(DateTime(2026, 10, 10, 9, 5), now, zh), zh.syncedAt('09:05'));
  });
}
