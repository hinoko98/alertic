import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../onboarding/domain/enrollment_failure.dart';
import '../../panel/presentation/widgets/admin_fields.dart';

/// Mínimo de caracteres que se avisa **antes** de preguntarle al servidor. Es
/// una comodidad: la regla es la del servidor, y si cambia, lo que él conteste
/// llega igual a la pantalla.
const int _minimumLength = 10;

/// Abre la hoja para cambiar la contraseña. Devuelve `true` si se cambió.
Future<bool> showChangePassword(BuildContext context) async {
  final bool? changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext context) => const _ChangePassword(),
  );
  return changed ?? false;
}

class _ChangePassword extends StatefulWidget {
  const _ChangePassword();

  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    if (_current.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña actual.');
      return;
    }
    if (_next.text.length < _minimumLength) {
      setState(
        () => _error = 'La contraseña nueva debe tener al menos '
            '$_minimumLength caracteres.',
      );
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = 'La confirmación no coincide con la contraseña nueva.');
      return;
    }
    if (_next.text == _current.text) {
      setState(() => _error = 'La contraseña nueva tiene que ser distinta de la actual.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final NavigatorState navigator = Navigator.of(context);
    try {
      await AppScope.of(context).credentialsRepository.changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      navigator.pop(true);
    } on EnrollmentFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cambiar contraseña');
      if (mounted) {
        setState(
          () => _error = 'No pudimos cambiar la contraseña. Revisa tu conexión e '
              'intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget eye = IconButton(
      tooltip: _show ? 'Ocultar' : 'Mostrar',
      icon: Icon(
        _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
      ),
      onPressed: () => setState(() => _show = !_show),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('TU CUENTA', style: AppTextStyles.eyebrow),
            const SizedBox(height: 2),
            const Text(
              'Cambiar contraseña',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Al cambiarla se cierran tus sesiones en otros celulares. Esta '
              'sigue abierta.',
              style: AppTextStyles.caption,
            ),
            if (_error != null) InlineNotice(_error!),
            AdminTextField(
              label: 'Contraseña actual',
              controller: _current,
              obscureText: !_show,
              suffix: eye,
            ),
            AdminTextField(
              label: 'Contraseña nueva',
              controller: _next,
              obscureText: !_show,
            ),
            AdminTextField(
              label: 'Repite la contraseña nueva',
              controller: _confirm,
              obscureText: !_show,
            ),
            const SizedBox(height: AppSpacing.xl),
            // `Wrap` y no `Row`: dos botones con texto no caben en 400 puntos de
            // ancho, y en un celular bajan a otra línea en vez de desbordarse.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                SheetButton(
                  label: 'CAMBIAR CONTRASEÑA',
                  filled: true,
                  busy: _busy,
                  onTap: _submit,
                ),
                SheetButton(
                  label: 'CANCELAR',
                  onTap: _busy ? null : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
