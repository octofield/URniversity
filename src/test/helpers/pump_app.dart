import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urniversity/core/config.dart';
import 'package:urniversity/core/theme/app_theme.dart';
import 'package:urniversity/main.dart';
import 'package:urniversity/providers/guest_provider.dart';
import 'package:urniversity/providers/onboarding_provider.dart';
import 'package:urniversity/providers/settings_provider.dart';
import 'package:urniversity/widgets/coach_mark.dart';

// Guest mode never reaches Supabase — SyncedListNotifier.upsert() returns right
// after persistLocally() — so a widget test can drive the real screens with no
// network and no stubs.
//
// Supabase still has to be initialised because providers read
// Supabase.instance.client eagerly. EmptyLocalStorage keeps it from touching
// storage and detectSessionInUri: false keeps the deep link observer from
// starting, so nothing here reaches the network. initialize() is idempotent,
// so calling this from every setUp is safe
// seenTour defaults to true: a tour chapter puts a scrim over HomeScreen that
// blocks every tap outside its highlight, so a test pumping the app would be
// driving the tour instead of the screen it means to test. Only the tour's own
// tests ask for the first-run state
Future<void> setUpTestSupabase({bool guest = true, bool seenTour = true}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The midnight roll-over timer would still be pending when a test ends, which
  // fails the test. untilNextDay() is covered by its own unit test instead
  EffectiveNowNotifier.autoRollOver = false;
  SharedPreferences.setMockInitialValues({
    if (guest) 'is_guest_mode': true,
    if (seenTour) 'onboarding_done': kTourChapters,
  });
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      detectSessionInUri: false,
    ),
  );
  // Sets a library-private global that guestModeProvider seeds itself from;
  // setting the SharedPreferences key alone is not enough
  await preloadGuestMode();
  await preloadOnboarding();
}

// Widget tests share one view, so a size set in one test leaks into the next
// unless it is reset. Height is generous so lists do not overflow and turn a
// layout assertion into a RenderFlex error
void setViewWidth(WidgetTester tester, double width, {double height = 1600}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
}

// Builds a container the tests can seed before the first frame. The detail
// screens pop themselves when their goal is missing, so their data has to exist
// before they are pumped, and addGoal() mints the id itself
ProviderContainer testContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

// Wraps a screen the way main.dart does. Without the l10n delegates any
// MaterialLocalizations.of() in the tree throws, which most screens hit through
// AlertDialog and friends
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  double width = 400,
  Locale locale = const Locale('zh', 'TW'),
  List<Override> overrides = const [],
  ProviderContainer? container,
  // The overview graph animates its edges forever, so nothing ever settles
  // there; those tests pump a fixed number of frames instead
  bool settle = true,
}) async {
  setViewWidth(tester, width);
  final scope = container ?? testContainer(overrides: overrides);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: scope,
      child: MaterialApp(
        theme: appTheme,
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'TW'),
          Locale('en'),
          Locale('ja'),
        ],
        home: screen,
        navigatorObservers: [tourRouteObserver],
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return scope;
}

// For the routing that only _AuthGate decides. It is private, so the gate can
// only be reached by pumping App itself, which brings its own MaterialApp.
//
// Seed data through the returned container, not before the call: App watches
// syncProvider, which calls loadGuest() on every list provider and replaces
// their state with what SharedPreferences holds
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  double width = 400,
  ProviderContainer? container,
}) async {
  setViewWidth(tester, width);
  final scope = container ?? testContainer();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: scope, child: const App()),
  );
  await tester.pumpAndSettle();
  return scope;
}
