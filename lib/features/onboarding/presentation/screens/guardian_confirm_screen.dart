import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/guardian_link.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 11: confirmar al estudiante y el parentesco.
///
/// El acudiente ve al estudiante con el apellido tapado y dice quién es para él.
/// Puede sumar más hijos antes de seguir: cada uno queda como una solicitud
/// aparte, porque el colegio aprueba vínculo por vínculo.
class GuardianConfirmScreen extends StatefulWidget {
  const GuardianConfirmScreen({
    required this.draft,
    required this.student,
    super.key,
  });

  final GuardianDraft draft;
  final StudentMatch student;

  @override
  State<GuardianConfirmScreen> createState() => _GuardianConfirmScreenState();
}

class _GuardianConfirmScreenState extends State<GuardianConfirmScreen> {
  late GuardianRelationship _relationship = widget.draft.relationship;

  /// Los hijos ya confirmados más el que se está mirando, sin repetir: el mismo
  /// documento buscado dos veces sería dos solicitudes iguales.
  List<StudentMatch> get _withCurrent => <StudentMatch>[
        for (final StudentMatch child in widget.draft.children)
          if (child.document != widget.student.document) child,
        widget.student,
      ];

  GuardianDraft get _updated =>
      widget.draft.copyWith(children: _withCurrent, relationship: _relationship);

  void _continue() {
    Navigator.of(context).pushNamed(
      AppRoutes.guardianData,
      arguments: GuardianStepArgs(draft: _updated),
    );
  }

  void _addAnother() {
    Navigator.of(context).pushNamed(AppRoutes.guardianSearch, arguments: _updated);
  }

  @override
  Widget build(BuildContext context) {
    final StudentMatch student = widget.student;
    final List<StudentMatch> earlier = <StudentMatch>[
      for (final StudentMatch child in widget.draft.children)
        if (child.document != student.document) child,
    ];

    return OnboardingScaffold(
      title: 'Registro del acudiente',
      subtitle: 'Paso 2 de 4',
      step: 1,
      stepCount: 4,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PrimaryButton(
            label: 'Sí, continuar',
            icon: null,
            onPressed: _continue,
          ),
          TextButton(
            key: const Key('no-es-mi-hijo'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: AppColors.inkMuted,
            ),
            child: const Text('No es mi hijo · buscar de nuevo'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('¿Es tu hijo o hija?', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.lg),
          Container(
            key: const Key('estudiante-encontrado'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.success, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        student.initials,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onBrand,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            student.maskedName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const Text(
                            'Estudiante encontrada en la matrícula',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(child: _Fact(label: 'Curso', value: student.grade)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _Fact(label: 'Jornada', value: student.shift)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _Fact(label: 'Documento', value: student.maskedDocument),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (earlier.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ya agregaste: ${earlier.map((StudentMatch c) => c.firstName).join(', ')}',
              key: const Key('hijos-agregados'),
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const Text('TU PARENTESCO', style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final GuardianRelationship option in GuardianRelationship.values)
                ChoiceChip(
                  key: Key('parentesco-${option.name}'),
                  label: Text(option.label),
                  selected: option == _relationship,
                  showCheckmark: false,
                  selectedColor: AppColors.brandSoft,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: option == _relationship ? AppColors.brand : AppColors.border,
                  ),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: option == _relationship ? AppColors.brand : AppColors.ink,
                  ),
                  onSelected: (_) => setState(() => _relationship = option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            key: const Key('agregar-otro-hijo'),
            onPressed: _addAnother,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar otro hijo o hija'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
              foregroundColor: AppColors.brand,
              side: BorderSide(color: AppColors.brand.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
