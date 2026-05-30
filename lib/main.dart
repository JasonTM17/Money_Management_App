import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        .maybeWhen(data: (mode) => mode, orElse: () => ThemeMode.system);
    return MaterialApp(
      title: 'CashFlow Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const PrivacyGate(child: HomeScreen()),
    );
  }
}
