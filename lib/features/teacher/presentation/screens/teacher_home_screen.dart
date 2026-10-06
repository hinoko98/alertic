import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/shell_scope.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../account/presentation/alerts_feed_screen.dart';
import '../../../drills/presentation/drills_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/presentation/widgets/alert_level_style.dart';
import '../../../alerts/presentation/widgets/end_alert.dart';
import '../../../incidents/domain/incident.dart';
import '../../../incidents/presentation/incidents_screen.dart';
import '../../../incidents/presentation/open_incidents.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../../student/presentation/widgets/home_tile.dart';
import 'group_roster_screen.dart';
import 'new_alert_screen.dart';

/// El inicio del docente.
///
/// Con una alerta activa, lo primero es la lista de su grupo: el docente es
/// quien responde por 32 personas que puede ver con sus propios ojos. Sin
/// alerta, lo primero es el botón de emitirla.
class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({required this.teacher, super.key});

  final TeacherEnrollment teacher;

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final String? school = ShellScope.maybeOf(context)?.schoolName;

    return StreamBuilder<Alert?>(
      stream: scope.alertRepository.watchActiveAlert(),
      builder: (BuildContext context, AsyncSnapshot<Alert?> snapshot) {
        final Alert? active = snapshot.data;

        return AppPage(
          title: 'Hola, ${PersonName.firstName(teacher.fullName)}',
          subtitle: <String>['Docente', ?school].join(' · '),
          bottom: _IssueButton(
            teacher: teacher,
            activeAlert: active,
            // Con confirmación: ver `confirmEndAlert`.
            onEnd: () => confirmEndAlert(context, active!),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            children: <Widget>[
              if (active != null) ...<Widget>[
                _ActiveAlertBanner(
                  alert: active,
                  onOpen: () => _openRoster(context, active),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SectionLabel('Ahora estás con', padding: EdgeInsets.only(bottom: AppSpacing.sm)),
              _CurrentGroupCard(teacher: teacher),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: HomeTile(
                      icon: Icons.people_outline,
                      label: 'LISTA DEL GRUPO',
                      onTap: () => active == null
                          ? _noAlert(context)
                          : _openRoster(context, active),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    // El número es el de reportes sin atender de sus grupos,
                    // según el servidor, y cambia solo cuando llega uno.
                    child: OpenIncidents(
                      builder: (BuildContext context, OpenIncidentsState state) =>
                          HomeTile(
                        icon: Icons.mark_email_unread_outlined,
                        label: state.incidents.isEmpty
                            ? 'REPORTES'
                            : 'REPORTES · ${state.incidents.length}',
                        onTap: () => _openReports(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: HomeTile(
                      icon: Icons.event_outlined,
                      label: 'Simulacros',
                      onTap: () => pushInShell<void>(context, (_) => const DrillsScreen()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: HomeTile(
                      icon: Icons.notifications_none,
                      label: 'Alertas y avisos',
                      onTap: () => pushInShell<void>(context, (_) => const AlertsFeedScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRoster(BuildContext context, Alert alert) {
    final String? grade = teacher.primaryGroup;
    if (grade == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Todavía no tienes un grupo asignado. Pídeselo a coordinación.'),
          ),
        );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GroupRosterScreen(alert: alert, grade: grade),
      ),
    );
  }

  static void _noAlert(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('La lista se llena cuando hay una alerta activa.'),
        ),
      );
  }

  /// Abre la bandeja de reportes. Desde ahí, el docente puede convertir uno en
  /// una alerta: la pantalla de emitir ya sabe de qué amenaza se trata.
  void _openReports(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => IncidentsScreen(
          onEscalate: (Incident incident) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => NewAlertScreen(
                  groups: teacher.groups,
                  initialHazard: incident.hazard,
                  incidentId: incident.id,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActiveAlertBanner extends StatelessWidget {
  const _ActiveAlertBanner({required this.alert, required this.onOpen});

  final Alert alert;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AlertLevelStyle style = AlertLevelStyle.of(alert.level);

    return Material(
      color: style.headerColor,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(style.icon, size: 20, color: style.headerForeground),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${alert.level.label} · ACTIVA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: style.headerForeground,
                      ),
                    ),
                    Text(
                      alert.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: style.headerForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                size: 18,
                color: style.headerForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentGroupCard extends StatelessWidget {
  const _CurrentGroupCard({required this.teacher});

  final TeacherEnrollment teacher;

  @override
  Widget build(BuildContext context) {
    final String group = teacher.primaryGroup ?? 'Sin grupo';
    final GroupSummary? summary = teacher.summaryFor(group);

    // «Aula 7 · Bloque A» se parte en dos para el recuadro: el salón grande y el
    // bloque debajo. Si el servidor no lo tiene, se dice con un guion y no se
    // inventa uno.
    final List<String> place = (summary?.classroom ?? '').split(' · ');

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    group,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Text(teacher.subject, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Divider(height: 1),
          IntrinsicHeight(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _Stat(
                    value: summary == null ? '—' : '${summary.enrolled}',
                    label: 'Matriculados',
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.border,
                ),
                Expanded(
                  child: _Stat(
                    value: place.first.isEmpty ? '—' : place.first,
                    label: place.length > 1 ? place[1] : 'Salón',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Emitir una alerta, o finalizar la que está activa.
class _IssueButton extends StatelessWidget {
  const _IssueButton({
    required this.teacher,
    required this.activeAlert,
    required this.onEnd,
  });

  final TeacherEnrollment teacher;
  final Alert? activeAlert;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final bool hasAlert = activeAlert != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.md,
      ),
      child: PrimaryButton(
        key: const Key('emitir-o-finalizar'),
        label: hasAlert ? 'FINALIZAR ALERTA' : 'GENERAR ALERTA',
        icon: hasAlert ? Icons.stop_circle_outlined : Icons.campaign_outlined,
        background: hasAlert ? AppColors.ink : AppColors.brand,
        onPressed: () {
          if (hasAlert) {
            onEnd();
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => NewAlertScreen(groups: teacher.groups),
            ),
          );
        },
      ),
    );
  }
}
