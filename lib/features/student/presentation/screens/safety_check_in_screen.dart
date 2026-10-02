import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/safety_report.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Pantalla 11: la persona dice cómo está y dónde está.
///
/// Es la pantalla que alimenta el tablero del colegio. Todo lo que se manda son
/// opciones cerradas: sin campos de texto no hay nada que un celular pueda
/// inyectar en la pantalla del docente.
class SafetyCheckInScreen extends StatefulWidget {
  const SafetyCheckInScreen({
    required this.alert,
    required this.student,
    required this.onSent,
    this.initialStatus = SafetyStatus.safe,
    super.key,
  });

  final Alert alert;
  final StudentEnrollment student;

  /// El reporte quedó registrado.
  final VoidCallback onSent;

  /// Con qué botón entró desde la alerta roja.
  final SafetyStatus initialStatus;

  @override
  State<SafetyCheckInScreen> createState() => _SafetyCheckInScreenState();
}

class _SafetyCheckInScreenState extends State<SafetyCheckInScreen> {
  late SafetyStatus _status = widget.initialStatus;
  ReportedLocation _location = ReportedLocation.atMeetingPoint;
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await AppScope.of(context).alertRepository.submitSafetyReport(
            SafetyReport(
              alertId: widget.alert.id,
              status: _status,
              location: _location,
              reportedAt: DateTime.now(),
              // TODO(ubicación): adjuntar el GPS cuando el permiso esté
              // concedido. Sin permiso se manda igual: el reporte vale aunque
              // no se sepa dónde está.
            ),
          );
      if (!mounted) {
        return;
      }
      widget.onSent();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reportar estado');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo enviar. Lo reintentamos solo; quédate en el punto '
                'de encuentro.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: double.infinity,
              color: AppColors.levelRed,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenGutter,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                'ALERTA ${widget.alert.level.label} · '
                '${widget.alert.hazard.label} · ${widget.alert.issuedAtLabel}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.onBrand,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                children: <Widget>[
                  const Text('¿CÓMO ESTÁS?', style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _StatusButton(
                          status: SafetyStatus.safe,
                          icon: Icons.check,
                          label: 'ESTOY\nBIEN',
                          selected: _status == SafetyStatus.safe,
                          onTap: () =>
                              setState(() => _status = SafetyStatus.safe),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatusButton(
                          status: SafetyStatus.needsHelp,
                          icon: Icons.error_outline,
                          label: 'NECESITO\nAYUDA',
                          selected: _status == SafetyStatus.needsHelp,
                          onTap: () =>
                              setState(() => _status = SafetyStatus.needsHelp),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const Text('¿DÓNDE ESTÁS?', style: AppTextStyles.eyebrow),
                  const SizedBox(height: AppSpacing.sm),
                  for (final ReportedLocation location
                      in ReportedLocation.values)
                    _LocationOption(
                      location: location,
                      label: location == ReportedLocation.atMeetingPoint
                          ? 'En el punto ${widget.student.meetingPoint.code} · '
                              '${widget.student.meetingPoint.name}'
                          : location.label,
                      selected: _location == location,
                      onTap: () => setState(() => _location = location),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _Recipients(student: widget.student),
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
                label: 'ENVIAR',
                background: AppColors.ink,
                isLoading: _sending,
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los dos botones grandes: estoy bien, necesito ayuda.
class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.status,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final SafetyStatus status;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isHelp = status == SafetyStatus.needsHelp;
    final Color background = selected
        ? (isHelp ? AppColors.ink : AppColors.brand)
        : AppColors.surface;
    final Color foreground =
        selected ? AppColors.onBrand : AppColors.inkMuted;

    return Material(
      color: background,
      shape: Border.fromBorderSide(
        BorderSide(color: selected ? background : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 128,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Icon(icon, size: 26, color: foreground),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.location,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ReportedLocation location;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? const Color(0xFFFDEDEA) : AppColors.surface,
        shape: Border.fromBorderSide(
          BorderSide(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(
                      Icons.my_location,
                      size: 16,
                      color: AppColors.brand,
                    ),
                  ),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quién va a ver este reporte. Se dice antes de enviarlo, no después.
class _Recipients extends StatelessWidget {
  const _Recipients({required this.student});

  final StudentEnrollment student;

  /// Une nombres como se leen en voz alta: `A, B y C`.
  static String _asList(List<String> names) {
    if (names.length < 2) {
      return names.join();
    }
    final String last = names.last;
    final String rest = names.sublist(0, names.length - 1).join(', ');
    return '$rest y $last';
  }

  @override
  Widget build(BuildContext context) {
    final List<String> names = <String>[
      student.homeroomTeacher,
      ...student.guardians.map((GuardianLink g) => g.fullName),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.people_outline, size: 14, color: AppColors.inkFaint),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Lo verán ${_asList(names)}. Si no hay señal, se envía por SMS.',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
