import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../session/domain/session.dart';
import '../../domain/enrollment.dart';
import '../../domain/enrollment_failure.dart';
import '../widgets/identity_card.dart';
import '../widgets/onboarding_scaffold.dart';

/// El código ya es válido; falta que la persona confirme que los datos son suyos.
///
/// Es una sola pantalla para los dos roles que entran por código: el diseño es
/// el mismo y solo cambia el contenido del recuadro. **Aquí se quema el código**,
/// no antes: si la persona ve que el perfil no es el suyo, el código sigue
/// sirviendo.
///
/// Recibe un [CodeEnrollment] y no un [Enrollment] cualquiera, para que el
/// compilador garantice lo que esta pantalla da por hecho: que hay un código que
/// quemar. Un docente nunca llega aquí, porque entra con correo y contraseña.
class ConfirmIdentityScreen extends StatefulWidget {
  const ConfirmIdentityScreen({required this.enrollment, super.key});

  final CodeEnrollment enrollment;

  @override
  State<ConfirmIdentityScreen> createState() => _ConfirmIdentityScreenState();
}

class _ConfirmIdentityScreenState extends State<ConfirmIdentityScreen> {
  bool _isConfirming = false;

  Future<void> _confirm() async {
    setState(() => _isConfirming = true);
    try {
      final AppScope scope = AppScope.of(context);
      final Session session =
          await scope.enrollmentRepository.confirmIdentity(widget.enrollment.code);
      await scope.sessionStore.save(session);
      if (!mounted) return;
      await Navigator.of(context).pushNamed(AppRoutes.permissions);
    } on EnrollmentFailure catch (failure, stack) {
      ErrorReporter.report(failure, stack, context: 'confirmar identidad');
      _showMessage(failure.message);
    } catch (error, stack) {
      // Cualquier cosa que no hayamos previsto: la persona ve un mensaje claro
      // y el detalle queda en el log.
      ErrorReporter.report(error, stack, context: 'confirmar identidad');
      _showMessage('No pudimos confirmar tus datos. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _reportWrongData() {
    _showMessage('Avisa en secretaría de tu colegio para que corrijan tus datos.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final CodeEnrollment enrollment = widget.enrollment;

    return OnboardingScaffold(
      title: 'Confirma tus datos',
      subtitle: 'Código válido',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PrimaryButton(
            label: 'Sí, soy yo',
            isLoading: _isConfirming,
            onPressed: _confirm,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: switch (enrollment) {
              StudentEnrollment() => 'Mis datos no son correctos',
              GuardianEnrollment() => 'Falta un hijo o hay un error',
            },
            onPressed: _isConfirming ? null : _reportWrongData,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('¿Eres tú?', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.lg),
          switch (enrollment) {
            StudentEnrollment() => _StudentCard(enrollment),
            GuardianEnrollment() => _GuardianCard(enrollment),
          },
          const SizedBox(height: AppSpacing.md),
          const LockedDataNote(
            message: 'El colegio registró estos datos. No se pueden editar desde '
                'la app.',
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard(this.enrollment);

  final StudentEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    return IdentityCard(
      children: <Widget>[
        IdentityHeader(role: enrollment.roleLabel, fullName: enrollment.fullName),
        const Divider(height: 1),
        DetailRow(label: 'Grado', value: '${enrollment.grade} · ${enrollment.shift}'),
        const Divider(height: 1),
        DetailRow(label: 'Director de grupo', value: enrollment.homeroomTeacher),
        const Divider(height: 1),
        const _CardSectionLabel('Acudientes vinculados'),
        for (final GuardianLink guardian in enrollment.guardians)
          LinkedPersonRow(name: guardian.fullName, detail: guardian.relationship),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _GuardianCard extends StatelessWidget {
  const _GuardianCard(this.enrollment);

  final GuardianEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    return IdentityCard(
      children: <Widget>[
        IdentityHeader(role: enrollment.roleLabel, fullName: enrollment.fullName),
        const Divider(height: 1),
        DetailRow(label: 'Celular', value: enrollment.maskedPhone),
        const Divider(height: 1),
        const _CardSectionLabel('Recibirás alertas de'),
        for (final LinkedStudent child in enrollment.children) ...<Widget>[
          LinkedPersonRow(
            initials: child.initials,
            name: child.fullName,
            detail: '${child.grade} · ${child.shift}',
          ),
          if (child != enrollment.children.last) const Divider(height: 1),
        ],
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

/// Título de sección dentro del recuadro.
class _CardSectionLabel extends StatelessWidget {
  const _CardSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.eyebrow.copyWith(color: AppColors.inkMuted),
      ),
    );
  }
}
