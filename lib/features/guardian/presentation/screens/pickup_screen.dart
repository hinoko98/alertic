import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/section_label.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../domain/guardian_repository.dart';

/// Pantalla 17: cómo recoger a los hijos al terminar la emergencia.
///
/// El momento más desordenado de una evacuación es el reencuentro: cien
/// familias en la portería preguntando por su hijo. Esta pantalla dice lo que
/// hay que llevar y lo que se va a pedir, para que sea una fila y no un tumulto.
///
/// **No hay código QR.** Un dibujo que parece un código y no se puede escanear
/// es peor que nada: la familia llegaría a la portería con algo que cree que
/// sirve. La entrega la verifica una persona del colegio contra el vínculo que
/// el propio colegio registró, y para eso alcanza el documento de identidad.
class PickupScreen extends StatelessWidget {
  const PickupScreen({required this.children, super.key});

  final List<ChildStatus> children;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Cómo recogerlos',
      subtitle: 'Al terminar la emergencia',
      onBack: () => Navigator.of(context).pop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          const Text('RECOGE A TUS HIJOS', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Preséntate en la portería del colegio. Una persona del colegio '
            'verifica que eres su acudiente y te entrega a cada uno.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _PickupRow(label: 'Lleva', value: 'Documento de identidad'),
                Divider(height: 1),
                _PickupRow(
                  label: 'Quién puede',
                  value: 'Solo acudientes registrados',
                ),
              ],
            ),
          ),
          const SectionLabel('A quién vas a recoger'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  _ChildRow(child: children[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupRow extends StatelessWidget {
  const _PickupRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTextStyles.caption)),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child});

  final ChildStatus child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  PersonName.short(child.fullName),
                  style: AppTextStyles.itemTitle,
                ),
                Text(
                  '${child.grade} · ${child.shift}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (child.isSafe)
            const Icon(Icons.check_circle_outline, size: 20, color: AppColors.success),
        ],
      ),
    );
  }
}
