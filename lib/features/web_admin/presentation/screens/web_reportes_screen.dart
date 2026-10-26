import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../risks/domain/risk_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

String _ago(DateTime at) {
  final Duration d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays < 7) return 'hace ${d.inDays} d';
  return Fmt.dayMonthShort(at);
}

WebChipTone _kindTone(RiskKind k) => switch (k) {
      RiskKind.grieta || RiskKind.humo => WebChipTone.brand,
      RiskKind.cable => WebChipTone.warn,
      _ => WebChipTone.neutral,
    };

/// Lo que la comunidad ve antes de que sea una emergencia, en tres columnas:
/// nuevos, en revisión y atendidos.
class WebReportesScreen extends StatefulWidget {
  const WebReportesScreen({super.key});

  @override
  State<WebReportesScreen> createState() => _WebReportesScreenState();
}

class _WebReportesScreenState extends State<WebReportesScreen> {
  late Future<List<RiskReport>> _reports;
  final TextEditingController _search = TextEditingController();
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _reports = AppScope.of(context).riskRepository!.loadInbox());

  Future<void> _set(RiskReport r, RiskStatus status) async {
    try {
      await AppScope.of(context).riskRepository!.setStatus(r.id, status);
      if (!mounted) return;
      WebNav.of(context).refreshBadges();
      _reload();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cambiar estado de reporte (panel web)');
      if (mounted) webToast(context, 'No se pudo cambiar el estado.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Reportes de riesgo',
      subtitle: 'Lo que la comunidad ve antes de que sea una emergencia',
      actions: <Widget>[WebSearchBox(controller: _search, hint: 'Buscar reporte', onChanged: (_) => setState(() {}))],
      children: <Widget>[
        WebFuture<List<RiskReport>>(
          future: _reports,
          onRetry: _reload,
          errorText: 'No pudimos cargar los reportes.',
          builder: (BuildContext context, List<RiskReport> all) {
            final String q = _search.text.trim().toLowerCase();
            final List<RiskReport> list = all.where((RiskReport r) {
              if (q.isEmpty) return true;
              return r.place.toLowerCase().contains(q) ||
                  r.kind.label.toLowerCase().contains(q) ||
                  (r.details?.toLowerCase().contains(q) ?? false);
            }).toList()
              ..sort((RiskReport a, RiskReport b) => b.createdAt.compareTo(a.createdAt));

            List<RiskReport> of(RiskStatus s) => list.where((RiskReport r) => r.status == s).toList();
            final List<RiskReport> closed = list
                .where((RiskReport r) => r.status == RiskStatus.atendido || r.status == RiskStatus.descartado)
                .toList();

            return LayoutBuilder(builder: (BuildContext context, BoxConstraints box) {
              final List<Widget> columns = <Widget>[
                _Column(title: 'Nuevos', tone: WebChipTone.brand, reports: of(RiskStatus.nuevo), nav: nav, onSet: _set),
                _Column(title: 'En revisión', tone: WebChipTone.warn, reports: of(RiskStatus.enRevision), nav: nav, onSet: _set),
                _Column(title: 'Cerrados', tone: WebChipTone.good, reports: closed, nav: nav, onSet: _set, max: 8),
              ];
              if (box.maxWidth < 900) {
                return Column(children: <Widget>[for (final Widget c in columns) Padding(padding: const EdgeInsets.only(bottom: 16), child: c)]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < columns.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: columns[i]),
                  ],
                ],
              );
            });
          },
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.title,
    required this.tone,
    required this.reports,
    required this.nav,
    required this.onSet,
    this.max,
  });

  final String title;
  final WebChipTone tone;
  final List<RiskReport> reports;
  final WebNav nav;
  final Future<void> Function(RiskReport r, RiskStatus s) onSet;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final List<RiskReport> shown = max == null ? reports : reports.take(max!).toList();
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WebPanelHeader(title: title, trailing: WebChip('${reports.length}', tone: tone)),
          const SizedBox(height: 12),
          if (shown.isEmpty) Text('Nada por aquí.', style: WebText.small),
          for (final RiskReport r in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WebPanel(
                padding: const EdgeInsets.all(14),
                color: WebColors.page,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      WebChip(r.kind.label, tone: _kindTone(r.kind)),
                      const SizedBox(width: 8),
                      Text(_ago(r.createdAt), style: WebText.small),
                    ]),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => nav.open(WebReporteDetalleScreen(report: r)),
                      child: Text(r.place, style: WebText.strong.copyWith(color: WebColors.brandDark)),
                    ),
                    if (r.details != null && r.details!.isNotEmpty) Text(r.details!, style: WebText.small, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      <String>[if (r.reporterRole != null) r.reporterRole!, if (r.reporterGrade != null) r.reporterGrade!].join(' · '),
                      style: WebText.small,
                    ),
                    if (r.status == RiskStatus.nuevo)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: WebButton(label: 'Pasar a revisión', small: true, dark: true, onPressed: () => onSet(r, RiskStatus.enRevision)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Un reporte con su historial y lo que coordinación puede hacer con él.
class WebReporteDetalleScreen extends StatefulWidget {
  const WebReporteDetalleScreen({required this.report, super.key});

  final RiskReport report;

  @override
  State<WebReporteDetalleScreen> createState() => _WebReporteDetalleScreenState();
}

class _WebReporteDetalleScreenState extends State<WebReporteDetalleScreen> {
  late RiskStatus _status = widget.report.status;
  bool _busy = false;

  Future<void> _set(RiskStatus status) async {
    final WebNav nav = WebNav.of(context);
    setState(() => _busy = true);
    try {
      await AppScope.of(context).riskRepository!.setStatus(widget.report.id, status);
      if (!mounted) return;
      setState(() => _status = status);
      nav.refreshBadges();
      webToast(context, 'Estado actualizado: ${status.label}');
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'estado de reporte (detalle web)');
      if (mounted) webToast(context, 'No se pudo cambiar el estado.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final RiskReport r = widget.report;
    return WebPageFrame(
      title: '${r.kind.label} · ${r.place}',
      subtitle: 'Reportado ${Fmt.dayMonth(r.createdAt)} a las ${Fmt.hour(r.createdAt)}',
      actions: const <Widget>[WebBackButton()],
      children: <Widget>[
        WebSplit(
          main: WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  WebChip(r.kind.label, tone: _kindTone(r.kind)),
                  const SizedBox(width: 8),
                  WebChip(_status.label, tone: _status == RiskStatus.nuevo ? WebChipTone.brand : (_status == RiskStatus.enRevision ? WebChipTone.warn : WebChipTone.good)),
                ]),
                const SizedBox(height: 14),
                Text(
                  r.details == null || r.details!.isEmpty ? 'Sin descripción.' : '“${r.details}”',
                  style: WebText.body.copyWith(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  <String>[if (r.reporterName != null) r.reporterName!, if (r.reporterRole != null) r.reporterRole!, if (r.reporterGrade != null) r.reporterGrade!].join(' · '),
                  style: WebText.small,
                ),
                const SizedBox(height: 20),
                Text('Estado', style: WebText.label),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                  for (final RiskStatus s in RiskStatus.values)
                    WebOption(label: s.label, selected: s == _status, onTap: _busy ? null : () => _set(s)),
                ]),
                if (r.handledBy != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text('Atendido por ${r.handledBy}', style: WebText.small),
                ],
              ],
            ),
          ),
          side: const WebUnavailable(
            title: 'Prioridad, responsable y bloqueo de tramos',
            detail: 'El servidor todavía no guarda estos campos de un reporte. Por ahora coordinación cambia el estado y la persona que reportó lo ve en su app.',
          ),
        ),
      ],
    );
  }
}
