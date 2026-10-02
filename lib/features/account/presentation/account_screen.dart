import 'package:flutter/material.dart';

import '../../../app/sign_out.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../onboarding/domain/enrollment.dart';
import '../../onboarding/presentation/widgets/identity_card.dart';
import 'change_password_sheet.dart';

/// Cuenta: quién es la persona para el colegio, y cómo cerrar sesión.
///
/// Es la pantalla que le faltaba a docentes, acudientes y coordinación: el
/// estudiante ya tenía su perfil con el botón de salir. Es una sola pantalla para
/// los tres porque hacen lo mismo aquí —ver sus datos y salir—; lo que cambia es
/// qué datos tienen y si entran con contraseña (y por tanto pueden cambiarla).
class AccountScreen extends StatelessWidget {
  const AccountScreen({required this.enrollment, super.key});

  final Enrollment enrollment;

  /// Quien entra con correo y contraseña puede cambiarla; quien entra con el
  /// código del carné no tiene una.
  bool get _canChangePassword => enrollment.role.usesPassword;

  Future<void> _changePassword(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool changed = await showChangePassword(context);
    if (changed) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Contraseña cambiada. Tus otras sesiones se cerraron.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Enrollment person = enrollment;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.md,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          children: <Widget>[
            const Text('TU CUENTA', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.lg),
            IdentityCard(
              children: <Widget>[
                IdentityHeader(role: person.roleLabel, fullName: person.fullName),
                const Divider(height: 1),
                ..._details(person),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            LockedDataNote(
              message: _canChangePassword
                  ? 'El colegio registró estos datos. Si algo está mal, pídele a '
                      'coordinación que lo cambie.'
                  : 'El colegio registró estos datos. Si algo está mal, avisa en '
                      'secretaría.',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_canChangePassword) ...<Widget>[
              OutlinedButton(
                onPressed: () => _changePassword(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.border),
                  shape: const RoundedRectangleBorder(),
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                ),
                child: Text('CAMBIAR CONTRASEÑA', style: AppTextStyles.button),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            OutlinedButton(
              onPressed: () => confirmAndSignOut(
                context,
                message: _canChangePassword
                    ? SignOutMessages.withPassword
                    : SignOutMessages.withCode,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.border),
                shape: const RoundedRectangleBorder(),
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
              ),
              child: Text('CERRAR SESIÓN', style: AppTextStyles.button),
            ),
          ],
        ),
      ),
    );
  }

  /// Los datos de cada rol. Un `switch` sobre la clase sellada: si se agrega un
  /// rol nuevo, el compilador obliga a decidir qué se muestra aquí.
  static List<Widget> _details(Enrollment person) {
    return switch (person) {
      TeacherEnrollment() => <Widget>[
          if (person.email != null) ...<Widget>[
            DetailRow(label: 'Correo', value: person.email!),
            const Divider(height: 1),
          ],
          DetailRow(label: 'Materia', value: person.subject),
          const Divider(height: 1),
          DetailRow(
            label: 'Director de grupo',
            value: person.homeroomGroup ?? 'No dirige un grupo',
          ),
          const Divider(height: 1),
          DetailRow(
            label: 'Grupos que dicta',
            value: person.groups.isEmpty ? '—' : person.groups.join(', '),
          ),
        ],
      AdminEnrollment() => <Widget>[
          if (person.email != null) ...<Widget>[
            DetailRow(label: 'Correo', value: person.email!),
            const Divider(height: 1),
          ],
          DetailRow(label: 'Alcance', value: person.scope),
        ],
      GuardianEnrollment() => <Widget>[
          DetailRow(label: 'Celular registrado', value: person.maskedPhone),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text('HIJOS VINCULADOS', style: AppTextStyles.eyebrow),
          ),
          for (final LinkedStudent child in person.children)
            LinkedPersonRow(
              name: child.fullName,
              detail: '${child.grade} · ${child.shift}',
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      StudentEnrollment() => <Widget>[
          DetailRow(label: 'Grado', value: '${person.grade} · ${person.shift}'),
        ],
    };
  }
}
