import 'package:flutter/material.dart';

import 'app_colors.dart';

/// tipografía del diseño: grotesca pesada, títulos apretados y etiquetas en
/// mayúsculas con mucho tracking.
abstract final class AppTextStyles {
  /// "ALERTIC" en la portada.
  static const TextStyle hero = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w900,
    height: 1.0,
    letterSpacing: -1.5,
    color: AppColors.onBrand,
  );

  /// Titulo de pantalla: "ASÍ FUNCIONA", "TU CÓDIGO".
  static const TextStyle screenTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    height: 1.1,
    letterSpacing: -0.6,
    color: AppColors.ink,
  );

  /// Título de la barra superior de una pantalla.
  static const TextStyle headerTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: AppColors.ink,
  );

  /// Etiqueta pequena en mayúsculas sobre un bloque.
  static const TextStyle eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
    color: AppColors.inkMuted,
  );

  /// Titulo de un item dentro de una lista (paso, permiso, tarjeta).
  static const TextStyle itemTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppColors.ink,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 1.4,
    color: AppColors.inkMuted,
  );

  /// Texto de los botones de acción.
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );

  /// código personal: monoespaciado para que no se confundan caracteres.
  static const TextStyle code = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: <String>['Roboto Mono', 'Courier New'],
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
    color: AppColors.ink,
  );
}
