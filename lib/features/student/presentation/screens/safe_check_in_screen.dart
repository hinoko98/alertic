import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/safety_report.dart';
import '../../../onboarding/domain/enrollment.dart';
import 'safe_confirmed_screen.dart';

/// «Estoy a salvo» desde la alerta: la persona dice dónde está y confirma.
///
/// Es la pantalla que alimenta el tablero del colegio. Todo lo que se manda son
/// opciones cerradas: sin campos de texto no hay nada que un celular pueda
/// inyectar en la pantalla del docente.
class SafeCheckInScreen extends StatefulWidget {
  const SafeCheckInScreen({
    required this.alert,
    required this.student,
    this.onResponded,
    super.key,
  });

  final Alert alert;
  final StudentEnrollment student;

  /// El reporte quedó registrado.
  final VoidCallback? onResponded;

  @override
  State<SafeCheckInScreen> createState() => _SafeCheckInScreenState();
}

class _SafeCheckInScreenState extends State<SafeCheckInScreen> {
  ReportedLocation _location = ReportedLocation.atMeetingPoint;
  bool _sending = false;
  String? _error;

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final NavigatorState navigator = Navigator.of(context);
    try {
      await AppScope.of(context).alertRepository.submitSafetyReport(
            SafetyReport(
              alertId: widget.alert.id,
              status: SafetyStatus.safe,
              location: _location,
              reportedAt: DateTime.now(),
            ),
          );
      widget.onResponded?.call();
      navigator.pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => SafeConfirmedScreen(
            student: widget.student,
            confirmedAt: DateTime.now(),
            alertStillActive: true,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reportar estado');
      if (mounted) {
        setState(
          () => _error = 'No se pudo enviar. Quédate donde estás y vuelve a '
              'intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.student.meetingPoint;

    return AppPage(
      title: 'Estoy a salvo',
      subtitle: 'Alerta ${widget.alert.hazard.label.toLowerCase()} · ${widget.alert.issuedAtLabel}',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.screenGutter,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            key: const Key('enviar-a-salvo'),
            label: 'Confirmar que estoy a salvo',
            background: AppColors.success,
            icon: Icons.check,
            isLoading: _sending,
            onPressed: _send,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          const Text('¿Dónde estás?', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.md),
          for (final ReportedLocation place in ReportedLocation.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => setState(() => _location = place),
                color: _location == place ? AppColors.brandSoft : AppColors.surface,
                borderColor: _location == place ? AppColors.brand : AppColors.border,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _location == place ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 20,
                      color: _location == place ? AppColors.brand : AppColors.inkFaint,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        place == ReportedLocation.atMeetingPoint
                            ? 'En el punto ${point.code} · ${point.name}'
                            : place.label,
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                key: const Key('error-a-salvo'),
                style: AppTextStyles.caption.copyWith(color: AppColors.brand),
              ),
            ),
        ],
      ),
    );
  }
}
