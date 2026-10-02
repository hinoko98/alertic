import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// botón secundario: solo borde. Acompana al [PrimaryButton] con la acción
/// alterna (ya tengo cuenta, mis datos no son correctos).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.centered = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Centra la etiqueta en vez de alinearla a la izquierda.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(
      label,
      style: AppTextStyles.button.copyWith(color: AppColors.ink),
    );

    return Material(
      color: AppColors.surface,
      shape: const Border.fromBorderSide(
        BorderSide(color: AppColors.border),
      ),
      child: InkWell(
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
                  Icon(icon, size: 20, color: AppColors.ink),
                  const SizedBox(width: AppSpacing.md),
                ],
                centered ? text : Expanded(child: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
