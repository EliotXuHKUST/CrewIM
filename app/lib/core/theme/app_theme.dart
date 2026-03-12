import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 32.0;
  static const screenH = 20.0;
  static const cardRadius = 14.0;
  static const buttonRadius = 10.0;
  static const inputRadius = 22.0;
}

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.card,
      surfaceContainerHighest: AppColors.surfaceSecondary,
      error: AppColors.error,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 0.5,
      space: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.5, color: AppColors.textPrimary),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: -0.3, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.6, letterSpacing: -0.1, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: AppColors.textSecondary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.3, color: AppColors.textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.buttonOutline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.buttonRadius)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -0.2),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
    ),
  );
}
