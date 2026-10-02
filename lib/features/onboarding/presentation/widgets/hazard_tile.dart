import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Celda de la cuadrícula de amenazas de la bienvenida (lluvias, inundacion,
/// sismos, incendios).
class HazardTile extends StatelessWidget {
  const HazardTile({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 22, color: AppColors.brand),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: AppTextStyles.itemTitle),
        ],
      ),
    );
  }
}
