import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/pill.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/server_status_badge.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';

/// Pantalla 01: la bienvenida.
///
/// **Sin nombre de colegio**: la misma pantalla sirve para cualquier institución
/// que adopte ALERTIC. El colegio aparece cuando la persona escribe el código de
/// su carné y el servidor lo reconoce.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const _TopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Center(child: _Mark()),
                    const SizedBox(height: AppSpacing.lg),
                    const Center(
                      child: Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Center(child: Pill('Alertas tempranas')),
                    const SizedBox(height: AppSpacing.sm),
                    const Center(
                      child: Text(
                        'Para colegios y comunidades educativas',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Dice con quién habla la app: servidor, y si responde.
                    const ServerStatusBadge(),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Te avisa al instante cuando hay una emergencia en tu '
                      'colegio, te dice qué hacer y le cuenta a tu familia que '
                      'estás a salvo.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _HazardGrid(hazards: Hazard.values),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  PrimaryButton(
                    label: 'Empezar',
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.whoAreYou),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Docentes y coordinación. Ellos no tienen código: entran con
                  // la cuenta que les dio el colegio.
                  SecondaryButton(
                    label: 'Ya tengo cuenta',
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.signIn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Bienvenido a ALERTIC', style: AppTextStyles.headerTitle),
                Text(
                  'Alertas tempranas para tu colegio',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: const BoxDecoration(
        color: AppColors.brandSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 62,
        height: 62,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.verified_user_outlined,
          color: AppColors.brand,
          size: 30,
        ),
      ),
    );
  }
}

/// Las cuatro amenazas que cubre el sistema, en dos columnas.
class _HazardGrid extends StatelessWidget {
  const _HazardGrid({required this.hazards});

  final List<Hazard> hazards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final Hazard hazard in hazards)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width -
                    AppSpacing.screenGutter * 2 -
                    AppSpacing.sm) /
                2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: <Widget>[
                  Icon(hazardIcon(hazard), size: 16, color: AppColors.brand),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _label(hazard),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _label(Hazard hazard) => switch (hazard) {
        Hazard.lluvia => 'Lluvias',
        Hazard.inundacion => 'Inundación',
        Hazard.sismo => 'Sismos',
        Hazard.incendio => 'Incendios',
      };
}
