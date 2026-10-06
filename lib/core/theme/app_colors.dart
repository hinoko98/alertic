import 'package:flutter/material.dart';

/// Paleta de ALERTIC.
///
/// Los colores de nivel (amarilla, naranja, roja) son semánticos: solo se usan
/// para comunicar gravedad, nunca como decoración. El verde es lo mismo para lo
/// bueno —a salvo, conectado, sin alertas— y no se usa para otra cosa.
abstract final class AppColors {
  // Marca: el rojo institucional del diseño.
  static const Color brand = Color(0xFFB2243B);
  static const Color brandDark = Color(0xFF8E1B2E);

  /// El rojo suave de las insignias y los botones «Ayuda».
  static const Color brandSoft = Color(0xFFFBEAEC);

  // Niveles de alerta
  static const Color levelYellow = Color(0xFFF1C42B);
  static const Color levelOrange = Color(0xFFEE7811);
  static const Color levelRed = Color(0xFFB2243B);

  // Tinta: el azul casi negro del diseño.
  static const Color ink = Color(0xFF1B2631);
  static const Color inkMuted = Color(0xFF5F6B7A);
  static const Color inkFaint = Color(0xFF9AA3AF);

  // Superficies
  static const Color background = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEEF0F3);
  static const Color border = Color(0xFFE2E5EA);
  static const Color onBrand = Color(0xFFFFFFFF);

  // Lo bueno: a salvo, conectado, todo tranquilo.
  static const Color success = Color(0xFF1F6B45);
  static const Color successSoft = Color(0xFFE7F1EB);

  // Atención: sin confirmar, en revisión.
  static const Color warning = Color(0xFF8A5A00);
  static const Color warningSoft = Color(0xFFFFF3D6);
}
