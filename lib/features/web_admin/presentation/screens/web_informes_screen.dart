import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/alert_level.dart';
import '../../../drills/domain/drill_repository.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

WebChipTone _levelTone(AlertLevel l) => switch (l) {
      AlertLevel.roja => WebChipTone.brand,
      AlertLevel.naranja => WebChipTone.warn,
      AlertLevel.amarilla => WebChipTone.neutral,
    };

String _levelName(AlertLevel l) => switch (l) {
      AlertLevel.roja => 'Evacuar',
      AlertLevel.naranja => 'Precaución',
      AlertLevel.amarilla => 'Informativo',
    };

/// Evidencia para el comité de gestión del riesgo: las alertas que se han
/// emitido y cómo salieron los simulacros.
class WebInformesScreen extends StatefulWidget {
  const WebInformesScreen({super.key});

  @override
  State<WebInformesScreen> createState() => _WebInformesScreenState();
}

class _WebInformesScreenState extends State<WebInformesScreen> {
  late Future<(List<Alert>, DrillOverview?)> _data;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() {
    final AppScope scope = AppScope.of(context);
    setState(() {
      _data = () async {
        final List<Alert> history = await scope.alertRepository.loadHistory();
        DrillOverview? drills;
        try {
          drills = await scope.drillRepository?.load();
        } catch (error, stack) {
          ErrorReporter.report(error, stack, context: 'simulacros (informes web)');
        }
        return (history, drills);
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Informes',
      subtitle: 'Evidencia para el comité de gestión del riesgo y la Secretaría de Educación',
      children: <Widget>[
        WebFuture<(List<Alert>, DrillOverview?)>(
          future: _data,
          onRetry: _reload,
          builder: (BuildContext context, (List<Alert>, DrillOverview?) data) {
            final List<Alert> alerts = data.$1;
            final DrillOverview? drills = data.$2;
            final List<DrillResult> results = (drills?.history ?? const <DrillResult>[]).take(6).toList().reversed.toList();
            final int real = alerts.where((Alert a) => !a.isDrill).length;
            final double avg = results.isEmpty ? 0 : results.fold<int>(0, (int s, DrillResult r) => s + r.schoolPercent) / results.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                WebGrid(children: <Widget>[
                  WebStat(label: 'Alertas emitidas', value: '${alerts.length}', note: '$real reales · ${alerts.length - real} simulacros'),
                  WebStat(label: 'Simulacros hechos', value: '${drills?.history.length ?? 0}'),
                  WebStat(
                    label: 'A salvo en la meta (promedio)',
                    value: results.isEmpty ? '—' : '${avg.round()} %',
                    valueColor: results.isEmpty ? WebColors.ink : (avg >= 95 ? WebColors.good : WebColors.warnText),
                  ),
                  WebStat(label: 'Próximo simulacro', value: drills?.next == null ? 'Sin fecha' : Fmt.dayMonthShort(drills!.next!.scheduledAt)),
                ]),
                const SizedBox(height: 20),
                WebPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      WebPanelHeader(
                        title: 'Personas a salvo dentro de la meta',
                        subtitle: drills == null ? null : 'Porcentaje del colegio por simulacro · meta: 95 %',
                      ),
                      const SizedBox(height: 14),
                      if (results.isEmpty)
                        Text('Todavía no hay simulacros con resultados.', style: WebText.small)
                      else
                        _Bars(results: results),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                WebPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const WebPanelHeader(title: 'Historial de alertas'),
                      const SizedBox(height: 8),
                      WebTable(
                        headers: const <String>['Fecha', 'Evento', 'Nivel', 'Tipo', 'Alcance', ''],
                        empty: 'Todavía no se ha emitido ninguna alerta.',
                        rows: <List<Widget>>[
                          for (final Alert a in alerts)
                            <Widget>[
                              Text('${Fmt.dayMonthShort(a.issuedAt)} · ${Fmt.hour(a.issuedAt)}'),
                              Text(a.title, style: WebText.strong),
                              WebChip(_levelName(a.level), tone: _levelTone(a.level)),
                              Text(a.isDrill ? 'Simulacro' : 'Real'),
                              Text(a.scope),
                              WebButton(
                                label: 'Ver detalle',
                                secondary: true,
                                small: true,
                                onPressed: () => nav.open(WebInformeAlertaScreen(alert: a, result: _resultFor(drills, a))),
                              ),
                            ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static DrillResult? _resultFor(DrillOverview? drills, Alert a) {
    for (final DrillResult r in drills?.history ?? const <DrillResult>[]) {
      if (r.alertId == a.id) return r;
    }
    return null;
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.results});

  final List<DrillResult> results;

  @override
  Widget build(BuildContext context) {
    const double h = 150;
    return Column(children: <Widget>[
      Container(
        height: h + 28,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WebColors.field))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
          for (final DrillResult r in results)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
                Text('${r.schoolPercent} %', style: WebText.strong.copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  width: 44,
                  height: h * (r.schoolPercent.clamp(0, 100) / 100),
                  decoration: BoxDecoration(
                    color: r.schoolPercent >= 95 ? WebColors.good : WebColors.ink,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: <Widget>[
        for (final DrillResult r in results)
          Expanded(
            child: Text(
              '${Fmt.dayMonthShort(r.at)}\n${r.hazard.label[0]}${r.hazard.label.substring(1).toLowerCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: WebColors.inkMuted),
            ),
          ),
      ]),
    ]);
  }
}

/// El informe de una alerta: cómo quedó el colegio.
class WebInformeAlertaScreen extends StatefulWidget {
  const WebInformeAlertaScreen({required this.alert, this.result, super.key});

  final Alert alert;
  final DrillResult? result;

  @override
  State<WebInformeAlertaScreen> createState() => _WebInformeAlertaScreenState();
}

class _WebInformeAlertaScreenState extends State<WebInformeAlertaScreen> {
  late Future<EmergencyBoard?> _board;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _board = () async {
      try {
        return await AppScope.of(context).panelRepository?.loadBoard(widget.alert.id);
      } catch (error, stack) {
        ErrorReporter.report(error, stack, context: 'informe de alerta (panel web)');
        return null;
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final Alert a = widget.alert;
    return WebPageFrame(
      title: 'Informe · ${a.title}',
      subtitle: '${a.isDrill ? 'Simulacro' : 'Alerta real'} · ${_levelName(a.level).toLowerCase()} · ${a.scope} · ${Fmt.dayMonth(a.issuedAt)} ${Fmt.hour(a.issuedAt)}',
      actions: const <Widget>[WebBackButton()],
      children: <Widget>[
        FutureBuilder<EmergencyBoard?>(
          future: _board,
          builder: (BuildContext context, AsyncSnapshot<EmergencyBoard?> snap) {
            if (snap.connectionState != ConnectionState.done) return const WebLoadState();
            final EmergencyBoard? b = snap.data;
            if (b == null) {
              return const WebUnavailable(title: 'Sin datos del tablero', detail: 'El servidor no devolvió el resultado de esta alerta.');
            }
            final DrillResult? r = widget.result;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              WebGrid(children: <Widget>[
                WebStat(label: 'A salvo al final', value: '${b.safePercent} %', note: '${b.safe} de ${b.total}'),
                WebStat(label: 'Sin confirmar', value: '${b.noResponse}'),
                WebStat(label: 'Pidieron ayuda', value: '${b.needHelp}'),
                WebStat(label: 'A salvo en la meta', value: r == null ? '—' : '${r.schoolPercent} %'),
              ]),
              const SizedBox(height: 20),
              WebPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  const WebPanelHeader(title: 'Por curso'),
                  const SizedBox(height: 8),
                  WebTable(
                    headers: const <String>['Curso', 'A salvo', 'Sin confirmar', 'Piden ayuda', 'Avance'],
                    empty: 'Sin datos por curso.',
                    rows: <List<Widget>>[
                      for (final GradeProgress g in b.byGrade)
                        <Widget>[
                          Text(g.grade, style: WebText.strong),
                          Text('${g.safe} de ${g.total}'),
                          Text('${g.noResponse}'),
                          Text('${g.needHelp}'),
                          SizedBox(width: 160, child: WebMeter(fraction: g.progress, color: WebColors.good)),
                        ],
                    ],
                  ),
                ]),
              ),
            ]);
          },
        ),
      ],
    );
  }
}
