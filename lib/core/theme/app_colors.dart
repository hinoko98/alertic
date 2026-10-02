import 'package:flutter/material.dart';

/// Paleta de ALERTIC.
///
/// Los colores de nivel (amarilla, naranja, roja) son semánticos: solo se usan
/// para comunicar gravedad, nunca como decoracion.
abstract final class AppColors {
  // Marca
  static const Color brand = Color(0xFFE63118);
  static const Color brandDark = Color(0xFFC4260F);

  // Niveles de alerta
  static const Color levelYellow = Color(0xFFF1C42B);
  static const Color levelOrange = Color(0xFFEE7811);
  static const Color levelRed = Color(0xFFD92B12);

  // Tinta
  static const Color ink = Color(0xFF111111);
  static const Color inkMuted = Color(0xFF6B6B6B);
  static const Color inkFaint = Color(0xFF9A9A9A);

  // Superficies
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF4F4F2);
  static const Color border = Color(0xFFDCDCD8);
  static const Color onBrand = Color(0xFFFFFFFF);
}
