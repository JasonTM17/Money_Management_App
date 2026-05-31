import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale>(LocaleController.new);

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    try {
      final value = await ref.read(secureStorageProvider).read(key: _key);
      return _themeModeFromName(value);
    } on Object {
      return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      await ref.read(secureStorageProvider).write(key: _key, value: mode.name);
    } on Object {
      // Platform storage may be unavailable in widget tests.
    }
    state = AsyncData(mode);
  }
}

class LocaleController extends AsyncNotifier<Locale> {
  static const _key = 'locale';

  @override
  Future<Locale> build() async {
    try {
      final value = await ref.read(secureStorageProvider).read(key: _key);
      return _localeFromCode(value);
    } on Object {
      return const Locale('vi');
    }
  }

  Future<void> setLocale(Locale locale) async {
    try {
      await ref
          .read(secureStorageProvider)
          .write(key: _key, value: locale.languageCode);
    } on Object {
      // Platform storage may be unavailable in widget tests.
    }
    state = AsyncData(_localeFromCode(locale.languageCode));
  }
}

ThemeMode _themeModeFromName(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

Locale _localeFromCode(String? value) => switch (value) {
  'en' => const Locale('en'),
  'ja' => const Locale('ja'),
  _ => const Locale('vi'),
};

class AppTheme {
  static const seed = Color(0xFF16A34A);
  static const deepSlate = Color(0xFF051424);
  static const surfaceSlate = Color(0xFF0B1F34);
  static const cardSlate = Color(0xFF102A43);
  static const lightSurface = Color(0xFFF3F7F5);
  static const lightPanel = Color(0xFFFFFFFF);
  static const incomeBlue = Color(0xFF3B82F6);
  static const warningAmber = Color(0xFFF59E0B);
  static const expenseRed = Color(0xFFEF4444);

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      primary: seed,
      secondary: incomeBlue,
      tertiary: warningAmber,
      error: expenseRed,
      surface: isDark ? deepSlate : lightSurface,
      surfaceContainerHighest: isDark ? cardSlate : lightPanel,
    );
    final textTheme = ThemeData(brightness: brightness).textTheme.apply(
      fontFamily: 'Noto Sans JP',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Noto Sans JP',
      scaffoldBackgroundColor: isDark ? deepSlate : lightSurface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: seed.withValues(alpha: 0),
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: isDark
            ? cardSlate.withValues(alpha: 0.72)
            : lightPanel.withValues(alpha: 0.86),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.055)
                : scheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : seed.withValues(alpha: 0.08),
        selectedColor: seed.withValues(alpha: 0.16),
        disabledColor: scheme.onSurface.withValues(alpha: 0.08),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : scheme.outlineVariant.withValues(alpha: 0.36),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(0, 46)),
          visualDensity: VisualDensity.comfortable,
          textStyle: WidgetStateProperty.all(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary.withValues(alpha: 0.72)
                  : scheme.outlineVariant.withValues(alpha: 0.58),
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surfaceSlate : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        filled: true,
        fillColor: isDark
            ? surfaceSlate.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.9),
      ),
      listTileTheme: ListTileThemeData(
        minLeadingWidth: 34,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? surfaceSlate.withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.94),
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.15,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.16 : 0.45),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant.withValues(alpha: 0.35),
      ),
    );
  }
}
