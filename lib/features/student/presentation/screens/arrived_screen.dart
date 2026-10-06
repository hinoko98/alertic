import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/safety_report.dart';
import '../../../help/presentation/help_screen.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../onboarding/domain/enrollment.dart';
import 'safe_confirmed_screen.dart';

/// Pantalla 10: llegaste al punto de encuentro.
///
/// Pantalla verde: aquí se acaba la evacuación. Recuerda qué hacer mientras se
/// espera y deja confirmar que se está a salvo —lo que alimenta el tablero— o
/// pedir ayuda para otra persona.
class ArrivedScreen extends StatefulWidget {
  const ArrivedScreen({
    required this.student,
    this.point,
    this.alert,
    this.onResponded,
    super.key,
  });

  final StudentEnrollment student;

  /// El punto al que llegó, si no es el asignado (escogió otro en el mapa).
  final MeetingPoint? point;
  final Alert? alert;
  final VoidCallback? onResponded;

  @override
  State<ArrivedScreen> createState() => _ArrivedScreenState();
}

class _ArrivedScreenState extends State<ArrivedScreen> {
  bool _sending = false;
  String? _error;

  Future<void> _confirmSafe() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final NavigatorState navigator = Navigator.of(context);
    try {
      final Alert? alert = widget.alert;
      // Sin alerta (un repaso de la ruta) no hay a quién reportarle: se muestra
      // la confirmación sin mandar nada.
      if (alert != null) {
        await AppScope.of(context).alertRepository.submitSafetyReport(
              SafetyReport(
                alertId: alert.id,
                status: SafetyStatus.safe,
                location: ReportedLocation.atMeetingPoint,
                reportedAt: DateTime.now(),
              ),
            );
        widget.onResponded?.call();
      }
      navigator.pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => SafeConfirmedScreen(
            student: widget.student,
            confirmedAt: DateTime.now(),
            alertStillActive: alert != null,
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'confirmar a salvo');
      if (mounted) {
        setState(
          () => _error = 'No se pudo enviar. Quédate en el punto; lo reintentamos '
              'cuando vuelva la conexión.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _helpSomeone() async {
    final bool? sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => HelpScreen(
          alert: widget.alert,
          classroom: widget.student.classroom,
          initialKind: HelpKind.someoneElse,
        ),
      ),
    );
    if (sent == true) widget.onResponded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point ?? widget.student.meetingPoint;

    return Scaffold(
      backgroundColor: AppColors.success,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.pin_drop_outlined, size: 36, color: AppColors.success),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Llegaste al punto ${point.code}',
                key: const Key('llegaste'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.onBrand,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                point.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onBrand),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Quédate con tu grupo y espera las instrucciones de tu docente o '
                'de coordinación.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Reminder('No regreses a los salones hasta que lo indiquen.'),
                    SizedBox(height: 6),
                    _Reminder('Aléjate de muros, postes y cables.'),
                  ],
                ),
              ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _error!,
                    key: const Key('error-llegada'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              _WhiteButton(
                key: const Key('confirmar-a-salvo'),
                label: 'Confirmar que estoy a salvo',
                filled: true,
                loading: _sending,
                onTap: _confirmSafe,
              ),
              const SizedBox(height: AppSpacing.sm),
              _WhiteButton(
                key: const Key('alguien-necesita-ayuda'),
                label: 'Alguien necesita ayuda',
                filled: false,
                onTap: _helpSomeone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reminder extends StatelessWidget {
  const _Reminder(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.check, size: 15, color: AppColors.onBrand),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.onBrand)),
        ),
      ],
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({
    required this.label,
    required this.filled,
    required this.onTap,
    this.loading = false,
    super.key,
  });

  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        side: const BorderSide(color: Colors.white70),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.success),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: filled ? AppColors.success : AppColors.onBrand,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
