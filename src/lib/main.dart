import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/guest_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/auth/login_screen.dart';
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

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncProvider);
    final lang = ref.watch(languageProvider);

    return MaterialApp(
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
