import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      home: const HomeScreen(),
    );
  }
}

Locale _localeFor(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.zhTw: return const Locale('zh', 'TW');
    case AppLanguage.en:   return const Locale('en');
    case AppLanguage.jp:   return const Locale('ja');
  }
}
