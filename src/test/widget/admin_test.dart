import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urniversity/l10n/strings_zh_tw.dart';
import 'package:urniversity/providers/admin_provider.dart';
import 'package:urniversity/providers/grade_settings_provider.dart';
import 'package:urniversity/providers/remote_config_provider.dart';
import 'package:urniversity/screens/admin_screen.dart';
import 'package:urniversity/screens/home_screen.dart';
import 'package:urniversity/screens/maintenance_screen.dart';
import 'package:urniversity/screens/settings_screen.dart';
import 'package:urniversity/screens/timetable_screen.dart';
import 'package:urniversity/widgets/swipe_switcher.dart';

import '../helpers/pump_app.dart';

class _FakeAdmin implements AdminSource {
  final bool admin;
  final List<(String, bool)> disabled = [];
  _FakeAdmin({this.admin = true});

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<AdminStats> stats() async => const AdminStats(
        users: 42,
        usersToday: 3,
        dau: 7,
        wau: 19,
        mau: 30,
        features: {'tasks': FeatureUsage(total: 900, users: 35)},
        styles: {'linen': 20, 'midnight': 22},
        languages: {'zh_tw': 40, 'en': 2},
        creditCategories: 5,
        errorGroups: [ErrorGroup(where: 'courses upsert', code: '23514', count: 4)],
      );

  @override
  Future<List<AdminUser>> users(String search, int page) async => [
        AdminUser(id: 'u1', email: 'someone@example.com', createdAt: DateTime(2026, 9, 1), school: '國立臺灣大學'),
      ];

  @override
  Future<void> setDisabled(String userId, bool disabled) async => this.disabled.add((userId, disabled));
}

