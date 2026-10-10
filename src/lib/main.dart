import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_routes.dart';
import 'core/config.dart';
import 'core/theme/app_motion.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_styles.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_strings.dart';
import 'providers/admin_provider.dart';
import 'providers/app_style_provider.dart';
import 'providers/auth_link_error_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/auth_status_provider.dart';
import 'providers/date_provider.dart';
import 'providers/guest_provider.dart';
import 'providers/future_goals_provider.dart';
import 'providers/home_widget_provider.dart';
import 'providers/notification_action_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/semester_goals_provider.dart';
import 'providers/tasks_provider.dart';
import 'screens/future_goal_detail_screen.dart';
import 'screens/future_screen.dart';
import 'screens/semester_goal_detail_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/today_screen.dart';
import 'providers/password_recovery_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/remote_config_provider.dart';
import 'providers/reviews_provider.dart';
import 'screens/review_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/realtime_sync.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/maintenance_screen.dart';
import 'widgets/coach_mark.dart';
import 'widgets/style_crossfade.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_profile_screen.dart';
import 'screens/admin_screen.dart';
import 'widgets/app_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Addresses without "#/" on the web (/tasks, not /#/tasks), and a page
  // pushed on top of a tab gets its own address too (CLAUDE.md §13)
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  // Before anything is drawn: even the wait screen wears the style, matching
  // the system splash, and a random launch is drawn exactly once
  await preloadAppStyle();
  AppColors.use(kStylePalettes[launchStyle]!);
  // Paint first, connect second: the branded wait screen carries the app name,
  // which the Android 12 splash API cannot draw, and it picks up exactly where
  // the native splash leaves off
  runApp(const _Bootstrap());
}

Future<void> _startUp() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  await preloadGuestMode();
  // Same reason as guest mode: read before the first frame, or HomeScreen's
  // first build sees a chapter as unseen and starts it for someone who has
  // already been through it
  await preloadOnboarding();
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  // Held in state, not rebuilt: a FutureBuilder that re-ran this would
  // initialize Supabase twice
  late final Future<void> _ready = _startUp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      // The wait screen dissolves into the app instead of cutting to it
      builder: (context, snapshot) => AnimatedSwitcher(
        duration: AppMotion.page,
        switchInCurve: AppMotion.enterCurve,
        child: snapshot.connectionState != ConnectionState.done
            ? const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: SplashScreen(),
              )
            : const ProviderScope(child: App()),
      ),
    );
  }
}

// Lets the auth-link listener below show a message from outside any Scaffold,
// so it reaches the user whether _AuthGate landed them on the login screen or,
// as a guest, on the home screen
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

// The task edit sheet is a modal route, so opening it from a notification needs
// a context below the Navigator rather than App's own
final _navigatorKey = GlobalKey<NavigatorState>();

final _crossfadeKey = GlobalKey<StyleCrossfadeState>();

// Every widget reads AppColors directly rather than through Theme.of, so a new
// style reaches only what happens to rebuild. Marking every element dirty
// rebuilds the lot in one frame without recreating any State — the navigation
// stack, scroll positions and open sheets all stay where they were
void _rebuildEverything() {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  // Made once: a new router on every build would forget where the user is
  final _routerRefresh = ValueNotifier<int>(0);
  late final GoRouter _router = _buildRouter(ref, _routerRefresh);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _routerRefresh.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Being away for hours is the other way the day changes under the app; the
    // midnight timer only covers the case where it stayed open
    if (lifecycle == AppLifecycleState.resumed) {
      ref.read(effectiveNowProvider.notifier).refresh();
      // And whatever other devices changed meanwhile (§3-I)
      ref.read(liveSyncProvider)
        ..setForeground(true)
        ..refreshAll(minGap: kResumeRefreshGap);
    } else if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.hidden) {
      ref.read(liveSyncProvider).setForeground(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncProvider);
    ref.watch(liveSyncProvider);
    // Signing in or out, or a stored session settling, moves the router
    ref.listen<AuthStatus>(authStatusProvider, (_, _) => _routerRefresh.value++);
    ref.listen<bool>(passwordRecoveryProvider, (_, _) => _routerRefresh.value++);

    // The style is applied here, above everything that reads it: App is the
    // shallowest dirty element, so it rebuilds first in the frame
    final palette = kStylePalettes[ref.watch(appStyleProvider)]!;
    AppColors.use(palette);
    ref.listen<AppStyle>(appStyleProvider, (_, _) {
      // The screen still shows the old style at this point
      _crossfadeKey.currentState?.snapshot();
      _rebuildEverything();
    });

    // When the day rolls over, the date being shown follows it — unless the
    // user has browsed to some other day, which rollOverTo() leaves alone
    ref.listen<DateTime>(effectiveNowProvider,
        (_, now) => ref.read(dateProvider.notifier).rollOverTo(now));
    ref.watch(authLinkWatcherProvider);
    // Keeps the device's pending reminders in step with the task and goal data
    ref.watch(notificationSyncProvider);
    ref.watch(notificationActionProvider);
    // Keeps the home screen widget in step with the data, and routes the taps
    // on it that open the app
    ref.watch(homeWidgetSyncProvider);
    ref.watch(homeWidgetLaunchProvider);
    final lang = ref.watch(languageProvider);
    final s = ref.watch(stringsProvider);

    // A reset link signs the user in with a recovery session. Catch the event
    // here so _AuthGate can send them to set a password instead of the home page
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryProvider.notifier).state = true;
      }
      // supabase_flutter subscribes to this stream with an empty onError, so a
      // failed code exchange dies there unless it is picked up here
      final failure = next.error == null
          ? null
          : authLinkFailureFromError(next.error!);
      if (failure != null) {
        ref.read(authLinkErrorProvider.notifier).state = failure;
      }
    });

    // A dead reset link used to leave the user on an ordinary login screen with
    // nothing said, and on Android with no address bar to even read the error
    ref.listen<AuthLinkFailure?>(authLinkErrorProvider, (_, failure) {
      if (failure == null) return;
      final message = switch (failure) {
        AuthLinkFailure.expired => s.resetLinkInvalid,
        AuthLinkFailure.wrongDevice => s.resetLinkWrongDevice,
      };
      // Deferred for two reasons: the messenger does not exist yet during the
      // first build, and clearing the provider here would be a write during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
        );
        ref.read(authLinkErrorProvider.notifier).state = null;
      });
    });

    // Something the user asked to open from a notification or the home screen
    // widget. Deliberately watched rather than listened to: on a cold start the
    // id arrives before the rows do, so this rebuilds until the item exists and
    // only then navigates
    _handlePendingOpen(ref);

    return MaterialApp.router(
      routerConfig: _router,
      scaffoldMessengerKey: _messengerKey,
      title: 'URniversity',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(palette),
      builder: (context, child) => StyleCrossfade(key: _crossfadeKey, child: child!),
      locale: _localeFor(lang),
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
    );
  }
}

