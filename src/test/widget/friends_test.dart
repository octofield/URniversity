import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/core/timetable.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/models/course.dart';
import 'package:urniversity/models/friend.dart';
import 'package:urniversity/models/future_goal.dart';
import 'package:urniversity/models/semester_goal.dart';
import 'package:urniversity/models/task.dart';
import 'package:urniversity/providers/friends_provider.dart';
import 'package:urniversity/providers/realtime_sync.dart';
import 'package:urniversity/providers/remote_config_provider.dart';
import 'package:urniversity/providers/tasks_provider.dart';
import 'package:urniversity/screens/friend_screen.dart';
import 'package:urniversity/screens/friends_screen.dart';
import 'package:urniversity/screens/invite_accept_screen.dart';
import 'package:urniversity/screens/me_screen.dart';

import '../helpers/pump_app.dart';

// The friends feature against a stand-in for supabase/friends.sql: widget tests
// never reach Supabase, so what the server allows is checked by hand with two
// real accounts (scripts/friends_check, test plan M1)
class FakeFriends implements FriendsSource {
  List<FriendEntry> entries;
  FriendShares shares = const FriendShares();
  FriendTimetable? table;
  List<Task>? tasks;
  FriendGraph? graphData;
  FriendPreview? preview;
  Object? requestError;
  Object? saveError;
  String requestResult = 'pending';
  int listCalls = 0;
  final requested = <String>[];
  final responded = <(String, bool)>[];
  final removed = <String>[];
  final saved = <FriendShares>[];

  FakeFriends([this.entries = const []]);

  @override
  Future<List<FriendEntry>> list() async {
    listCalls++;
    return entries;
  }

  @override
  Future<String> myCode() async => 'ABCD2345';

  @override
  Future<FriendPreview?> owner(String code) async => preview;

  @override
  Future<String> request(String code) async {
    if (requestError != null) throw requestError!;
    requested.add(code);
    return requestResult;
  }

  @override
  Future<void> respond(String friendshipId, bool accept) async {
    responded.add((friendshipId, accept));
    entries = [
      for (final e in entries)
        if (e.friendshipId != friendshipId)
          e
        else if (accept)
          FriendEntry(friendshipId: e.friendshipId, userId: e.userId, name: e.name, status: FriendStatus.friend),
    ];
  }

  @override
  Future<void> remove(String friendshipId) async {
    removed.add(friendshipId);
    entries = [for (final e in entries) if (e.friendshipId != friendshipId) e];
  }

  @override
  Future<FriendShares> myShares() async => shares;

  @override
  Future<void> saveShares(FriendShares next) async {
    if (saveError != null) throw saveError!;
    saved.add(next);
    shares = next;
  }

  @override
  Future<FriendTimetable?> timetable(String friendId, String semester) async => table;

  @override
  Future<List<Task>?> rates(String friendId) async => tasks;

  @override
  Future<FriendGraph?> graph(String friendId) async => graphData;
}

FriendEntry entry(String id, String name, FriendStatus status, [FriendShares shares = const FriendShares()]) =>
    FriendEntry(friendshipId: id, userId: 'user-$id', name: name, status: status, shares: shares);

