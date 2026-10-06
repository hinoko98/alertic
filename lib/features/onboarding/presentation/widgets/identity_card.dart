import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Recuadro con los datos que el colegio cargó de la persona.
class IdentityCard extends StatelessWidget {
  const IdentityCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Etiqueta negra con el rol: ESTUDIANTE, ACUDIENTE, DOCENTE.
class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});

  final String role;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          role,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.onBrand,
          ),
        ),
      ),
    );
  }
}

/// Encabezado del recuadro: rol y nombre completo.
class IdentityHeader extends StatelessWidget {
  const IdentityHeader({required this.role, required this.fullName, super.key});

  final String role;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Align(alignment: Alignment.centerLeft, child: RoleChip(role)),
          const SizedBox(height: AppSpacing.md),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.4,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de dato: etiqueta a la izquierda, valor a la derecha.
class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: AppTextStyles.caption)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Persona vinculada dentro del recuadro: un acudiente visto desde el
/// estudiante, o un hijo visto desde el acudiente.
class LinkedPersonRow extends StatelessWidget {
  const LinkedPersonRow({
    required this.name,
    required this.detail,
    this.initials,
    super.key,
  });

  final String name;

  /// Parentesco, o grado y jornada.
  final String detail;

  /// Avatar con iniciales. Si es nulo, el detalle va alineado a la derecha.
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final String? avatar = initials;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          if (avatar != null) ...<Widget>[
            SizedBox(
              width: 28,
              child: Text(
                avatar,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(detail, style: AppTextStyles.caption),
                ],
              ),
            ),
          ] else ...<Widget>[
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text(detail, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// Aviso al pie: los datos los puso el colegio y no se editan desde la app.
class LockedDataNote extends StatelessWidget {
  const LockedDataNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.lock_outline, size: 14, color: AppColors.inkFaint),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(message, style: AppTextStyles.caption)),
      ],
    );
  }
}
