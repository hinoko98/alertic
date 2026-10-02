import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Fila de permiso: icono, qué hace, y el interruptor.
///
/// La descripción dice para qué se usa el permiso, no solo su nombre: es la
/// única parte del registro donde la app pide algo a cambio.
class PermissionToggle extends StatelessWidget {
  const PermissionToggle({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.itemTitle),
                const SizedBox(height: AppSpacing.xs),
                Text(description, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.surface,
            activeTrackColor: AppColors.brand,
            inactiveThumbColor: AppColors.surface,
            inactiveTrackColor: AppColors.border,
            trackOutlineColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) => states.contains(WidgetState.selected)
                  ? AppColors.brand
                  : AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}
