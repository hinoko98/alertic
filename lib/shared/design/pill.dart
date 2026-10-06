import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// La insignia pequeña y redonda: «Nuevo», «A salvo», «Estudiante», «9.° B».
enum PillTone { neutral, brand, success, warning, dark }

class Pill extends StatelessWidget {
  const Pill(this.label, {this.tone = PillTone.neutral, this.icon, super.key});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (tone) {
      PillTone.neutral => (AppColors.surfaceAlt, AppColors.inkMuted),
      PillTone.brand => (AppColors.brandSoft, AppColors.brand),
      PillTone.success => (AppColors.successSoft, AppColors.success),
      PillTone.warning => (AppColors.warningSoft, AppColors.warning),
      PillTone.dark => (AppColors.ink, AppColors.onBrand),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
