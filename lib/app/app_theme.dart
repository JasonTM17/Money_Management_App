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
      return ThemeMode.dark;
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
  'system' => ThemeMode.system,
  _ => ThemeMode.dark,
};

Locale _localeFromCode(String? value) => switch (value) {
  'en' => const Locale('en'),
  'ja' => const Locale('ja'),
  _ => const Locale('vi'),
};

class AppTheme {
  static const fontFamily = 'Be Vietnam Pro';
  static const fontFallback = ['Noto Sans JP'];

  static const seed = Color(0xFF16A34A);
  static const stitchPrimary = Color(0xFF62DF7D);
  static const deepSlate = Color(0xFF051424);
  static const surfaceSlate = Color(0xFF0D1C2D);
  static const cardSlate = Color(0xFF122131);
  static const elevatedSlate = Color(0xFF1C2B3C);
  static const lightSurface = Color(0xFFF8FAFC);
  static const lightPanel = Color(0xFFFFFFFF);
  static const incomeBlue = Color(0xFF3B82F6);
  static const warningAmber = Color(0xFFF59E0B);
  static const expenseRed = Color(0xFFEF4444);

  static const controlRadius = 8.0;
  static const cardRadius = 16.0;
  static const sheetRadius = 16.0;
  static const bottomNavigationHeight = 68.0;

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: isDark ? stitchPrimary : seed,
      onPrimary: isDark ? const Color(0xFF003914) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF1CA64D)
          : const Color(0xFFDDFBE4),
      onPrimaryContainer: isDark
          ? const Color(0xFFE8FFED)
          : const Color(0xFF064E20),
      secondary: incomeBlue,
      onSecondary: Colors.white,
      tertiary: warningAmber,
      onTertiary: const Color(0xFF2A1700),
      error: expenseRed,
      surface: isDark ? deepSlate : lightSurface,
      onSurface: isDark ? const Color(0xFFD4E4FA) : const Color(0xFF0F172A),
      onSurfaceVariant: isDark
          ? const Color(0xFFB8C6D8)
          : const Color(0xFF475569),
      outline: isDark ? const Color(0xFF879485) : const Color(0xFF94A3B8),
      outlineVariant: isDark
          ? const Color(0xFF3E4A3D)
          : const Color(0xFFE2E8F0),
      surfaceContainerHighest: isDark ? elevatedSlate : lightPanel,
    );
    final baseTextTheme = ThemeData(brightness: brightness, useMaterial3: true)
        .textTheme
        .apply(
          fontFamily: fontFamily,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    final textTheme = baseTextTheme.copyWith(
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.45),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );

    final panelColor = isDark ? cardSlate : lightPanel;
    final elevatedPanelColor = isDark ? elevatedSlate : lightPanel;

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleSpacing: 20,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: panelColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : scheme.outlineVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : seed.withValues(alpha: 0.08),
        selectedColor: seed.withValues(alpha: 0.16),
        disabledColor: scheme.onSurface.withValues(alpha: 0.08),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : scheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(0, 48)),
          visualDensity: VisualDensity.comfortable,
          textStyle: WidgetStateProperty.all(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary.withValues(alpha: 0.72)
                  : scheme.outlineVariant,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surfaceSlate : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        filled: true,
        fillColor: isDark
            ? surfaceSlate.withValues(alpha: 0.78)
            : Colors.white.withValues(alpha: 0.96),
      ),
      listTileTheme: ListTileThemeData(
        minLeadingWidth: 34,
        minTileHeight: 64,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: bottomNavigationHeight,
        backgroundColor: isDark ? surfaceSlate : Colors.white,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 10.5,
            height: 1.05,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.20 : 0.78),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant.withValues(alpha: 0.35),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevatedPanelColor,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
    );
  }
}
