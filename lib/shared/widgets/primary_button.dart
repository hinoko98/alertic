import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// botón de acción principal: rectangulo solido, etiqueta a la izquierda y un
/// icono al extremo derecho. Es el único botón relleno de cada pantalla.
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
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: background,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: AppSpacing.buttonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.button.copyWith(color: foreground),
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, size: 20, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
