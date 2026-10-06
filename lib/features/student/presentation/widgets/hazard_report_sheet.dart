import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';

/// Hoja para reportar una emergencia que el colegio todavía no vio.
///
/// Son opciones cerradas, sin campo de texto. Dos razones: en una emergencia
/// nadie escribe, y un texto libre que sale del celular de un menor y llega a
/// una pantalla del colegio es una entrada más que habría que limpiar y
/// moderar. Con una lista fija no hay nada que validar del lado del servidor
/// más allá de que el valor exista.
class HazardReportSheet extends StatelessWidget {
  const HazardReportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // Desplazable a propósito: una hoja inferior solo puede ocupar poco más de la
    // mitad de la pantalla, y en un celular bajo las cuatro opciones no caben. Sin
    // desplazamiento, la última —incendios— quedaba cortada y no se podía tocar,
    // justo en la pantalla que se usa para avisar de una emergencia.
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('¿Qué viste?', style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Le llega a tu director de grupo y a coordinación. '
                    'Ellos deciden si suena una alerta.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final Hazard hazard in Hazard.values) ...<Widget>[
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  hazardIcon(hazard),
                  color: AppColors.brand,
                  size: 22,
                ),
                title: Text(hazard.label, style: AppTextStyles.itemTitle),
                onTap: () => Navigator.of(context).pop(hazard),
              ),
            ],
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              child: Text(
                'Si hay alguien herido, busca a un docente además de reportar.',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
