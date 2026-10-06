import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Botón secundario: blanco con borde. Acompaña al [PrimaryButton] con la acción
/// alterna (ya tengo cuenta, mis datos no son correctos).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.centered = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Centra la etiqueta (lo habitual) o la alinea a la izquierda.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.button.copyWith(color: AppColors.ink),
    );

    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          onTap: onPressed,
          child: SizedBox(
            height: AppSpacing.buttonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment:
                    centered ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 18, color: AppColors.ink),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  centered ? Flexible(child: text) : Expanded(child: text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