// The admin backend (UC21–UC22) and what it controls in everyone's app:
// feature switches, the announcement, maintenance mode
void main() {
  const zh = StringsZhTw();
  setUp(() => setUpTestSupabase());

  RemoteConfig off(String feature) => RemoteConfig(flags: {feature: false});

  group('feature switches', () {
    testWidgets('all on by default: the timetable is in the side menu', (tester) async {
      await pumpApp(tester);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      expect(find.text(zh.timetable), findsWidgets);
    });

    testWidgets('timetable off: no card, no side-menu entry', (tester) async {
      await pumpApp(tester, container: testContainer(remoteConfig: off('timetable')));
      expect(find.text(zh.timetable), findsNothing);
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      expect(find.text(zh.timetable), findsNothing);
    });

    testWidgets('templates off: no templates button on the targets tab', (tester) async {
      await pumpApp(tester, container: testContainer(remoteConfig: off('goal_templates')));
      await tester.tap(find.byIcon(Icons.school_outlined));
      await tester.pumpAndSettle();
      expect(find.byTooltip(zh.goalTemplates), findsNothing);
    });

    testWidgets('catalog search off: Add course goes straight to adding by hand', (tester) async {
      await pumpScreen(tester, const TimetableScreen(), container: testContainer(remoteConfig: off('catalog_search')));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text(zh.searchCourseHint), findsNothing);
      expect(find.widgetWithText(TextField, zh.courseTitle), findsOneWidget);
    });

    testWidgets('credits by category off: not offered, and a user\'s own choice waits', (tester) async {
      final c = testContainer(remoteConfig: off('credit_categories'));
      await c.read(gradeSettingsProvider.notifier).set(const GradeSettings(categoriesEnabled: true));
      await pumpScreen(tester, const SettingsScreen(), container: c);
      expect(find.text(zh.creditCategories), findsNothing);
      expect(c.read(creditCategoriesActiveProvider), isFalse);
      expect(c.read(gradeSettingsProvider).categoriesEnabled, isTrue, reason: 'kept for when it comes back');
    });

    testWidgets('an unreachable source leaves the last copy on the device in force', (tester) async {
      final c = testContainer(remoteConfig: off('timetable'));
      await pumpApp(tester, container: c);
      final saved = (await SharedPreferences.getInstance()).getString(RemoteConfigNotifier.cacheKey);
      expect(saved, contains('"timetable":false'));

      // Next launch, offline
      final offline = testContainer(overrides: [remoteConfigSourceProvider.overrideWithValue(_Unreachable())]);
      await pumpApp(tester, container: offline);
      expect(offline.read(featureOnProvider('timetable')), isFalse);
    });
  });

  group('announcement', () {
    RemoteConfig announcing({required DateTime from, required DateTime until}) => RemoteConfig(
          announcement: Announcement(id: 'a1', text: '今晚 23:00 停機維護', startsAt: from, endsAt: until),
        );

    testWidgets('shows while it runs, and stays gone once dismissed', (tester) async {
      final now = DateTime.now();
      final config = announcing(from: now.subtract(const Duration(days: 1)), until: now.add(const Duration(days: 1)));
      await pumpApp(tester, container: testContainer(remoteConfig: config));
      expect(find.text('今晚 23:00 停機維護'), findsOneWidget);

      await tester.tap(find.byTooltip(zh.dismissAnnouncement));
      await tester.pumpAndSettle();
      expect(find.text('今晚 23:00 停機維護'), findsNothing);
      expect((await SharedPreferences.getInstance()).getString('dismissed_announcement'), 'a1');
    });

    testWidgets('not before it starts or after it ends', (tester) async {
      final now = DateTime.now();
      final config = announcing(from: now.subtract(const Duration(days: 3)), until: now.subtract(const Duration(days: 1)));
      await pumpApp(tester, container: testContainer(remoteConfig: config));
      expect(find.text('今晚 23:00 停機維護'), findsNothing);
    });
  });

  group('maintenance', () {
    const maintenance = RemoteConfig(maintenance: true, maintenanceMessage: '升級資料庫中');

    testWidgets('everyone but admins sees only the maintenance screen', (tester) async {
      await pumpApp(tester, container: testContainer(remoteConfig: maintenance));
      expect(find.byType(MaintenanceScreen), findsOneWidget);
      expect(find.text('升級資料庫中'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('an admin is let through', (tester) async {
      await pumpApp(tester,
          container: testContainer(
            remoteConfig: maintenance,
            overrides: [isAdminProvider.overrideWith((ref) async => true)],
          ));
      expect(find.byType(MaintenanceScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  // The way in sits in the side menu, under the timetable, for admins only
  // (moved from Settings, 2026-10-04)
  group('the entry', () {
    ProviderContainer as(bool admin) => testContainer(overrides: [
          adminSourceProvider.overrideWithValue(_FakeAdmin(admin: admin)),
          isAdminProvider.overrideWith((ref) async => admin),
        ]);

    testWidgets('an admin finds it in the drawer, and it opens', (tester) async {
      await pumpApp(tester, width: 360, container: as(true));
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text(zh.adminTitle)));
      await tester.pumpAndSettle();
      expect(find.byType(AdminScreen), findsOneWidget);
    });

    testWidgets('on a wide screen it is in the rail, labelled or as an icon', (tester) async {
      await pumpApp(tester, width: 1280, container: as(true));
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.text(zh.adminTitle)), findsOneWidget);
      setViewWidth(tester, 900);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(NavigationRail), matching: find.byTooltip(zh.adminTitle)), findsOneWidget);
    });

    testWidgets('anyone else sees no trace of it, and Settings no longer has it', (tester) async {
      await pumpApp(tester, width: 360, container: as(false));
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
      expect(find.text(zh.adminTitle), findsNothing);

      await pumpScreen(tester, const SettingsScreen(), container: as(true));
      expect(find.text(zh.adminTitle), findsNothing);
    });
  });

  group('the backend', () {
    Future<ProviderContainer> openAdmin(WidgetTester tester, _FakeAdmin fake, {double width = 400}) =>
        pumpScreen(tester, const AdminScreen(),
            width: width,
            container: testContainer(overrides: [
              adminSourceProvider.overrideWithValue(fake),
              isAdminProvider.overrideWith((ref) async => fake.admin),
            ]));

    testWidgets('a non-admin sees nothing but that', (tester) async {
      await openAdmin(tester, _FakeAdmin(admin: false));
      expect(find.text(zh.adminNoAccess), findsOneWidget);
      expect(find.text(zh.adminTabOverview), findsNothing);
    });

    testWidgets('the overview has the numbers', (tester) async {
      await openAdmin(tester, _FakeAdmin());
      expect(find.text('42'), findsOneWidget);
      expect(find.text(zh.adminDau), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text(zh.adminGuestsNote), findsOneWidget);
    });

    testWidgets('on a phone a swipe moves between sections, and the tab strip follows', (tester) async {
      await openAdmin(tester, _FakeAdmin());
      await tester.fling(find.byType(SwipeSwitcher), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(find.text(zh.adminUsage(900, 35)), findsOneWidget, reason: 'the usage section');
      expect(DefaultTabController.maybeOf(tester.element(find.byType(TabBar))), isNull);
      final strip = tester.widget<TabBar>(find.byType(TabBar));
      expect(strip.controller!.index, 1);

      await tester.fling(find.byType(SwipeSwitcher), const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(find.text(zh.adminDau), findsOneWidget, reason: 'back on the overview');
    });

    testWidgets('the sections stay clear of the phone\'s navigation bar', (tester) async {
      await openAdmin(tester, _FakeAdmin());
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byWidgetPredicate((w) => w is SafeArea && !w.top && w.bottom),
        ),
        findsOneWidget,
      );
    });

    testWidgets('settings and errors: styles, languages and where it fails', (tester) async {
      await openAdmin(tester, _FakeAdmin(), width: 1280);
      await tester.tap(find.text(zh.adminTabSettings));
      await tester.pumpAndSettle();
      expect(find.text(zh.adminCreditCategoriesOn(5)), findsOneWidget);
      expect(find.text('courses upsert  23514'), findsOneWidget);
    });

    testWidgets('controls: a switch saved reaches the remote settings', (tester) async {
      final c = await openAdmin(tester, _FakeAdmin(), width: 1280);
      await tester.tap(find.text(zh.adminTabControls));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, zh.featureTimetable));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, zh.save));
      await tester.pumpAndSettle();
      expect(c.read(featureOnProvider('timetable')), isFalse);
    });

    testWidgets('pulled down, the backend closes like any page (§3-Q)', (tester) async {
      await pumpScreen(
        tester,
        Builder(builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
              child: const Text('open'),
            ),
          ),
        )),
        container: testContainer(overrides: [
          adminSourceProvider.overrideWithValue(_FakeAdmin()),
          isAdminProvider.overrideWith((ref) async => true),
        ]),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.drag(find.text(zh.adminDau), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.byType(AdminScreen), findsNothing);
    });

    testWidgets('an account is disabled only after confirming', (tester) async {
      final fake = _FakeAdmin();
      await openAdmin(tester, fake, width: 1280);
      await tester.tap(find.text(zh.adminTabUsers));
      await tester.pumpAndSettle();
      expect(find.text('someone@example.com'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, zh.adminDisable));
      await tester.pumpAndSettle();
      expect(fake.disabled, isEmpty, reason: 'not before confirming');
      await tester.tap(find.widgetWithText(FilledButton, zh.adminDisable));
      await tester.pumpAndSettle();
      expect(fake.disabled, [('u1', true)]);
    });
  });
}

class _Unreachable implements RemoteConfigSource {
  @override
  Future<RemoteConfig?> fetch() async => throw Exception('offline');

  @override
  Future<void> save(RemoteConfig config, String updatedBy) async => throw Exception('offline');
}
