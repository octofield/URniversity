import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_link_error_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/guest_provider.dart';
import 'providers/password_recovery_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/setup_profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  await preloadGuestMode();
  runApp(const ProviderScope(child: App()));
}

// Lets the auth-link listener below show a message from outside any Scaffold,
// so it reaches the user whether _AuthGate landed them on the login screen or,
// as a guest, on the home screen
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncProvider);
    ref.watch(authLinkWatcherProvider);
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

    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      title: 'URniversity',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
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
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Checked before guest mode: opening a reset link while browsing as a guest
    // must still land on the password screen
    if (ref.watch(passwordRecoveryProvider)) return const ResetPasswordScreen();

    final isGuest = ref.watch(guestModeProvider);
    if (isGuest) {
      return ref.watch(pendingGuestLoginProvider) ? const LoginScreen() : const HomeScreen();
    }

    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () {
        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? const HomeScreen() : const LoginScreen();
      },
      error: (_, _) => const LoginScreen(),
      data: (authData) {
        if (authData.session == null) return const LoginScreen();

        // Profile null = still loading; show HomeScreen to avoid flash for returning users.
        final profile = ref.watch(profileProvider);
        if (profile == null) return const HomeScreen();

        // Email users with no username get the one-time setup screen.
        final user = ref.watch(currentUserProvider);
        final provider = user?.appMetadata['provider'] as String? ?? 'email';
        if (provider != 'google' && (profile.username == null || profile.username!.isEmpty)) {
          return const SetupProfileScreen();
        }

        return const HomeScreen();
      },
    );
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
