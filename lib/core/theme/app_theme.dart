import 'package:flutter/material.dart';

// Blue + white only. Functional. Dense. No decorative color.
abstract final class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFFEFF6FF);
  static const primaryDark = Color(0xFF1D4ED8);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  // Light surfaces
  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);

  // Dark surfaces
  static const bgDark = Color(0xFF0F1117);
  static const surfaceDark = Color(0xFF1A1D27);
  static const borderDark = Color(0xFF2E3354);
  static const textPrimaryDark = Color(0xFFE2E8F0);
  static const textSecondaryDark = Color(0xFF94A3B8);
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      surface: isDark ? AppColors.surfaceDark : AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.bgDark : AppColors.bg,

      // Dense AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor:
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        toolbarHeight: 52,
      ),

      // Flat cards with just a border — no elevation
      cardTheme: CardThemeData(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.borderDark : AppColors.border,
        thickness: 1,
        space: 0,
      ),

      // Dense text fields
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide:
              BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        labelStyle: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),

      // Prefer text buttons — use filled only for primary actions
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(0, 36),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 34),
          side: const BorderSide(color: AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),

      // Dense list tiles
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        titleTextStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          color:
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),

      // Minimal transitions (faster feel, less battery)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color:
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textMuted,
        ),
      ),
    );
  }
}
