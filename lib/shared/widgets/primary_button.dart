import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Botón de acción principal: relleno, esquinas suaves, etiqueta centrada y un
/// icono opcional. Es el único botón relleno de cada pantalla.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.background = AppColors.brand,
    this.foreground = AppColors.onBrand,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color background;
  final Color foreground;

  /// Muestra un indicador en vez del icono y bloquea el botón mientras se
  /// espera una respuesta.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !isLoading;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: AppSpacing.buttonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.button.copyWith(color: foreground),
                    ),
                  ),
                  if (isLoading) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    ),
                  ] else if (icon != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(icon, size: 18, color: foreground),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
