import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../app/shell_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../incidents/domain/incident.dart';
import '../../../alerts/presentation/widgets/alert_level_style.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/person_name.dart';
import '../widgets/hazard_report_sheet.dart';
import '../widgets/home_tile.dart';

/// Pantalla 10: el inicio del estudiante.
///
/// En calma responde una sola pregunta: dónde me toca si suena la alarma. Con
/// una alerta activa, esa alerta manda sobre todo lo demás.
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({required this.student, super.key});

  final StudentEnrollment student;

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _TopBar(student: student),
            Expanded(
              child: StreamBuilder<Alert?>(
                stream: scope.alertRepository.watchActiveAlert(),
                builder: (BuildContext context, AsyncSnapshot<Alert?> snapshot) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      AppSpacing.lg,
                      AppSpacing.screenGutter,
                      AppSpacing.xl,
                    ),
                    children: <Widget>[
                      _SchoolStatus(alert: snapshot.data),
                      const SizedBox(height: AppSpacing.xl),
                      _MeetingPointCard(student: student),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: HomeTile(
                              icon: Icons.menu_book_outlined,
                              label: 'QUÉ HACER',
                              onTap: () => _openTab(context, 'Guía'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: HomeTile(
                              icon: Icons.history,
                              label: 'HISTORIAL',
                              onTap: () => _openTab(context, 'Perfil'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            _ReportButton(student: student),
          ],
        ),
      ),
    );
  }

  static void _openTab(BuildContext context, String label) =>
      ShellScope.maybeOf(context)?.openTab(label);
}

/// Encabezado con quién es la persona y si el celular tiene señal.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.student});

  final StudentEnrollment student;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'ALERTIC',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '${PersonName.short(student.fullName)} · ${student.grade}'
                      .toUpperCase(),
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          // TODO(conexión): reflejar el estado real de la red cuando exista el
          // backend. Hoy es fijo para no mentirle a la persona con un ícono que
          // no mide nada.
          const _ConnectionChip(),
        ],
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 5),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.wifi, size: 13, color: AppColors.ink),
          SizedBox(width: 5),
          Text(
            'EN LÍNEA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// El estado del colegio: sin alertas, o la alerta activa.
class _SchoolStatus extends StatelessWidget {
  const _SchoolStatus({required this.alert});

  final Alert? alert;

  @override
  Widget build(BuildContext context) {
    final Alert? active = alert;
    if (active == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('ESTADO DEL COLEGIO', style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          const Text('SIN ALERTAS', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Jornada normal · revisado ${_nowLabel()}',
            style: AppTextStyles.caption,
          ),
        ],
      );
    }

    final AlertLevelStyle style = AlertLevelStyle.of(active.level);
    return Container(
      width: double.infinity,
      color: style.headerColor,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${active.level.label} · ACTIVA · ${active.issuedAtLabel}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: style.headerForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            active.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.05,
              color: style.headerForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            active.scope,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: style.headerForeground,
            ),
          ),
        ],
      ),
    );
  }

  static String _nowLabel() {
    final DateTime now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }
}

/// A dónde le toca ir a esta persona. Es lo primero que se busca en el inicio.
class _MeetingPointCard extends StatelessWidget {
  const _MeetingPointCard({required this.student});

  final StudentEnrollment student;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('TU PUNTO DE ENCUENTRO', style: AppTextStyles.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: AppColors.surface,
          shape: const Border.fromBorderSide(
            BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () => ShellScope.maybeOf(context)?.openTab('Mapa'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    color: AppColors.brand,
                    alignment: Alignment.center,
                    child: Text(
                      student.meetingPoint.code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.onBrand,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          student.meetingPoint.name,
                          style: AppTextStyles.itemTitle.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          student.meetingPoint.routeHint,
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: AppColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reportar una emergencia que el colegio todavía no vio.
class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.student});

  final StudentEnrollment student;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        color: AppColors.brand,
        child: InkWell(
          onTap: () => _openSheet(context),
          child: SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.campaign_outlined,
                  size: 20,
                  color: AppColors.onBrand,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'REPORTAR EMERGENCIA',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.onBrand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final Hazard? hazard = await showModalBottomSheet<Hazard>(
      context: context,
      // Que pueda usar toda la altura que necesite: con el límite por omisión
      // (poco más de la mitad) las opciones no caben en un celular bajo.
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext context) => const HazardReportSheet(),
    );
    if (hazard == null || !context.mounted) {
      return;
    }

    // Se toman antes de esperar: después de un `await` el contexto puede ya no
    // estar, y el mensaje tiene que salir de todos modos.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final IncidentRepository? repository =
        AppScope.of(context).incidentRepository;

    void say(String message) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    if (repository == null) {
      say('No se pudo enviar el reporte. Avisa a tu docente en persona.');
      return;
    }

    try {
      await repository.report(hazard);
      // Solo se dice «enviado» cuando el servidor lo confirmó. Un reporte de
      // incendio que parece haber salido y no salió es peor que un error: quien
      // lo hizo cree que ya avisó, y nadie se entera.
      say(
        'Reporte de ${hazard.reportLabel.toLowerCase()} enviado. Tu docente y '
        'coordinación ya lo ven.',
      );
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reportar emergencia');
      say(
        error is ApiException && error.statusCode != null
            ? error.message
            : 'No se pudo enviar el reporte. Avisa a tu docente en persona.',
      );
    }
  }
}
