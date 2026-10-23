import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/alert.dart';
import '../../domain/alert_level.dart';
import '../../domain/hazard.dart';
import 'alert_level_style.dart';

/// Los colores de la pantalla de una alerta.
///
/// El **tipo de amenaza** da el color de fondo —un sismo se reconoce de lejos
/// por ser rojo, una inundación por ser azul— y el **nivel** se dice aparte, en
/// la etiqueta bajo el título («Alerta naranja · Prepararse para salir»). Un
/// simulacro tiene su propio color para que nadie lo confunda con una emergencia.
///
/// Una lluvia solo es amarilla mientras el nivel es amarillo: si sube, toma el
/// color del nivel, porque un fondo de precaución no puede acompañar una orden de
/// evacuar.
class AlertPalette {
  const AlertPalette({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.panel,
    required this.topChipBackground,
    required this.topChipForeground,
    required this.levelChipBackground,
    required this.levelChipForeground,
    required this.topLabel,
    this.levelChipFromLevel = false,
  });

  /// Fondo de toda la pantalla.
  final Color background;

  /// Texto e iconos sobre el fondo.
  final Color foreground;

  /// El color oscuro del fondo, para el texto de los botones blancos y los
  /// números de los pasos.
  final Color accent;

  /// El recuadro de «Qué hacer ahora».
  final Color panel;

  final Color topChipBackground;
  final Color topChipForeground;

  /// La etiqueta con el nivel y la acción.
  final Color levelChipBackground;
  final Color levelChipForeground;

  /// El texto de la insignia de arriba a la izquierda.
  final String topLabel;

  final bool levelChipFromLevel;

  /// El fondo es claro y el texto oscuro (la precaución amarilla).
  bool get isLight => foreground == AppColors.ink;

  static const Color _red = Color(0xFFB3263A);
  static const Color _redDark = Color(0xFF8A1C2D);
  static const Color _blue = Color(0xFF1D5FA8);
  static const Color _blueDark = Color(0xFF0F3E73);
  static const Color _caution = Color(0xFFF4C430);
  static const Color _flame = Color(0xFFB84A00);
  static const Color _flameDark = Color(0xFF7A3000);
  static const Color _drill = Color(0xFF4B3F8F);
  static const Color _drillDark = Color(0xFF2F2766);
  static const Color _orange = Color(0xFFF28C28);

  static AlertPalette of(Alert alert) {
    if (alert.isDrill) return _drillPalette;

    return switch (alert.hazard) {
      Hazard.sismo => _redPalette,
      Hazard.inundacion => _bluePalette,
      Hazard.incendio => _flamePalette,
      Hazard.lluvia => _rain(alert.level),
    };
  }

  static const AlertPalette _redPalette = AlertPalette(
    background: _red,
    foreground: Colors.white,
    accent: _redDark,
    panel: Color(0x33000000),
    topChipBackground: Colors.white,
    topChipForeground: _redDark,
    levelChipBackground: Colors.white,
    levelChipForeground: _redDark,
    topLabel: 'ALERTA ACTIVA',
  );

  static const AlertPalette _bluePalette = AlertPalette(
    background: _blue,
    foreground: Colors.white,
    accent: _blueDark,
    panel: Color(0x33000000),
    topChipBackground: Colors.white,
    topChipForeground: _blueDark,
    // En azul el nivel se lee por su propio color, no por el del fondo.
    levelChipBackground: _orange,
    levelChipForeground: AppColors.ink,
    topLabel: 'ALERTA ACTIVA',
    levelChipFromLevel: true,
  );

  static const AlertPalette _flamePalette = AlertPalette(
    background: _flame,
    foreground: Colors.white,
    accent: _flameDark,
    panel: Color(0x33000000),
    topChipBackground: Colors.white,
    topChipForeground: _flameDark,
    levelChipBackground: Colors.white,
    levelChipForeground: _flameDark,
    topLabel: 'ALERTA ACTIVA',
  );

  static const AlertPalette _drillPalette = AlertPalette(
    background: _drill,
    foreground: Colors.white,
    accent: _drillDark,
    panel: Color(0x38000000),
    topChipBackground: Colors.white,
    topChipForeground: _drillDark,
    levelChipBackground: Color(0x2EFFFFFF),
    levelChipForeground: Colors.white,
    topLabel: 'SIMULACRO',
  );

  static AlertPalette _rain(AlertLevel level) {
    if (level == AlertLevel.amarilla) {
      return const AlertPalette(
        background: _caution,
        foreground: AppColors.ink,
        accent: AppColors.ink,
        panel: Color(0x8CFFFFFF),
        topChipBackground: AppColors.ink,
        topChipForeground: Colors.white,
        levelChipBackground: AppColors.ink,
        levelChipForeground: _caution,
        topLabel: 'AVISO DE PRECAUCIÓN',
      );
    }
    final AlertLevelStyle style = AlertLevelStyle.of(level);
    return AlertPalette(
      background: style.bodyColor,
      foreground: Colors.white,
      accent: style.headerColor,
      panel: const Color(0x33000000),
      topChipBackground: Colors.white,
      topChipForeground: style.headerColor,
      levelChipBackground: Colors.white,
      levelChipForeground: style.headerColor,
      topLabel: 'ALERTA ACTIVA',
    );
  }
}
