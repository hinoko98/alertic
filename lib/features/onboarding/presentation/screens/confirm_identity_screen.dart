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

/// Pantallas 04 y 05: la persona revisa los datos que el colegio cargó y
/// confirma que son suyos.
///
/// Es una sola pantalla para los dos roles que entran por código: el diseño es
/// el mismo y solo cambia el contenido del recuadro.
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
      if (!mounted) {
        return;
      }
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
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  void _reportWrongData() {
    _showMessage(
      'Avisa en secretaría del IIC para que corrijan tus datos.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final CodeEnrollment enrollment = widget.enrollment;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'CÓDIGO VÁLIDO',
                      style: AppTextStyles.eyebrow.copyWith(
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('¿ERES TÚ?', style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppSpacing.lg),
                    switch (enrollment) {
                      StudentEnrollment() => _StudentCard(enrollment),
                      GuardianEnrollment() => _GuardianCard(enrollment),
                    },
                    const SizedBox(height: AppSpacing.md),
                    const LockedDataNote(
                      message: 'El colegio registró estos datos. No se pueden '
                          'editar desde la app.',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  PrimaryButton(
                    label: 'SÍ, SOY YO',
                    isLoading: _isConfirming,
                    onPressed: _confirm,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: switch (enrollment) {
                      StudentEnrollment() => 'MIS DATOS NO SON CORRECTOS',
                      GuardianEnrollment() => 'FALTA UN HIJO O HAY UN ERROR',
                    },
                    centered: true,
                    onPressed: _isConfirming ? null : _reportWrongData,
                  ),
                ],
              ),
            ),
          ],
        ),
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
        IdentityHeader(
          role: enrollment.roleLabel,
          fullName: enrollment.fullName,
        ),
        const Divider(height: 1),
        DetailRow(
          label: 'Grado',
          value: '${enrollment.grade} · ${enrollment.shift}',
        ),
        const Divider(height: 1),
        DetailRow(
          label: 'Director de grupo',
          value: enrollment.homeroomTeacher,
        ),
        const Divider(height: 1),
        const _CardSectionLabel('Acudientes vinculados'),
        for (final GuardianLink guardian in enrollment.guardians)
          LinkedPersonRow(
            name: guardian.fullName,
            detail: guardian.relationship,
          ),
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
        IdentityHeader(
          role: enrollment.roleLabel,
          fullName: enrollment.fullName,
        ),
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
      child: Text(label.toUpperCase(), style: AppTextStyles.eyebrow),
    );
  }
}
