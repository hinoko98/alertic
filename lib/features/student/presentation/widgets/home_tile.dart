import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Atajo cuadrado del inicio: qué hacer, historial.
class HomeTile extends StatelessWidget {
  const HomeTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: AppColors.ink),
              const SizedBox(height: AppSpacing.lg),
              Text(label, style: AppTextStyles.itemTitle),
            ],
          ),
        ),
      ),
    );
  }
}
