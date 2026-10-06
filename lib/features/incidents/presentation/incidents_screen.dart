import 'package:flutter/material.dart';

import '../../../shared/design/app_page.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/incident.dart';
import 'incident_inbox.dart';

/// La bandeja de reportes, a pantalla completa. La abre el docente.
///
/// Coordinación no la usa: la tiene dentro del tablero, junto a lo demás que
/// está pasando.
class IncidentsScreen extends StatelessWidget {
  const IncidentsScreen({this.onEscalate, super.key});

  /// Convierte un reporte en una alerta. Lo decide quien abre la pantalla porque
  /// emitir una alerta es de otra parte de la app.
  final void Function(Incident incident)? onEscalate;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'REPORTES',
      subtitle: 'Lo que la comunidad avisa de tus grupos',
      onBack: () => Navigator.of(context).pop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          const Text(
            'Tú decides si hay que ir, descartarlo o emitir una alerta.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          IncidentInbox(onEscalate: onEscalate),
        ],
      ),
    );
  }
}