void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  ProviderContainer signedIn(FakeFriends fake, {RemoteConfig? remoteConfig}) => testContainer(
        overrides: [
          canSyncProvider.overrideWithValue(true),
          friendsSourceProvider.overrideWithValue(fake),
        ],
        remoteConfig: remoteConfig,
      );

  final list = [
    entry('a', '阿明', FriendStatus.incoming),
    entry('b', '小華', FriendStatus.outgoing),
    entry('c', '大雄', FriendStatus.friend, const FriendShares(timetable: true)),
  ];

  group('who can use it', () {
    testWidgets('a guest is asked to make an account, and nothing is asked of the server', (tester) async {
      final fake = FakeFriends(list);
      await pumpScreen(tester, const FriendsScreen(),
          container: testContainer(overrides: [friendsSourceProvider.overrideWithValue(fake)]));
      expect(find.text(zh.friendsGuestPrompt), findsOneWidget);
      expect(find.text(zh.loginOrCreateAccount), findsOneWidget);
      expect(fake.listCalls, 0);
    });

    testWidgets('switched off from the backend: a line saying so, no calls', (tester) async {
      final fake = FakeFriends(list);
      await pumpScreen(tester, const FriendsScreen(),
          container: signedIn(fake, remoteConfig: const RemoteConfig(flags: {'friends': false})));
      expect(find.text(zh.friendsOff), findsOneWidget);
    });
  });

  group('the friends page', () {
    testWidgets('requests to answer, requests sent, and friends', (tester) async {
      await pumpScreen(tester, const FriendsScreen(), container: signedIn(FakeFriends(list)));
      await tester.scrollUntilVisible(find.text('大雄'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text(zh.friendRequestsIncoming), findsOneWidget);
      expect(find.text(zh.friendRequestsOutgoing), findsOneWidget);
      expect(find.text('阿明'), findsOneWidget);
      expect(find.text('小華'), findsOneWidget);
      // What a friend shares, under their name
      expect(find.text(zh.timetable), findsWidgets);
      expect(find.text('ABCD 2345'), findsOneWidget);
    });

    testWidgets('accepting makes them a friend; declining asks the server to drop it', (tester) async {
      final fake = FakeFriends(list);
      await pumpScreen(tester, const FriendsScreen(), container: signedIn(fake));
      await tester.scrollUntilVisible(find.text(zh.acceptFriend), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(zh.acceptFriend));
      await tester.pumpAndSettle();
      expect(fake.responded, [('a', true)]);
      expect(find.text(zh.friendRequestsIncoming), findsNothing);
      expect(find.text('阿明'), findsOneWidget, reason: 'now among the friends');

      fake.entries = [entry('d', '靜香', FriendStatus.incoming)];
      await pumpScreen(tester, const FriendsScreen(), container: signedIn(fake));
      await tester.scrollUntilVisible(find.text(zh.declineFriend), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(zh.declineFriend));
      await tester.pumpAndSettle();
      expect(fake.responded.last, ('d', false));
      expect(find.text('靜香'), findsNothing);
    });

    testWidgets('cancelling a request and unfriending ask first', (tester) async {
      final fake = FakeFriends(list);
      await pumpScreen(tester, const FriendsScreen(), container: signedIn(fake));
      await tester.scrollUntilVisible(find.text(zh.cancelFriendRequest), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(zh.cancelFriendRequest));
      await tester.pumpAndSettle();
      expect(find.text(zh.cancelFriendRequestConfirm('小華')), findsOneWidget);
      expect(fake.removed, isEmpty, reason: 'not before the answer');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(zh.cancelFriendRequest)));
      await tester.pumpAndSettle();
      expect(fake.removed, ['b']);

      await tester.scrollUntilVisible(find.byKey(const ValueKey('friendMenu.c')), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('friendMenu.c')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(zh.removeFriend));
      await tester.pumpAndSettle();
      expect(find.text(zh.removeFriendConfirm('大雄')), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(zh.removeFriend)));
      await tester.pumpAndSettle();
      expect(fake.removed, ['b', 'c']);
    });

    testWidgets('a code is taken in any case, with a dash, or inside a pasted link', (tester) async {
      final fake = FakeFriends();
      await pumpScreen(tester, const FriendsScreen(), container: signedIn(fake));
      final field = find.byKey(const ValueKey('friendCodeField'));

      await tester.enterText(field, 'abcd-2345');
      await tester.tap(find.text(zh.sendFriendRequest));
      await tester.pumpAndSettle();
      expect(fake.requested, ['ABCD2345']);
      expect(find.text(zh.friendRequestSent), findsOneWidget);

      await tester.enterText(field, '加我 https://urniversity.netlify.app/invite/WXYZ6789');
      await tester.tap(find.text(zh.sendFriendRequest));
      await tester.pumpAndSettle();
      expect(fake.requested.last, 'WXYZ6789');
    });

    testWidgets('a code that cannot be one is not sent; a refusal says why', (tester) async {
      final fake = FakeFriends();
      await pumpScreen(tester, const FriendsScreen(), container: signedIn(fake));
      final field = find.byKey(const ValueKey('friendCodeField'));

      await tester.enterText(field, 'OOOO1111');
      await tester.tap(find.text(zh.sendFriendRequest));
      await tester.pumpAndSettle();
      expect(fake.requested, isEmpty);
      expect(find.text(zh.friendCodeInvalid), findsOneWidget);

      fake.requestError = const PostgrestException(message: 'already', code: 'P0001');
      ScaffoldMessenger.of(tester.element(field)).hideCurrentSnackBar();
      await tester.enterText(field, 'ABCD2345');
      await tester.tap(find.text(zh.sendFriendRequest));
      await tester.pumpAndSettle();
      expect(find.text(zh.friendAlready), findsOneWidget);
    });

    testWidgets('the three switches start off and save; a failed save moves back', (tester) async {
      final fake = FakeFriends();
      await pumpScreen(tester, const FriendsScreen(), container: signedIn(fake));
      SwitchListTile tile(String key) => tester.widget<SwitchListTile>(find.byKey(ValueKey('share.$key')));
      for (final key in ['timetable', 'rates', 'graph']) {
        await tester.scrollUntilVisible(find.byKey(ValueKey('share.$key')), 200, scrollable: find.byType(Scrollable).first);
        expect(tile(key).value, isFalse, reason: key);
      }

      await tester.scrollUntilVisible(find.byKey(const ValueKey('share.timetable')), -200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('share.timetable')));
      await tester.pumpAndSettle();
      expect(fake.saved.single, const FriendShares(timetable: true));
      expect(tile('timetable').value, isTrue);

      fake.saveError = Exception('offline');
      await tester.tap(find.byKey(const ValueKey('share.timetable')));
      await tester.pumpAndSettle();
      expect(tile('timetable').value, isTrue, reason: 'the write failed, so it is still on');
    });

    for (final width in [360.0, 768.0, 1280.0]) {
      testWidgets('fits at $width wide', (tester) async {
        await pumpScreen(tester, const FriendsScreen(), width: width, container: signedIn(FakeFriends(list)));
        await tester.scrollUntilVisible(find.text('大雄'), 300, scrollable: find.byType(Scrollable).first);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('one friend', () {
    final theirCourse = Course(
      id: 'k1',
      semester: '115-1',
      title: '微積分',
      color: 0xFF4A90C4,
      // Wednesday all day: no free time together then
      sessions: const [CourseSession(weekday: 3, startMinute: 8 * 60, endMinute: 18 * 60)],
      createdAt: DateTime(2000),
    );

    testWidgets('only what they share, and a line when that is nothing', (tester) async {
      final none = entry('c', '大雄', FriendStatus.friend);
      final fake = FakeFriends([none]);
      await pumpScreen(tester, FriendScreen(entry: none), container: signedIn(fake));
      expect(find.text(zh.friendSharesNothing('大雄')), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('their timetable, read only; free time together waits for the user to share too', (tester) async {
      final friend = entry('c', '大雄', FriendStatus.friend, const FriendShares(timetable: true));
      final fake = FakeFriends([friend])..table = FriendTimetable(courses: [theirCourse]);
      await pumpScreen(tester, FriendScreen(entry: friend), width: 1280, container: signedIn(fake));
      expect(find.text('微積分'), findsWidgets);
      expect(find.text(zh.commonFreeTime), findsNothing);
      expect(find.text(zh.commonFreeNeedsYours), findsOneWidget);

      // Nothing to open: not theirs to edit, and not the user's to add to
      await tester.tap(find.text('微積分').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('both sharing: the free times, and "meet then" makes a task', (tester) async {
      final friend = entry('c', '大雄', FriendStatus.friend, const FriendShares(timetable: true));
      final fake = FakeFriends([friend])
        ..table = FriendTimetable(courses: [theirCourse])
        ..shares = const FriendShares(timetable: true);
      final c = signedIn(fake);
      await pumpScreen(tester, FriendScreen(entry: friend), container: c);
      await tester.tap(find.text(zh.commonFreeTime));
      await tester.pumpAndSettle();
      expect(find.text('${zh.weekdayFull(1)} 08:00–18:00'), findsOneWidget);
      expect(find.textContaining(zh.weekdayFull(3)), findsNothing, reason: 'they have class all Wednesday');

      await tester.tap(find.byKey(const ValueKey('meet.1.480')));
      await tester.pumpAndSettle();
      final task = c.read(tasksProvider).singleWhere((t) => t.title == zh.meetTaskTitle('大雄'));
      expect(task.dueTime, nextSlotStart(const FreeSlot(1, 480, 1080), DateTime.now()));
    });

    testWidgets('fits a phone', (tester) async {
      final friend = entry('c', '大雄', FriendStatus.friend, const FriendShares(timetable: true));
      final fake = FakeFriends([friend])
        ..table = FriendTimetable(courses: [theirCourse])
        ..shares = const FriendShares(timetable: true);
      await pumpScreen(tester, FriendScreen(entry: friend), width: 360, container: signedIn(fake));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(zh.commonFreeTime));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('their rates and their graph (7-2)', () {
    void reduceMotion(WidgetTester tester) {
      // The graph's particles never settle otherwise
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Two due today, one of them done: half this week
    final tasks = [
      Task(id: 't1', title: '', dueTime: today.add(const Duration(hours: 23)), isCompleted: true, createdAt: today.subtract(const Duration(days: 30))),
      Task(id: 't2', title: '', dueTime: today.add(const Duration(hours: 23)), createdAt: today.subtract(const Duration(days: 30))),
      // Two weeks back and never done: not this week's to count
      Task(id: 't3', title: '', dueTime: today.subtract(const Duration(days: 14)), createdAt: today.subtract(const Duration(days: 30))),
    ];
    const graph = FriendGraph(
      futures: [FutureGoal(id: 'f1', title: '出國交換', categories: ['exchange'])],
      semesters: [SemesterGoal(id: 's1', title: '多益 800', semester: '115-1', futureGoalId: 'f1')],
      taskCounts: {'s1': 3},
    );

    testWidgets('only the rates shared: that tab alone, with this week and the twelve weeks', (tester) async {
      final friend = entry('c', '大雄', FriendStatus.friend, const FriendShares(rates: true));
      final fake = FakeFriends([friend])..tasks = tasks;
      await pumpScreen(tester, FriendScreen(entry: friend), container: signedIn(fake));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.widgetWithText(Tab, zh.shareRates), findsOneWidget);
      expect(find.widgetWithText(Tab, zh.timetable), findsNothing);
      expect(find.widgetWithText(Tab, zh.overview), findsNothing);
      expect(tester.widget<Text>(find.byKey(const ValueKey('friendRate'))).data, '50%');
      expect(find.text(zh.reviewDoneOf(1, 2)), findsOneWidget);
      expect(find.text(zh.reviewHeatmapTitle), findsOneWidget);
    });

    testWidgets('only the graph shared: their visions and targets, read only', (tester) async {
      reduceMotion(tester);
      final friend = entry('c', '大雄', FriendStatus.friend, const FriendShares(graph: true));
      final fake = FakeFriends([friend])..graphData = graph;
      await pumpScreen(tester, FriendScreen(entry: friend), width: 1280, container: signedIn(fake));
      expect(find.widgetWithText(Tab, zh.overview), findsOneWidget);
      expect(find.widgetWithText(Tab, zh.shareRates), findsNothing);
      expect(find.text('出國交換'), findsOneWidget);
      expect(find.text('多益 800'), findsOneWidget);
      expect(find.text('3'), findsOneWidget, reason: 'the task count on the target');
      // "This semester" judges by the viewer's own semesters: not offered
      expect(find.text(zh.backToCurrentSem), findsNothing);

      await tester.tap(find.text('多益 800'));
      await tester.pumpAndSettle();
      expect(find.text(zh.graphOpen), findsNothing, reason: 'not the viewer\'s to open');
      expect(find.text(zh.graphNextDue), findsNothing, reason: 'their tasks never arrive');
      expect(find.text(zh.tasks), findsWidgets);
    });

    testWidgets('all three shared: four tabs, and each fits a phone', (tester) async {
      reduceMotion(tester);
      final friend = entry('c', '大雄', FriendStatus.friend, const FriendShares(timetable: true, rates: true, graph: true));
      final fake = FakeFriends([friend])
        ..table = const FriendTimetable()
        ..tasks = tasks
        ..graphData = graph
        ..shares = const FriendShares(timetable: true);
      await pumpScreen(tester, FriendScreen(entry: friend), width: 360, container: signedIn(fake));
      expect(find.byType(Tab), findsNWidgets(4));
      for (final tab in [zh.commonFreeTime, zh.shareRates, zh.overview]) {
        await tester.tap(find.widgetWithText(Tab, tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  });

  group('the red dot', () {
    Badge dot(WidgetTester tester, String key) =>
        tester.widget<Badge>(find.descendant(of: find.byKey(ValueKey(key)).first, matching: find.byType(Badge)).first);

    testWidgets('on the Me tab and on 👥 while a request waits', (tester) async {
      await pumpApp(tester, container: signedIn(FakeFriends(list)));
      expect(dot(tester, 'nav.invites').isLabelVisible, isTrue);

      await pumpScreen(tester, const Scaffold(body: MeScreen()), container: signedIn(FakeFriends(list)));
      final friends = find.byKey(const ValueKey('me.friends'));
      expect(tester.widget<Badge>(find.descendant(of: friends, matching: find.byType(Badge))).isLabelVisible, isTrue);
    });

    testWidgets('gone with nothing waiting', (tester) async {
      final calm = [for (final e in list) if (e.status != FriendStatus.incoming) e];
      await pumpApp(tester, container: signedIn(FakeFriends(calm)));
      expect(dot(tester, 'nav.invites').isLabelVisible, isFalse);

      await pumpScreen(tester, const Scaffold(body: MeScreen()), container: signedIn(FakeFriends(calm)));
      final friends = find.byKey(const ValueKey('me.friends'));
      expect(tester.widget<Badge>(find.descendant(of: friends, matching: find.byType(Badge))).isLabelVisible, isFalse);
    });

    testWidgets('the side menu has Friends, with the dot, and it opens the page', (tester) async {
      await pumpApp(tester, container: signedIn(FakeFriends(list)));
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('drawer.friends'));
      expect(entry, findsOneWidget);
      expect(tester.widget<Badge>(find.descendant(of: entry, matching: find.byType(Badge))).isLabelVisible, isTrue);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(FriendsScreen), findsOneWidget);
    });

    for (final width in [900.0, 1280.0]) {
      testWidgets('the rail has Friends at $width wide', (tester) async {
        await pumpApp(tester, width: width, container: signedIn(FakeFriends(list)));
        final entry = find.byKey(const ValueKey('rail.friends'));
        expect(entry, findsOneWidget);
        expect(tester.widget<Badge>(find.descendant(of: entry, matching: find.byType(Badge))).isLabelVisible, isTrue);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(FriendsScreen), findsOneWidget);
      });
    }

    testWidgets('a guest has no Friends in the side menu', (tester) async {
      await pumpApp(tester);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('drawer.friends')), findsNothing);
      await pumpApp(tester, width: 1280);
      expect(find.byKey(const ValueKey('rail.friends')), findsNothing);
    });

    testWidgets('a guest has no 👥 at all', (tester) async {
      await pumpScreen(tester, const Scaffold(body: MeScreen()));
      expect(find.byKey(const ValueKey('me.friends')), findsNothing);
    });
  });

  group('an invite link', () {
    testWidgets('whose code it is, then the request', (tester) async {
      final fake = FakeFriends()..preview = const FriendPreview(userId: 'u9', name: '出木杉');
      await pumpScreen(tester, const InviteAcceptScreen(code: 'abcd2345'), container: signedIn(fake));
      expect(find.text(zh.inviteAddQuestion('出木杉')), findsOneWidget);
      await tester.tap(find.text(zh.sendFriendRequest));
      await tester.pumpAndSettle();
      expect(fake.requested, ['ABCD2345']);
      expect(find.text(zh.friendRequestSentTo('出木杉')), findsOneWidget);
    });

    testWidgets('the user\'s own code', (tester) async {
      final fake = FakeFriends()..preview = const FriendPreview(userId: 'me', name: '我', isSelf: true);
      await pumpScreen(tester, const InviteAcceptScreen(code: 'ABCD2345'), container: signedIn(fake));
      expect(find.text(zh.friendCodeIsYours), findsOneWidget);
    });

    testWidgets('a code nobody has', (tester) async {
      await pumpScreen(tester, const InviteAcceptScreen(code: 'WXYZ6789'), container: signedIn(FakeFriends()));
      expect(find.text(zh.friendCodeNotFound), findsOneWidget);
    });

    testWidgets('a malformed code is not looked up', (tester) async {
      final unused = FakeFriends();
      await pumpScreen(tester, const InviteAcceptScreen(code: 'nope'), container: signedIn(unused));
      expect(find.text(zh.friendCodeNotFound), findsOneWidget);
      expect(unused.requested, isEmpty);
    });

    testWidgets('a guest is asked to make an account first', (tester) async {
      await pumpScreen(tester, const InviteAcceptScreen(code: 'ABCD2345'));
      expect(find.text(zh.friendsGuestPrompt), findsOneWidget);
    });
  });
}