// Every address, and what it shows (CLAUDE.md §13). Signed out, every address
// but /login goes there, carrying where it was headed (?from=); signed in, or
// as a guest, /login goes back there. [refresh] fires on every change of
// authStatusProvider, which is when these are worked out again. Anything
// unknown — a mistyped address, or a sign-in deep link on Android, which the
// router is handed too — lands on the tasks
GoRouter _buildRouter(WidgetRef ref, Listenable refresh) {
  const pages = {AppRoutes.timetable, AppRoutes.grades, AppRoutes.settings, AppRoutes.admin};
  return GoRouter(
    navigatorKey: _navigatorKey,
    // Lets the first-run tour follow the user into sheets and pages
    observers: [tourRouteObserver],
    initialLocation: AppRoutes.tasks,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final known = AppRoutes.tabs.contains(path) || pages.contains(path) || path == AppRoutes.login;
      if (!known) return AppRoutes.tasks;
      // A reset link wins over everything: _AuthGate shows the password page
      // wherever the user is, so never send them to /login meanwhile
      if (ref.read(passwordRecoveryProvider)) return path == AppRoutes.login ? AppRoutes.tasks : null;
      final status = ref.read(authStatusProvider);
      if (path == AppRoutes.login) {
        if (status != AuthStatus.signedIn) return null;
        final from = state.uri.queryParameters['from'];
        return from != null && from.startsWith('/') && !from.startsWith(AppRoutes.login) ? from : AppRoutes.tasks;
      }
      if (status == AuthStatus.signedOut) {
        return Uri(path: AppRoutes.login, queryParameters: {'from': state.uri.toString()}).toString();
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => _titled((s) => s.login, const LoginScreen())),
      GoRoute(
        path: AppRoutes.timetable,
        pageBuilder: (_, state) => GesturePage(key: state.pageKey, child: _titled((s) => s.timetable, const _AuthGate(child: TimetableScreen()))),
      ),
      GoRoute(
        path: AppRoutes.grades,
        pageBuilder: (_, state) => GesturePage(key: state.pageKey, child: _titled((s) => s.grades, const _AuthGate(child: TimetableScreen(grades: true)))),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (_, state) => GesturePage(key: state.pageKey, child: _titled((s) => s.settings, const _AuthGate(child: SettingsScreen()))),
      ),
      // Anyone can open the address; AdminScreen shows nothing to a non-admin
      GoRoute(
        path: AppRoutes.admin,
        pageBuilder: (_, state) => GesturePage(key: state.pageKey, child: _titled((s) => s.adminTitle, const _AuthGate(child: AdminScreen()))),
      ),
      // The four tabs are one page under one key, so moving between them keeps
      // HomeScreen — its tab state, scroll positions, dragged buttons — and
      // only tells it which tab to show
      GoRoute(
        path: '/:tab',
        pageBuilder: (_, state) {
          final tab = AppRoutes.tabs.indexOf(state.uri.path);
          return NoTransitionPage(
            key: const ValueKey('home'),
            child: _titled(
              (s) => [s.tasks, s.targets, s.goals, s.me][tab],
              _AuthGate(child: HomeScreen(tab: tab)),
            ),
          );
        },
      ),
    ],
  );
}

