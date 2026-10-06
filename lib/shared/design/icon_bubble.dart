import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// El círculo con un icono que acompaña a cada elemento de una lista.
class IconBubble extends StatelessWidget {
  const IconBubble({
    required this.icon,
    this.size = 40,
    this.background = AppColors.brandSoft,
    this.foreground = AppColors.brand,
    super.key,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color foreground;

  /// Variante neutra, para lo que no es de marca.
  const IconBubble.neutral({required this.icon, this.size = 40, super.key})
      : background = AppColors.surfaceAlt,
        foreground = AppColors.ink;

  /// Variante verde: lo que está bien.
  const IconBubble.success({required this.icon, this.size = 40, super.key})
      : background = AppColors.successSoft,
        foreground = AppColors.success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}
