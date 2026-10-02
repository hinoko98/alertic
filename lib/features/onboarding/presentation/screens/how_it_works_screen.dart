import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/step_progress.dart';
import '../../../alerts/domain/alert_level.dart';
import '../widgets/alert_level_bar.dart';
import '../widgets/numbered_step.dart';

/// Pantalla 02: como funciona la app y qué significa cada nivel de alerta.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const List<({String title, String description})> _steps =
      <({String title, String description})>[
    (
      title: 'Te llega la alerta',
      description: 'Suena y vibra aunque el celular esté en silencio.',
    ),
    (
      title: 'Sigues los pasos',
      description:
          'Instrucciones cortas y el punto de encuentro, también sin internet.',
    ),
    (
      title: 'Avisas que estás bien',
      description: 'Tu docente y tu familia lo ven al momento.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
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
                    const StepProgress(currentStep: 1),
                    const SizedBox(height: AppSpacing.lg),
                    const Text(
                      'ASÍ FUNCIONA',
                      style: AppTextStyles.screenTitle,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (int i = 0; i < _steps.length; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1),
                      NumberedStep(
                        number: i + 1,
                        title: _steps[i].title,
                        description: _steps[i].description,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const Text('NIVELES DE ALERTA', style: AppTextStyles.eyebrow),
                    const SizedBox(height: AppSpacing.md),
                    for (final AlertLevel level in AlertLevel.values)
                      AlertLevelBar(level: level),
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
              child: PrimaryButton(
                label: 'SIGUIENTE',
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.enterCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
