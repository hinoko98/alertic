import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Lo que se ve cuando una pantalla no se pudo construir.
///
/// Reemplaza el recuadro gris de Flutter, que en release queda en blanco y no
/// dice nada. En debug muestra el error para poder arreglarlo; en release solo
/// dice que algo falló, sin detalles técnicos.
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({required this.details, super.key});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: AppColors.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.brand,
                  size: 32,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'ALGO FALLÓ EN ESTA PANTALLA',
                  style: AppTextStyles.screenTitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Cierra y vuelve a abrir la app. Si sigue pasando, avisa en '
                  'coordinación.',
                  style: AppTextStyles.body,
                ),
                if (kDebugMode) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        '${details.exception}',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
