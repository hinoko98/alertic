import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../alerts/domain/alert_level.dart';
import '../../../alerts/presentation/widgets/alert_level_style.dart';

/// Franja de color que explica qué significa un nivel de alerta.
///
/// Toma los colores de [AlertLevelStyle], el mismo sitio del que los toma la
/// pantalla de alerta: así lo que se le enseña a la persona en el registro es
/// exactamente lo que va a ver cuando suene de verdad.
class AlertLevelBar extends StatelessWidget {
  const AlertLevelBar({required this.level, super.key});

  final AlertLevel level;

  @override
  Widget build(BuildContext context) {
    final AlertLevelStyle style = AlertLevelStyle.of(level);

    return Container(
      height: 34,
      color: style.headerColor,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              level.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: style.headerForeground,
              ),
            ),
          ),
          Text(
            level.meaning,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: style.headerForeground,
            ),
          ),
        ],
      ),
    );
  }
}
