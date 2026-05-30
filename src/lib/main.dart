import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/guest_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

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
    if (ref.watch(guestModeProvider)) return const HomeScreen();
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () {
        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? const HomeScreen() : const LoginScreen();
      },
      error: (_, _) => const LoginScreen(),
      data: (state) => state.session != null ? const HomeScreen() : const LoginScreen(),
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
