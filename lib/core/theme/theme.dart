import 'package:flutter/material.dart';

import 'brand.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: BrandColors.gold,
      onPrimary: Colors.black,
      secondary: BrandColors.goldSoft,
      onSecondary: Colors.black,
      error: Color(0xFFCF6679),
      onError: Colors.black,
      surface: BrandColors.surface,
      onSurface: BrandColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BrandColors.background,
      dividerTheme: const DividerThemeData(color: BrandColors.border),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandColors.gold,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BrandColors.surface,
        foregroundColor: BrandColors.textPrimary,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: BrandColors.surfaceAlt,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: BrandColors.gold.withValues(alpha: 0.32)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.gold,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.goldSoft,
          side: const BorderSide(color: BrandColors.gold),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.surface,
        labelStyle: const TextStyle(color: BrandColors.textSecondary),
        hintStyle: const TextStyle(color: BrandColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: BrandColors.gold),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1B1B1B),
        disabledColor: const Color(0xFF1B1B1B),
        selectedColor: const Color(0xFF1B1B1B),
        secondarySelectedColor: const Color(0xFF1B1B1B),
        side: const BorderSide(color: BrandColors.gold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(color: BrandColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: BrandColors.textPrimary),
        brightness: Brightness.dark,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BrandColors.surface,
        indicatorColor: BrandColors.gold.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: BrandColors.textPrimary),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: BrandColors.surface,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: BrandColors.textPrimary),
        bodySmall: TextStyle(color: BrandColors.textSecondary),
      ),
    );
  }
}
