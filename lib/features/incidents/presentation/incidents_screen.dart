import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          children: <Widget>[
            const Text('REPORTES', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lo que la comunidad avisa de tus grupos. Tú decides si hay que ir, '
              'descartarlo o emitir una alerta.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.lg),
            IncidentInbox(onEscalate: onEscalate),
          ],
        ),
      ),
    );
  }
}