// The browser tab's title on the web, "任務 · URniversity", in the app's language
Widget _titled(String Function(AppStrings s) name, Widget child) => Consumer(
      builder: (context, ref, _) => Title(
        title: '${name(ref.watch(stringsProvider))} · URniversity',
        color: AppColors.primary,
        child: child,
      ),
    );

class _AuthGate extends ConsumerWidget {
  // What this address shows once the user is in: a tab of HomeScreen, or a page
  final Widget child;
  const _AuthGate({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Checked first: opening a reset link while browsing as a guest must still
    // land on the password screen
    if (ref.watch(passwordRecoveryProvider)) return const ResetPasswordScreen();

    // Not yet known whether a stored, expired session still holds: the wait
    // screen rather than a page that may be taken away a moment later. Signed
    // out, the router is about to move to /login; this covers the frame before
    final status = ref.watch(authStatusProvider);
    if (status != AuthStatus.signedIn) return const SplashScreen();

    if (!ref.watch(guestModeProvider)) {
      // Profile null = still loading; show the page to avoid a flash for
      // returning users. Email users with no username get the one-time setup
      final profile = ref.watch(profileProvider);
      final user = ref.watch(currentUserProvider);
      final provider = user?.appMetadata['provider'] as String? ?? 'email';
      if (profile != null && provider != 'google' && (profile.username == null || profile.username!.isEmpty)) {
        return const SetupProfileScreen();
      }
    }

    // Maintenance mode (admin backend) stands in for every page, but not for
    // the login page: an admin signs in there and is let through
    final maintenance = ref.watch(remoteConfigProvider).maintenance && !(ref.watch(isAdminProvider).value ?? false);
    return maintenance ? const MaintenanceScreen() : child;
  }
}

// Returns once the named item has loaded and its destination has been opened.
// Doing nothing while the data is still arriving is the point: a cold start
// would otherwise find no match and drop the request
void _handlePendingOpen(WidgetRef ref) {
  final pending = ref.watch(pendingOpenProvider);
  if (pending == null) return;

  void open(void Function(BuildContext context) navigate) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = _navigatorKey.currentContext;
      ref.read(pendingOpenProvider.notifier).state = null;
      if (navContext != null) navigate(navContext);
    });
  }

  switch (pending.kind) {
    case 'task':
      final task =
          ref.watch(tasksProvider).where((t) => t.id == pending.id).firstOrNull;
      if (task != null) {
        open((ctx) => showTaskSheet(ctx, ref, existing: task));
      }

    case 'semesterGoal':
      final exists = ref
          .watch(semesterGoalsProvider)
          .any((g) => g.id == pending.id);
      if (exists) {
        open((ctx) => Navigator.push(
              ctx,
              AppPageRoute(
                builder: (_) => SemesterGoalDetailScreen(goalId: pending.id),
              ),
            ));
      }

    case 'futureGoal':
      final exists =
          ref.watch(futureGoalsProvider).any((g) => g.id == pending.id);
      if (exists) {
        open((ctx) => Navigator.push(
              ctx,
              AppPageRoute(
                builder: (_) => FutureGoalDetailScreen(goalId: pending.id),
              ),
            ));
      }

    // The widget's + button. Nothing to wait for here: the sheet creates the
    // row, so it can open as soon as the navigator exists
    case 'newTask':
      open((ctx) => showTaskSheet(ctx, ref));

    case 'newSemesterGoal':
      open((ctx) => showSemesterGoalSheet(ctx, ref));

    case 'newFutureGoal':
      open((ctx) => showFutureGoalSheet(ctx, ref));

    // A class on the widget, or its + on the classes tab
    case 'timetable':
    case 'newCourse':
      // The timetable switched off from the admin backend: nothing to open
      if (!ref.read(featureOnProvider('timetable'))) {
        ref.read(pendingOpenProvider.notifier).state = null;
      } else {
        open((ctx) => GoRouter.of(ctx).push(AppRoutes.timetable));
      }

    // The Sunday reminder. Opens whichever review is due; if it was already
    // done from another device, there is nothing to open and the request ends
    case 'review':
      final window = ref.read(dueReviewProvider);
      if (window == null) {
        ref.read(pendingOpenProvider.notifier).state = null;
      } else {
        open((ctx) => Navigator.push(
              ctx,
              AppPageRoute(builder: (_) => ReviewScreen(window: window)),
            ));
      }

    default:
      // An unknown kind would otherwise stay pending forever, rebuilding
      ref.read(pendingOpenProvider.notifier).state = null;
  }
}

Locale _localeFor(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.zhTw:
      return const Locale('zh', 'TW');
    case AppLanguage.en:
      return const Locale('en');
    case AppLanguage.jp:
      return const Locale('ja');
  }
}
