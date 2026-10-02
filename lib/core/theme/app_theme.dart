import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema único de la app. ALERTIC no tiene modo oscuro: los colores comunican
/// gravedad y deben verse igual en todos los celulares.
abstract final class AppTheme {
  static ThemeData build() {
    const ColorScheme scheme = ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      secondary: AppColors.ink,
      onSecondary: AppColors.onBrand,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.levelRed,
      onError: AppColors.onBrand,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surface,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.hero,
        headlineMedium: AppTextStyles.screenTitle,
        titleSmall: AppTextStyles.itemTitle,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelSmall: AppTextStyles.eyebrow,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: AppColors.onBrand, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
