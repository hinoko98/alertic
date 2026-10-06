import 'package:flutter/material.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/location/location_tracker.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/pill.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// Lo que se dice sobre la ubicación: que la estamos buscando, o por qué no hay y
/// qué hacer. Nada si todo funciona (el mapa ya lo muestra).
class LocationNotice extends StatelessWidget {
  const LocationNotice({required this.tracker, super.key});

  final LocationTracker tracker;

  @override
  Widget build(BuildContext context) {
    final LocationAccess? access = tracker.access;
    if (access == null || tracker.isLive) return const SizedBox.shrink();

    final (String title, String body, String? action, VoidCallback? onAction) = switch (access) {
      LocationAccess.granted => (
          'Buscando tu ubicación…',
          'Puede tardar unos segundos. Mejora al aire libre.',
          null,
          null,
        ),
      LocationAccess.denied => (
          'Activa tu ubicación',
          'Con ella el mapa te muestra por dónde vas y hacia dónde ir. Solo se usa '
              'mientras tienes esta pantalla abierta.',
          'Permitir ubicación',
          tracker.retry,
        ),
      LocationAccess.deniedForever => (
          'La ubicación está bloqueada',
          'Para verla en el mapa, permítela en los ajustes del celular.',
          'Abrir ajustes',
          tracker.openSettings,
        ),
      LocationAccess.serviceOff => (
          'El GPS está apagado',
          'Enciéndelo para ver tu posición en el mapa.',
          'Ya lo encendí',
          tracker.retry,
        ),
      LocationAccess.unsupported => (
          'Sin ubicación en este dispositivo',
          'Sigue los pasos de abajo: el colegio los escribió para llegar al punto.',
          null,
          null,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        key: const Key('aviso-ubicacion'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 2),
            Text(body, style: AppTextStyles.caption),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                key: const Key('activar-ubicacion'),
                label: action,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// «En vivo · GPS ±6 m», o «Sin ubicación».
class LiveStatusPill extends StatelessWidget {
  const LiveStatusPill({required this.tracker, super.key});

  final LocationTracker tracker;

  @override
  Widget build(BuildContext context) {
    final LocationFix? fix = tracker.fix;
    if (tracker.isLive && fix != null) {
      return Pill(
        'En vivo · GPS ±${fix.accuracy.round()} m',
        tone: PillTone.success,
        icon: Icons.circle,
      );
    }
    return const Pill('Sin ubicación', tone: PillTone.neutral, icon: Icons.location_off_outlined);
  }
}
