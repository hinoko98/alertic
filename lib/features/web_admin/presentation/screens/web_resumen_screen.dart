import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert.dart';
import '../../../drills/domain/drill_repository.dart';
import '../../../panel/domain/panel_repository.dart';
import '../../../risks/domain/risk_repository.dart';
import '../../../session/domain/session.dart';
import '../web_nav.dart';
import '../web_style.dart';

/// Pantalla «Resumen» del panel web.
///
/// Cada bloque se carga por su cuenta: si el servidor no responde por los
/// reportes, el resto del tablero se sigue viendo y ese bloque dice qué falló.
class WebResumenScreen extends StatefulWidget {
  const WebResumenScreen({required this.session, super.key});

  final Session session;

  @override
  State<WebResumenScreen> createState() => _WebResumenScreenState();
}

class _WebResumenScreenState extends State<WebResumenScreen> {
  Alert? _active;
  Alert? _last;
  CommunityStats? _stats;
  List<RiskReport>? _reports;
  DrillOverview? _drills;

  /// Qué bloques no se pudieron traer.
  final Set<String> _failed = <String>{};
  bool _loading = true;
  DateTime? _loadedAt;
  bool _started = false;
  StreamSubscription<Alert?>? _alertSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    super.dispose();
  }

  Future<T?> _guard<T>(String block, Future<T>? Function() call) async {
    try {
      final T? result = await call();
      // Sin repositorio (o sin respuesta) el bloque no se queda cargando: dice
      // que no se pudo.
      if (result == null) _failed.add(block);
      return result;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'resumen web: $block');
      _failed.add(block);
      return null;
    }
  }

  Future<void> _load() async {
    final AppScope scope = AppScope.of(context);
    setState(() {
      _loading = true;
      _failed.clear();
    });

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _guard('comunidad', () => scope.panelRepository?.loadStats()),
      _guard('reportes', () => scope.riskRepository?.loadInbox()),
      _guard('simulacros', () => scope.drillRepository?.load()),
      _guard('alertas', () => scope.alertRepository.loadHistory()),
    ]);

    // La alerta activa llega por el canal en vivo: se escucha para que el
    // tablero cambie solo cuando se emite o se finaliza una.
    _alertSub ??= scope.alertRepository.watchActiveAlert().listen(
      (Alert? alert) {
        if (mounted) setState(() => _active = alert);
      },
      onError: (Object error, StackTrace stack) =>
          ErrorReporter.report(error, stack, context: 'alerta activa (panel web)'),
    );

    if (!mounted) return;
    final List<Alert>? history = results[3] as List<Alert>?;
    setState(() {
      _stats = results[0] as CommunityStats?;
      _reports = results[1] as List<RiskReport>?;
      _drills = results[2] as DrillOverview?;
      _last = (history == null || history.isEmpty) ? null : history.first;
      _loading = false;
      _loadedAt = DateTime.now();
    });
  }

  String get _today {
    final DateTime now = DateTime.now();
    final String day = Fmt.weekday(now);
    return '${day[0].toUpperCase()}${day.substring(1)} ${Fmt.dayMonth(now)}';
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    final DateTime? loadedAt = _loadedAt;

    return WebPageFrame(
      title: 'Resumen',
      subtitle: loadedAt == null ? _today : '$_today · actualizado ${Fmt.hour(loadedAt)}',
      actions: <Widget>[
        WebButton(
          label: 'Actualizar',
          secondary: true,
          icon: Icons.refresh,
          busy: _loading,
          onPressed: _load,
        ),
        WebButton(
          label: 'Emitir alerta',
          icon: Icons.warning_amber_outlined,
          onPressed: () => nav.go(WebPage.alerta),
        ),
      ],
      children: <Widget>[
        _StatusBanner(active: _active, last: _last, failed: _failed.contains('alertas'), onReport: () => nav.go(WebPage.informes), onMonitor: () => nav.go(WebPage.monitoreo)),
        _Kpis(stats: _stats, reports: _reports, drills: _drills, failed: _failed),
        WebSplit(
          main: _DrillsPanel(overview: _drills, failed: _failed.contains('simulacros')),
          side: _ReportsPanel(reports: _reports, failed: _failed.contains('reportes')),
        ),
        _CoveragePanel(stats: _stats, failed: _failed.contains('comunidad')),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.active,
    required this.last,
    required this.failed,
    required this.onReport,
    required this.onMonitor,
  });

  final Alert? active;
  final Alert? last;
  final bool failed;
  final VoidCallback onReport;
  final VoidCallback onMonitor;

  @override
  Widget build(BuildContext context) {
    final Alert? alert = active;
    if (alert != null) {
      return WebPanel(
        color: WebColors.brandSoft,
        borderColor: const Color(0xFFF1B9C1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: <Widget>[
            const WebIconBubble(Icons.warning_amber_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    alert.isDrill ? 'Simulacro en curso' : 'Alerta activa',
                    style: WebText.strong.copyWith(fontSize: 16, color: const Color(0xFF8A1C2D)),
                  ),
                  Text(
                    '${alert.title} · ${alert.scope} · desde ${Fmt.hour(alert.issuedAt)}',
                    style: WebText.small,
                  ),
                ],
              ),
            ),
            WebButton(label: 'Ir al monitoreo', small: true, onPressed: onMonitor),
          ],
        ),
      );
    }

    final String detail = failed
        ? 'No pudimos consultar el historial de alertas.'
        : last == null
            ? 'Aún no se ha emitido ninguna alerta.'
            : 'Última alerta: ${last!.title.toLowerCase()} del ${Fmt.dayMonth(last!.issuedAt)}${last!.isDrill ? ' (simulacro)' : ''}';

    return WebPanel(
      color: WebColors.goodSoft,
      borderColor: WebColors.goodLine,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.verified_user_outlined, size: 20, color: WebColors.good),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Sin alertas activas',
                  style: WebText.strong.copyWith(fontSize: 16, color: const Color(0xFF133F29)),
                ),
                Text(detail, style: WebText.small.copyWith(color: const Color(0xFF2E5A43))),
              ],
            ),
          ),
          if (last != null) WebButton(label: 'Ver informe', secondary: true, small: true, onPressed: onReport),
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.stats, required this.reports, required this.drills, required this.failed});

  final CommunityStats? stats;
  final List<RiskReport>? reports;
  final DrillOverview? drills;
  final Set<String> failed;

  static String _n(int? value) => value == null ? '—' : _thousands(value);

  /// `1334` → `1.334`, como se escribe en Colombia.
  static String _thousands(int value) {
    final String s = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
      out.write(s[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final List<RiskReport>? open = reports?.where((RiskReport r) => r.isOpen).toList();
    final int? fresh = reports?.where((RiskReport r) => r.status == RiskStatus.nuevo).length;
    final Drill? next = drills?.next;

    return WebGrid(
      children: <Widget>[
        WebStat(
          label: 'Personas en la comunidad',
          value: _n(stats?.total),
          note: stats == null ? (failed.contains('comunidad') ? 'No se pudo cargar' : null) : '${_thousands(stats!.activeCodes)} con código activo',
          noteColor: WebColors.goodText,
        ),
        WebStat(
          label: 'Códigos sin activar',
          value: _n(stats?.pendingCodes),
        ),
        WebStat(
          label: 'Reportes abiertos',
          value: _n(open?.length),
          valueColor: (open?.isNotEmpty ?? false) ? WebColors.brand : WebColors.ink,
          note: failed.contains('reportes')
              ? 'No se pudo cargar'
              : (fresh == null ? null : '$fresh nuevos sin revisar'),
        ),
        WebStat(
          label: 'Próximo simulacro',
          value: next == null ? (drills == null ? '—' : 'Sin fecha') : Fmt.dayMonthShort(next.scheduledAt),
          note: next == null
              ? (failed.contains('simulacros') ? 'No se pudo cargar' : null)
              : '${next.hazard.label[0]}${next.hazard.label.substring(1).toLowerCase()} · ${Fmt.hour(next.scheduledAt)}',
        ),
      ],
    );
  }
}

class _DrillsPanel extends StatelessWidget {
  const _DrillsPanel({required this.overview, required this.failed});

  final DrillOverview? overview;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    // Del más viejo al más nuevo, y como mucho los seis últimos.
    final List<DrillResult> results =
        (overview?.history ?? const <DrillResult>[]).take(6).toList().reversed.toList();

    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WebPanelHeader(
            title: 'Resultado de los simulacros',
            subtitle: overview == null
                ? null
                : 'Porcentaje del colegio que confirmó a salvo dentro de la meta de '
                    '${(overview!.goalSeconds / 60).toStringAsFixed(overview!.goalSeconds % 60 == 0 ? 0 : 1)} min',
          ),
          const SizedBox(height: 14),
          if (overview == null)
            WebLoadState(error: failed ? 'No pudimos cargar los simulacros.' : null)
          else if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Todavía no se ha hecho ningún simulacro.', style: WebText.small),
            )
          else
            _Bars(results: results),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.results});

  final List<DrillResult> results;

  @override
  Widget build(BuildContext context) {
    const double chartHeight = 150;
    return Column(
      children: <Widget>[
        Container(
          height: chartHeight + 28,
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: WebColors.field))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final DrillResult r in results)
                Expanded(
                  child: Tooltip(
                    message: '${r.hazard.label} · ${Fmt.dayMonth(r.at)}: ${r.schoolPercent} %',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text('${r.schoolPercent} %', style: WebText.strong.copyWith(fontSize: 12)),
                        const SizedBox(height: 6),
                        Container(
                          width: 44,
                          height: chartHeight * (r.schoolPercent.clamp(0, 100) / 100),
                          decoration: BoxDecoration(
                            color: r.hazard.wire == 'sismo' ? WebColors.brand : WebColors.ink,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (final DrillResult r in results)
              Expanded(
                child: Text(
                  '${Fmt.dayMonthShort(r.at)}\n${r.hazard.label[0]}${r.hazard.label.substring(1).toLowerCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: WebColors.inkMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReportsPanel extends StatelessWidget {
  const _ReportsPanel({required this.reports, required this.failed});

  final List<RiskReport>? reports;
  final bool failed;

  static IconData _icon(RiskKind kind) => switch (kind) {
        RiskKind.grieta => Icons.warning_amber_outlined,
        RiskKind.cable => Icons.bolt,
        RiskKind.agua => Icons.water_drop_outlined,
        RiskKind.humo => Icons.local_fire_department_outlined,
        RiskKind.arbol => Icons.park_outlined,
        RiskKind.otro => Icons.flag_outlined,
      };

  static String _ago(DateTime at) {
    final Duration diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final List<RiskReport>? list = reports == null
        ? null
        : (reports!.where((RiskReport r) => r.isOpen).toList()
          ..sort((RiskReport a, RiskReport b) => b.createdAt.compareTo(a.createdAt)));
    final List<RiskReport> shown = (list ?? const <RiskReport>[]).take(3).toList();

    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WebPanelHeader(
            title: 'Reportes recientes',
            trailing: TextButton(
              onPressed: () => WebNav.of(context).go(WebPage.reportes),
              child: const Text('Ver todos'),
            ),
          ),
          const SizedBox(height: 8),
          if (list == null)
            WebLoadState(error: failed ? 'No pudimos cargar los reportes.' : null)
          else if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No hay reportes abiertos.', style: WebText.small),
            )
          else
            for (int i = 0; i < shown.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: 24, color: WebColors.lineSoft),
              Row(
                children: <Widget>[
                  WebIconBubble(
                    _icon(shown[i].kind),
                    tone: shown[i].status == RiskStatus.nuevo ? WebChipTone.brand : WebChipTone.neutral,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${shown[i].kind.label} · ${shown[i].place}', style: WebText.strong),
                        Text(
                          '${shown[i].reporterRole ?? 'Comunidad'} · ${_ago(shown[i].createdAt)}',
                          style: WebText.small,
                        ),
                      ],
                    ),
                  ),
                  WebChip(
                    shown[i].status.label,
                    tone: shown[i].status == RiskStatus.nuevo ? WebChipTone.brand : WebChipTone.warn,
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({required this.stats, required this.failed});

  final CommunityStats? stats;
  final bool failed;

  static const Map<String, String> _labels = <String, String>{
    'estudiante': 'Estudiantes',
    'acudiente': 'Acudientes',
    'docente': 'Docentes',
    'administrador': 'Administradores',
  };

  @override
  Widget build(BuildContext context) {
    final CommunityStats? s = stats;
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WebPanelHeader(
            title: 'Comunidad por rol',
            trailing: TextButton(
              onPressed: () => WebNav.of(context).go(WebPage.usuarios),
              child: const Text('Gestionar'),
            ),
          ),
          const SizedBox(height: 8),
          if (s == null)
            WebLoadState(error: failed ? 'No pudimos cargar la comunidad.' : null)
          else
            for (final MapEntry<String, int> entry in s.byRole.entries) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(_labels[entry.key] ?? entry.key, style: WebText.strong),
                        Text(
                          '${_Kpis._thousands(entry.value)} · ${s.total == 0 ? 0 : (entry.value * 100 / s.total).round()} %',
                          style: WebText.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    WebMeter(fraction: s.total == 0 ? 0 : entry.value / s.total),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
