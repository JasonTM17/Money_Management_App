import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_localizations.dart';
import 'app/app_theme.dart';
import 'features/auth/privacy_gate.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: CashFlowManagerApp()));
}

class CashFlowManagerApp extends ConsumerWidget {
  const CashFlowManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref
        .watch(themeModeControllerProvider)
        .maybeWhen(data: (mode) => mode, orElse: () => ThemeMode.light);
    final locale = ref
        .watch(localeControllerProvider)
        .maybeWhen(data: (locale) => locale, orElse: () => const Locale('vi'));
    return MaterialApp(
      title: 'CashFlow Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const PrivacyGate(child: HomeScreen()),
    );
  }
}
