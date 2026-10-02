import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../alerts/presentation/widgets/hazard_icon.dart';
import '../domain/incident.dart';
import 'open_incidents.dart';

/// La bandeja de reportes de emergencia.
///
/// La usan el docente (los de sus grupos) y coordinación (todos). Es la misma
/// pantalla porque la pregunta es la misma: «¿qué está avisando la gente que yo
/// todavía no vi?». Qué le toca a cada quien lo decide el servidor, no esta
/// pantalla.
///
/// No se desplaza sola: es una columna, para poder ponerla dentro de otra lista
/// o dentro de un `Scaffold` con su propio desplazamiento.
class IncidentInbox extends StatelessWidget {
  const IncidentInbox({this.onEscalate, super.key});

  /// Convierte un reporte en una alerta para el colegio. Si es nulo, el botón no
  /// se muestra.
  final void Function(Incident incident)? onEscalate;

  @override
  Widget build(BuildContext context) {
    return OpenIncidents(
      builder: (BuildContext context, OpenIncidentsState state) {
        if (state.loading) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (state.failed)
              _Notice(
                text: 'No pudimos actualizar. Lo que ves puede no ser lo último.',
                action: 'REINTENTAR',
                onAction: state.reload,
              ),
            if (state.incidents.isEmpty && !state.failed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Nadie ha reportado nada. Cuando alguien avise de una '
                  'emergencia, aparece aquí al instante.',
                  style: AppTextStyles.body,
                ),
              ),
            for (final Incident incident in state.incidents)
              _IncidentCard(
                incident: incident,
                onEscalate: onEscalate,
                onChanged: state.reload,
              ),
          ],
        );
      },
    );
  }
}

class _IncidentCard extends StatefulWidget {
  const _IncidentCard({
    required this.incident,
    required this.onChanged,
    this.onEscalate,
  });

  final Incident incident;
  final Future<void> Function() onChanged;
  final void Function(Incident incident)? onEscalate;

  @override
  State<_IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<_IncidentCard> {
  bool _busy = false;

  Future<void> _handle(IncidentStatus status) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    try {
      await AppScope.of(context)
          .incidentRepository!
          .handle(widget.incident.id, status);
      await widget.onChanged();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'atender reporte');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                error is ApiException
                    ? error.message
                    : 'No se pudo registrar. Intenta otra vez.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Incident incident = widget.incident;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.brand, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(hazardIcon(incident.hazard), size: 20, color: AppColors.brand),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      incident.hazard.reportLabel,
                      style: AppTextStyles.itemTitle,
                    ),
                  ),
                  Text(_ago(incident.createdAt), style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                <String>[
                  incident.reporterName,
                  if (incident.reporterGrade != null) incident.reporterGrade!,
                ].join(' · '),
                style: AppTextStyles.body,
              ),
              if (incident.details != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text('«${incident.details}»', style: AppTextStyles.caption),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _Action(
                    label: 'YA LO ATENDÍ',
                    filled: true,
                    onTap: _busy ? null : () => _handle(IncidentStatus.handled),
                  ),
                  _Action(
                    label: 'DESCARTAR',
                    onTap: _busy ? null : () => _handle(IncidentStatus.dismissed),
                  ),
                  if (widget.onEscalate != null)
                    _Action(
                      label: 'EMITIR ALERTA',
                      onTap: _busy ? null : () => widget.onEscalate!(incident),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// «hace 3 min». Un reporte de hace una hora ya es otra clase de problema.
  static String _ago(DateTime when) {
    final Duration elapsed = DateTime.now().difference(when);
    if (elapsed.inSeconds < 60) return 'ahora';
    if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
    return 'hace ${elapsed.inDays} d';
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.ink : AppColors.surface,
      shape: Border.fromBorderSide(
        BorderSide(color: filled ? AppColors.ink : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: onTap == null
                  ? AppColors.inkFaint
                  : (filled ? AppColors.onBrand : AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.action, required this.onAction});

  final String text;
  final String action;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: AppColors.brand),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: Text(
              action,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
