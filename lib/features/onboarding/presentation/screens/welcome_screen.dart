import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/server_status_badge.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';
import '../widgets/hazard_tile.dart';

/// Pantalla 01: bienvenida. Lo primero que ve alguien que abre ALERTIC.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _Hero(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Dice con quién habla la app: servidor o datos de prueba.
                    const ServerStatusBadge(),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Te avisa al instante cuando hay una emergencia en el '
                      'colegio, te dice qué hacer y le cuenta a tu familia que '
                      'estás a salvo.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _HazardGrid(hazards: Hazard.values),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  0,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: <Widget>[
                    PrimaryButton(
                      label: 'EMPEZAR',
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.howItWorks),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Docentes y coordinación. Ellos no tienen código: entran
                    // con la cuenta que les dio el colegio.
                    SecondaryButton(
                      label: 'YA TENGO CUENTA',
                      centered: true,
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.signIn),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bloque rojo superior con el nombre de la app y el colegio.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.brand,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xxl,
        AppSpacing.screenGutter,
        AppSpacing.xl,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.tagline,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: AppColors.onBrand,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          Text(AppStrings.appName, style: AppTextStyles.hero),
          SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.schoolName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onBrand,
            ),
          ),
          Text(
            AppStrings.schoolCity,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.onBrand,
            ),
          ),
        ],
      ),
    );
  }
}

/// cuadrícula 2x2 con las amenazas que cubre el sistema.
class _HazardGrid extends StatelessWidget {
  const _HazardGrid({required this.hazards});

  final List<Hazard> hazards;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Column(
        children: <Widget>[
          for (int row = 0; row < hazards.length / 2; row++) ...<Widget>[
            if (row > 0) const Divider(height: 1),
            IntrinsicHeight(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: HazardTile(
                      icon: hazardIcon(hazards[row * 2]),
                      label: hazards[row * 2].label,
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: HazardTile(
                      icon: hazardIcon(hazards[row * 2 + 1]),
                      label: hazards[row * 2 + 1].label,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
