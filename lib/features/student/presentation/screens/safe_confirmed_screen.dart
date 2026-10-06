import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/format.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../account/domain/account_repository.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/person_name.dart';

/// Pantalla 11: estás a salvo.
///
/// Cierra el ciclo: dice a quién se le avisó. Solo se afirma lo que el sistema de
/// verdad hace: a los **acudientes que cargó el colegio** les llega un aviso (si
/// tienen la app y la persona no lo apagó), y el **director de grupo** ve la
/// confirmación en su lista. Los contactos que la persona sumó no reciben nada
/// automático, y aquí no se finge lo contrario.
class SafeConfirmedScreen extends StatefulWidget {
  const SafeConfirmedScreen({
    required this.student,
    required this.confirmedAt,
    required this.alertStillActive,
    super.key,
  });

  final StudentEnrollment student;
  final DateTime confirmedAt;
  final bool alertStillActive;

  @override
  State<SafeConfirmedScreen> createState() => _SafeConfirmedScreenState();
}

class _SafeConfirmedScreenState extends State<SafeConfirmedScreen> {
  bool _notifyFamily = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final AccountSettings? settings =
          await AppScope.of(context).accountRepository?.loadSettings();
      if (mounted && settings != null) {
        setState(() => _notifyFamily = settings.notifyFamily);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'ajustes al confirmar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentEnrollment student = widget.student;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenGutter),
                children: <Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: AppColors.successSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 40, color: AppColors.success),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Center(
                    child: Text(
                      'Estás a salvo',
                      key: Key('estas-a-salvo'),
                      style: AppTextStyles.screenTitle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Registramos tu confirmación a las ${Fmt.hour(widget.confirmedAt)} '
                      'en el punto ${student.meetingPoint.code} · ${student.meetingPoint.name}.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ),
                  const SectionLabel('Avisamos a'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (final GuardianLink guardian in student.guardians) ...<Widget>[
                          _Notified(
                            initials: PersonName.initials(guardian.fullName),
                            name: '${guardian.fullName} · ${guardian.relationship}',
                            detail: _notifyFamily
                                ? 'Aviso enviado'
                                : 'Apagaste el aviso a tu familia',
                            ok: _notifyFamily,
                          ),
                          const Divider(height: 1),
                        ],
                        _Notified(
                          initials: 'DG',
                          name: 'Director de grupo ${student.grade}',
                          detail: 'Ve tu confirmación en su lista',
                          ok: true,
                          dark: true,
                        ),
                      ],
                    ),
                  ),
                  if (widget.alertStillActive) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'La alerta sigue activa. Te avisaremos cuando sea '
                              'seguro volver o cuando tu familia pueda recogerte.',
                              style: TextStyle(fontSize: 12, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
                key: const Key('volver-al-inicio'),
                label: 'Volver al inicio',
                icon: null,
                onPressed: () => Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notified extends StatelessWidget {
  const _Notified({
    required this.initials,
    required this.name,
    required this.detail,
    required this.ok,
    this.dark = false,
  });

  final String initials;
  final String name;
  final String detail;
  final bool ok;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: dark ? AppColors.ink : AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.onBrand : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: AppTextStyles.itemTitle.copyWith(fontSize: 13)),
                Text(detail, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(
            ok ? Icons.done_all : Icons.notifications_off_outlined,
            size: 18,
            color: ok ? AppColors.success : AppColors.inkFaint,
          ),
        ],
      ),
    );
  }
}
