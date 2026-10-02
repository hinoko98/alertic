import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Barritas del encabezado que indican en qué paso del registro va la persona.
class StepProgress extends StatelessWidget {
  const StepProgress({
    required this.currentStep,
    this.totalSteps = 3,
    super.key,
  }) : assert(currentStep >= 0, 'currentStep no puede ser negativo');

  /// Paso actual, empezando en 0.
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Paso ${currentStep + 1} de $totalSteps',
      child: Row(
        children: <Widget>[
          for (int i = 0; i < totalSteps; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            Container(
              width: 22,
              height: 4,
              color: i == currentStep ? AppColors.brand : AppColors.border,
            ),
          ],
        ],
      ),
    );
  }
}
