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
      return ThemeMode.light;
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
  _ => ThemeMode.light,
};

Locale _localeFromCode(String? value) => switch (value) {
  'en' => const Locale('en'),
  'ja' => const Locale('ja'),
  _ => const Locale('vi'),
};

class AppTheme {
  static const fontFamily = 'Be Vietnam Pro';
  static const fontFallback = ['Noto Sans JP'];

  static const seed = Color(0xFF0F7A5C);
  static const stitchPrimary = Color(0xFF7BE0B3);
  static const deepSlate = Color(0xFF101613);
  static const surfaceSlate = Color(0xFF151D19);
  static const cardSlate = Color(0xFF1B2721);
  static const elevatedSlate = Color(0xFF24352C);
  static const lightSurface = Color(0xFFF4F0E7);
  static const lightPanel = Color(0xFFFFFCF4);
  static const lightPanelTint = Color(0xFFF8F2E6);
  static const ink = Color(0xFF1D251F);
  static const mutedInk = Color(0xFF667267);
  static const incomeGreen = Color(0xFF0F8F68);
  static const warningAmber = Color(0xFFB7791F);
  static const expenseRed = Color(0xFFC2413A);
  static const forecastNext = Color(0xFF126E6A);

  static const List<Color> chartPalette = [
    incomeGreen,
    expenseRed,
    warningAmber,
    seed,
    forecastNext,
  ];

  static const controlRadius = 12.0;
  static const cardRadius = 18.0;
  static const sheetRadius = 22.0;
  static const pillRadius = 999.0;
  static const bottomNavigationHeight = 72.0;

  static const animationFast = Duration(milliseconds: 180);
  static const animationMedium = Duration(milliseconds: 250);
  static const animationSlow = Duration(milliseconds: 400);

  static bool motionAllowed(BuildContext context) =>
      !MediaQuery.of(context).disableAnimations;

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
      onPrimary: isDark ? const Color(0xFF092116) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF244F3B)
          : const Color(0xFFDDEFE4),
      onPrimaryContainer: isDark
          ? const Color(0xFFDDFCE9)
          : const Color(0xFF173E2C),
      secondary: incomeGreen,
      onSecondary: Colors.white,
      tertiary: warningAmber,
      onTertiary: const Color(0xFF2A1B00),
      error: expenseRed,
      surface: isDark ? deepSlate : lightSurface,
      onSurface: isDark ? const Color(0xFFE8EFE8) : ink,
      onSurfaceVariant: isDark ? const Color(0xFFBAC7BB) : mutedInk,
      outline: isDark ? const Color(0xFF788778) : const Color(0xFFB7AD9D),
      outlineVariant: isDark
          ? const Color(0xFF354338)
          : const Color(0xFFE5DBC9),
      surfaceContainerHighest: isDark ? elevatedSlate : lightPanelTint,
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
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
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
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleSpacing: 18,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        color: panelColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.055)
                : scheme.outlineVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : seed.withValues(alpha: 0.075),
        selectedColor: seed.withValues(alpha: isDark ? 0.20 : 0.13),
        disabledColor: scheme.onSurface.withValues(alpha: 0.08),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.075)
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
          horizontal: 16,
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
            : lightPanel.withValues(alpha: 0.98),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.13),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 10.8,
            height: 1.05,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
