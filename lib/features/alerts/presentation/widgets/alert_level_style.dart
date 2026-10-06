import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/alert_level.dart';

/// Cómo se ve y se siente cada nivel de alerta.
///
/// Patrón creacional *Factory Method*: [AlertLevelStyle.of] es el único sitio
/// donde un nivel se convierte en colores, tamaños y acciones. Las pantallas
/// nunca preguntan «si es roja entonces...»; piden el estilo y lo aplican.
///
/// La escalada es deliberada: la amarilla informa sobre fondo blanco, la
/// naranja toma la pantalla, la roja la toma y exige responder.
class AlertLevelStyle {
  const AlertLevelStyle({
    required this.level,
    required this.headerColor,
    required this.bodyColor,
    required this.headerForeground,
    required this.bodyForeground,
    required this.titleSize,
    required this.icon,
    required this.primaryAction,
    required this.footnote,
    this.secondaryAction,
  });

  final AlertLevel level;

  /// Franja superior con el nivel y la hora.
  final Color headerColor;
  final Color headerForeground;

  /// Cuerpo con las instrucciones. En la amarilla es blanco; de naranja para
  /// arriba es del color del nivel, para que se reconozca sin leer.
  final Color bodyColor;
  final Color bodyForeground;

  final double titleSize;
  final IconData icon;

  final String primaryAction;

  /// Solo la roja tiene segunda acción: «necesito ayuda».
  final String? secondaryAction;

  /// Qué hace el celular con esta alerta. Se le dice a la persona para que
  /// entienda por qué sonó como sonó.
  final String footnote;

  /// El cuerpo va sobre el color del nivel.
  bool get isFullBleed => bodyColor != AppColors.surface;

  static AlertLevelStyle of(AlertLevel level) {
    return switch (level) {
      AlertLevel.amarilla => const AlertLevelStyle(
          level: AlertLevel.amarilla,
          headerColor: AppColors.levelYellow,
          headerForeground: AppColors.ink,
          bodyColor: AppColors.surface,
          bodyForeground: AppColors.ink,
          titleSize: 30,
          icon: Icons.warning_amber_rounded,
          primaryAction: 'Entendido',
          footnote: 'Sonido normal de notificación. '
              'Queda en Inicio hasta que se cierre.',
        ),
      AlertLevel.naranja => const AlertLevelStyle(
          level: AlertLevel.naranja,
          headerColor: AppColors.levelOrange,
          headerForeground: AppColors.onBrand,
          bodyColor: AppColors.levelOrange,
          bodyForeground: AppColors.onBrand,
          titleSize: 34,
          icon: Icons.notifications_active_outlined,
          primaryAction: 'Estoy listo',
          footnote: 'Sonido de alerta y vibración repetida cada 2 minutos.',
        ),
      AlertLevel.roja => const AlertLevelStyle(
          level: AlertLevel.roja,
          headerColor: AppColors.levelRed,
          headerForeground: AppColors.onBrand,
          bodyColor: AppColors.levelRed,
          bodyForeground: AppColors.onBrand,
          titleSize: 44,
          icon: Icons.emergency_share_outlined,
          primaryAction: 'Estoy a salvo',
          secondaryAction: 'Necesito ayuda',
          footnote: 'Sirena continua y vibración hasta que respondas. '
              'Ubicación compartida.',
        ),
    };
  }
}
