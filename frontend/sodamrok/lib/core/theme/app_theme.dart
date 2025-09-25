import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFAF7F2);
  static const Color primary = Color(0xFF3A7D74);
  static const Color accent = Color(0xFFFFAB5C);
  static const Color textMain = Color(0xFF1F3A36);
  static const Color textSecondary = Color(0xFF5C6D68);
  static const Color surface = Colors.white;

  static Color get primaryOpacity10 => primary.withOpacity(0.1);
}

class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      background: AppColors.background,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: AppColors.textMain,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        elevation: 8,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: AppColors.textMain,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(color: Color(0xFFE2DED5)),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textMain,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: AppColors.textMain),
      bodyMedium: base.bodyMedium?.copyWith(color: AppColors.textSecondary),
      labelLarge: base.labelLarge?.copyWith(
        color: AppColors.textMain,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
