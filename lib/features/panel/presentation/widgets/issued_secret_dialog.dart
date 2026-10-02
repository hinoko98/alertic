import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Muestra una credencial recién emitida: una contraseña temporal o un código.
///
/// **Se ve una sola vez.** El servidor guarda solo una versión cifrada, así que
/// cuando este diálogo se cierra nadie —tampoco coordinación— puede volver a
/// leerla; si se pierde, se genera otra. Por eso no se cierra tocando fuera: un
/// toque sin querer dejaría a coordinación sin la contraseña que acaba de crear.
Future<void> showIssuedSecret(
  BuildContext context, {
  required String title,
  required String person,
  required String secret,
  required String instruction,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _IssuedSecretDialog(
      title: title,
      person: person,
      secret: secret,
      instruction: instruction,
    ),
  );
}

class _IssuedSecretDialog extends StatefulWidget {
  const _IssuedSecretDialog({
    required this.title,
    required this.person,
    required this.secret,
    required this.instruction,
  });

  final String title;
  final String person;
  final String secret;
  final String instruction;

  @override
  State<_IssuedSecretDialog> createState() => _IssuedSecretDialogState();
}

class _IssuedSecretDialogState extends State<_IssuedSecretDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.secret));
    if (mounted) {
      setState(() => _copied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Para ${widget.person}', style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                border: Border.all(color: AppColors.border),
              ),
              // Seleccionable: en el computador de coordinación se puede copiar
              // a mano aunque el portapapeles falle.
              child: SelectableText(
                widget.secret,
                key: const Key('secreto-emitido'),
                style: AppTextStyles.code.copyWith(fontSize: 20, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(widget.instruction, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.visibility_off_outlined, size: 14, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Se muestra una sola vez. Después no se puede volver a ver.',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _copy,
          child: Text(_copied ? 'COPIADA' : 'COPIAR'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          child: const Text('LISTO'),
        ),
      ],
    );
  }
}
