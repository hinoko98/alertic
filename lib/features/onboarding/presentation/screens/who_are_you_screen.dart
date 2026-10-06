import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 02: ¿quién eres?
///
/// Estudiante y acudiente siguen con el código del carné. Docentes, directivos y
/// personal administrativo entran con la cuenta que les dio el colegio: nadie que
/// pueda emitir una alerta para todo el colegio entra con un papel impreso.
class WhoAreYouScreen extends StatefulWidget {
  const WhoAreYouScreen({super.key});

  @override
  State<WhoAreYouScreen> createState() => _WhoAreYouScreenState();
}

enum _Choice { student, guardian, teacher, staff }

class _WhoAreYouScreenState extends State<WhoAreYouScreen> {
  _Choice _choice = _Choice.student;

  bool get _usesCode => _choice == _Choice.student || _choice == _Choice.guardian;

  void _next() {
    Navigator.of(context).pushNamed(
      _usesCode ? AppRoutes.enterCode : AppRoutes.signIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Crear tu acceso',
      step: 0,
      footer: PrimaryButton(label: 'Continuar', onPressed: _next),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('¿Quién eres en el colegio?', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Así te mostramos la información que te sirve en una emergencia.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Option(
            icon: Icons.school_outlined,
            title: 'Estudiante',
            subtitle: 'Recibe alertas y sigue tu ruta de evacuación',
            selected: _choice == _Choice.student,
            onTap: () => setState(() => _choice = _Choice.student),
          ),
          _Option(
            icon: Icons.family_restroom_outlined,
            title: 'Acudiente',
            subtitle: 'Sabe al instante si tus hijos están a salvo',
            selected: _choice == _Choice.guardian,
            onTap: () => setState(() => _choice = _Choice.guardian),
          ),
          _Option(
            icon: Icons.co_present_outlined,
            title: 'Docente o directivo',
            subtitle: 'Guía a tu grupo y confirma quién llegó al punto',
            selected: _choice == _Choice.teacher,
            onTap: () => setState(() => _choice = _Choice.teacher),
          ),
          _Option(
            icon: Icons.assignment_ind_outlined,
            title: 'Personal administrativo',
            subtitle: 'Secretaría, servicios generales y vigilancia',
            selected: _choice == _Choice.staff,
            onTap: () => setState(() => _choice = _Choice.staff),
          ),
          if (!_usesCode) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Entras con el correo y la contraseña que te dio el colegio, no '
              'con un código.',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.signIn),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, size: 18, color: AppColors.onBrand),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('¿Administras ALERTIC en tu colegio?', style: AppTextStyles.itemTitle),
                      Text('Entra con tu usuario fijo, sin código', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: AppCard(
          onTap: onTap,
          color: selected ? AppColors.brandSoft : AppColors.surface,
          borderColor: selected ? AppColors.brand : AppColors.border,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              IconBubble(icon: icon, size: 38),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_outline, color: AppColors.brand, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
