import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/step_progress.dart';
import '../../domain/enrollment.dart';
import '../../domain/enrollment_failure.dart';
import '../../domain/personal_code.dart';
import '../widgets/info_note.dart';
import '../widgets/personal_code_field.dart';

/// Pantalla 03: la persona escribe el código personal que le entregó el colegio.
///
/// Solo estudiantes y acudientes: los docentes entran con correo y contraseña.
class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  String _digits = '';
  String? _error;
  bool _isValidating = false;

  bool get _isComplete => _digits.length == PersonalCode.digitsLength;

  void _onChanged(String digits) {
    setState(() {
      _digits = digits;
      _error = null;
    });
  }

  Future<void> _validate() async {
    if (_isValidating) {
      return;
    }

    final PersonalCode? code = PersonalCode.tryParse(_digits);
    if (code == null) {
      setState(() => _error = 'Revisa el código: son 8 caracteres del carné.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final Enrollment enrollment =
          await AppScope.of(context).enrollmentRepository.findByCode(code);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.confirmIdentity,
        arguments: enrollment,
      );
    } on EnrollmentFailure catch (failure, stack) {
      // Errores esperados: el mensaje ya viene escrito para la persona.
      ErrorReporter.report(failure, stack, context: 'validar código');
      _showError(failure.message);
    } catch (error, stack) {
      // Lo que no previmos: mensaje genérico arriba, detalle completo en el log.
      ErrorReporter.report(error, stack, context: 'validar código');
      _showError('No pudimos validar el código. Intenta otra vez.');
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const StepProgress(currentStep: 2),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('TU CÓDIGO', style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Cada estudiante y cada acudiente tiene uno propio. Lo '
                      'entrega secretaría o el director de grupo.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PersonalCodeField(
                      onChanged: _onChanged,
                      onCompleted: _validate,
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _error!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.brand),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const InfoNote(
                      title: '¿No tienes código?',
                      body: 'Pídelo en secretaría del IIC. Es de un solo uso; '
                          'si cambias de celular, te dan uno nuevo.',
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
              child: PrimaryButton(
                label: 'VALIDAR CÓDIGO',
                isLoading: _isValidating,
                onPressed: _isComplete ? _validate : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
