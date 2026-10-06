import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/screen_header.dart';

/// El marco de los pasos del registro: encabezado con flecha de volver, las tres
/// barritas de progreso, el contenido que se desplaza y un pie fijo con el botón.
///
/// Con el teclado abierto el pie pasa a ser parte del contenido: en un celular
/// quedan unos 200 puntos de pantalla, y un botón fijo se comería los campos.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.title,
    required this.child,
    required this.footer,
    this.step,
    this.subtitle,
    this.showBack = true,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// En qué paso va, empezando en 0. Sin valor, no se muestran las barritas.
  final int? step;
  final bool showBack;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          AppScreenHeader(
            title: title,
            subtitle: subtitle ?? (step == null ? null : 'Paso ${step! + 1} de 3'),
            onBack: showBack ? () => Navigator.of(context).maybePop() : null,
            showHelp: false,
          ),
          if (step != null) _Progress(step: step!),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  child,
                  if (keyboardOpen) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    footer,
                  ],
                ],
              ),
            ),
          ),
          if (!keyboardOpen)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.sm,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        0,
      ),
      child: Semantics(
        label: 'Paso ${step + 1} de 3',
        child: Row(
          children: <Widget>[
            for (int i = 0; i < 3; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.brand : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloque de ayuda al pie de un paso: «¿No tienes código?».
class HintCard extends StatelessWidget {
  const HintCard({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppTextStyles.itemTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
