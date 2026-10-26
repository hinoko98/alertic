import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/live_updates.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

/// El tablero de una alerta en curso, tal como la ve coordinación: quién está a
/// salvo, quién no ha respondido y quién pide ayuda.
///
/// Se actualiza solo: escucha el canal en vivo y, por si ese canal se cae, vuelve
/// a preguntar cada 15 segundos.
class WebMonitoreoScreen extends StatefulWidget {
  const WebMonitoreoScreen({super.key});

  @override
  State<WebMonitoreoScreen> createState() => _WebMonitoreoScreenState();
}

class _WebMonitoreoScreenState extends State<WebMonitoreoScreen> {
  Alert? _alert;
  EmergencyBoard? _board;
  List<MeetingPoint> _points = const <MeetingPoint>[];
  bool _loading = true;
  bool _boardFailed = false;
  DateTime _now = DateTime.now();

  StreamSubscription<Alert?>? _alertSub;
  StreamSubscription<LiveChange>? _liveSub;
  Timer? _tick;
  Timer? _poll;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final AppScope scope = AppScope.of(context);

    _alertSub = scope.alertRepository.watchActiveAlert().listen(
      (Alert? alert) {
        if (!mounted) return;
        final bool changed = alert?.id != _alert?.id;
        setState(() {
          _alert = alert;
          _loading = false;
          if (changed) _board = null;
        });
        if (changed) _refresh();
      },
      onError: (Object error, StackTrace stack) {
        ErrorReporter.report(error, stack, context: 'alerta activa (monitoreo web)');
        if (mounted) setState(() => _loading = false);
      },
    );
    _liveSub = scope.liveUpdates.changes
        .where((LiveChange c) => c == LiveChange.reports)
        .listen((_) => _refresh());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _alert != null) setState(() => _now = DateTime.now());
    });
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());

    scope.alertRepository.loadMeetingPoints().then((List<MeetingPoint> p) {
      if (mounted) setState(() => _points = p);
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report(e, s, context: 'puntos (monitoreo web)');
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    _liveSub?.cancel();
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final Alert? alert = _alert;
    if (alert == null) return;
    try {
      final EmergencyBoard? board = await AppScope.of(context).panelRepository?.loadBoard(alert.id);
      if (mounted) {
        setState(() {
          _board = board;
          _boardFailed = board == null;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'tablero (monitoreo web)');
      if (mounted) setState(() => _boardFailed = true);
    }
  }

  static String _clock(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _pointName(String code) {
    for (final MeetingPoint p in _points) {
      if (p.code == code) return '${p.code} · ${p.name}';
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final Alert? alert = _alert;
    if (_loading) {
      return const WebPageFrame(title: 'Monitoreo en vivo', children: <Widget>[WebLoadState()]);
    }
    if (alert == null) {
      return WebPageFrame(
        title: 'Monitoreo en vivo',
        subtitle: 'No hay ninguna alerta activa',
        actions: <Widget>[
          WebButton(label: 'Emitir alerta', icon: Icons.warning_amber_outlined, onPressed: () => WebNav.of(context).go(WebPage.alerta)),
        ],
        children: const <Widget>[
          WebUnavailable(
            icon: Icons.verified_user_outlined,
            title: 'Todo en calma',
            detail: 'Cuando se emita una alerta o un simulacro, aquí verás quién está a salvo, quién no responde y quién pide ayuda, en vivo.',
          ),
        ],
      );
    }

    final EmergencyBoard? b = _board;
    final Duration elapsed = _now.difference(alert.issuedAt);
    return WebPageFrame(
      title: '${alert.isDrill ? 'Simulacro' : 'Alerta activa'} · ${alert.title} · ${alert.level.meaning}',
      subtitle: 'Emitida a las ${Fmt.hour(alert.issuedAt)}${alert.issuedBy == null ? '' : ' por ${alert.issuedBy}'} · ${alert.scope}',
      actions: <Widget>[
        WebButton(
          label: 'Finalizar alerta',
          dark: true,
          onPressed: () => WebNav.of(context).open(WebFinalizarScreen(alert: alert, board: b)),
        ),
      ],
      children: <Widget>[
        if (b == null)
          WebLoadState(error: _boardFailed ? 'No pudimos cargar el tablero.' : null, onRetry: _refresh)
        else ...<Widget>[
          WebGrid(children: <Widget>[
            WebStat(
              label: 'A salvo',
              value: _n(b.safe),
              valueColor: WebColors.good,
              note: '${b.safePercent} % de ${_n(b.total)}',
            ),
            WebStat(label: 'Sin confirmar', value: _n(b.noResponse)),
            WebStat(
              label: 'Piden ayuda',
              value: _n(b.needHelp),
              valueColor: b.needHelp > 0 ? WebColors.brand : WebColors.ink,
            ),
            WebStat(label: 'Tiempo transcurrido', value: _clock(elapsed), note: 'Meta: 95 % antes de 05:00'),
          ]),
          WebMeter(fraction: b.total == 0 ? 0 : b.safe / b.total, color: WebColors.good, height: 14),
          WebSplit(
            main: _ByPoint(board: b, name: _pointName),
            side: _HelpRequests(requests: b.needHelpList),
          ),
          _ByGrade(rows: b.byGrade),
        ],
      ],
    );
  }

  static String _n(int v) {
    final String s = v.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
      out.write(s[i]);
    }
    return out.toString();
  }
}

class _ByPoint extends StatelessWidget {
  const _ByPoint({required this.board, required this.name});

  final EmergencyBoard board;
  final String Function(String code) name;

  @override
  Widget build(BuildContext context) {
    final int max = board.byMeetingPoint.fold<int>(1, (int m, MeetingPointCount c) => c.count > m ? c.count : m);
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WebPanelHeader(title: 'Personas por punto de encuentro', subtitle: 'Quienes ya confirmaron que llegaron'),
          const SizedBox(height: 14),
          if (board.byMeetingPoint.isEmpty)
            Text('Todavía nadie ha llegado a un punto.', style: WebText.small)
          else
            for (final MeetingPointCount c in board.byMeetingPoint)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Flexible(child: Text(name(c.code), style: WebText.strong)),
                        Text('${c.count}', style: WebText.small),
                      ],
                    ),
                    const SizedBox(height: 6),
                    WebMeter(fraction: c.count / max, color: WebColors.good),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _HelpRequests extends StatelessWidget {
  const _HelpRequests({required this.requests});

  final List<HelpRequest> requests;

  static String _ago(DateTime at) {
    final Duration d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return 'ahora';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    return 'hace ${d.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WebPanelHeader(
            title: 'Pedidos de ayuda',
            trailing: WebChip('${requests.length} activos', tone: requests.isEmpty ? WebChipTone.neutral : WebChipTone.brand),
          ),
          const SizedBox(height: 10),
          if (requests.isEmpty)
            Text('Nadie ha pedido ayuda.', style: WebText.small)
          else
            for (int i = 0; i < requests.length; i++) ...<Widget>[
              if (i > 0) const Divider(height: 24, color: WebColors.lineSoft),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const WebIconBubble(Icons.warning_amber_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(requests[i].helpKindLabel ?? 'Pide ayuda', style: WebText.strong),
                        Text(
                          '${requests[i].fullName} · ${requests[i].grade} · ${requests[i].location} · ${_ago(requests[i].reportedAt)}',
                          style: WebText.small,
                        ),
                        if (requests[i].helpDetails != null && requests[i].helpDetails!.isNotEmpty)
                          Text('“${requests[i].helpDetails}”', style: WebText.small.copyWith(fontStyle: FontStyle.italic)),
                        if (requests[i].medicalInfo != null && requests[i].medicalInfo!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: WebChip('Ficha: ${requests[i].medicalInfo}', tone: WebChipTone.warn),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

class _ByGrade extends StatelessWidget {
  const _ByGrade({required this.rows});

  final List<GradeProgress> rows;

  @override
  Widget build(BuildContext context) {
    final List<GradeProgress> pending =
        rows.where((GradeProgress g) => g.noResponse > 0 || g.needHelp > 0).toList()
          ..sort((GradeProgress a, GradeProgress b) => b.noResponse.compareTo(a.noResponse));
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WebPanelHeader(title: 'Sin confirmar por curso'),
          const SizedBox(height: 8),
          WebTable(
            headers: const <String>['Curso', 'Sin confirmar', 'Piden ayuda', 'Avance'],
            empty: 'Todos los cursos confirmaron.',
            rows: <List<Widget>>[
              for (final GradeProgress g in pending)
                <Widget>[
                  Text(g.grade, style: WebText.strong),
                  Text('${g.noResponse}'),
                  Text('${g.needHelp}'),
                  SizedBox(width: 160, child: WebMeter(fraction: g.progress, color: WebColors.good)),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Cerrar la alerta: se revisa cómo quedó el colegio antes de darla por terminada.
class WebFinalizarScreen extends StatefulWidget {
  const WebFinalizarScreen({required this.alert, this.board, super.key});

  final Alert alert;
  final EmergencyBoard? board;

  @override
  State<WebFinalizarScreen> createState() => _WebFinalizarScreenState();
}

class _WebFinalizarScreenState extends State<WebFinalizarScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _finish() async {
    final EmergencyBoard? b = widget.board;
    final bool pending = b != null && (b.noResponse > 0 || b.needHelp > 0);
    final bool ok = await webConfirm(
      context,
      title: '¿Finalizar la alerta?',
      message: pending
          ? 'Todavía hay ${b.noResponse} personas sin confirmar y ${b.needHelp} pidiendo ayuda. '
              'Al finalizar, todos los celulares dejan de mostrar la alerta.'
          : 'Todos los celulares dejarán de mostrar la alerta.',
      confirm: 'Finalizar',
      danger: true,
    );
    if (!ok || !mounted) return;

    final AppScope scope = AppScope.of(context);
    final WebNav nav = WebNav.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.teacherRepository!.endAlert(widget.alert.id);
      nav.refreshBadges();
      nav.go(WebPage.informes);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'finalizar alerta (panel web)');
      if (mounted) setState(() => _error = 'No se pudo finalizar la alerta. Inténtalo otra vez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Alert a = widget.alert;
    final EmergencyBoard? b = widget.board;
    final Duration active = DateTime.now().difference(a.issuedAt);

    Widget check(bool ok, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(ok ? Icons.check_circle : Icons.error_outline, size: 18, color: ok ? WebColors.good : WebColors.warn),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: WebText.body)),
            ],
          ),
        );

    return WebPageFrame(
      title: 'Finalizar alerta',
      subtitle: '${a.title} · activa desde las ${Fmt.hour(a.issuedAt)} · ${active.inMinutes} min',
      actions: const <Widget>[WebBackButton(label: 'Volver al monitoreo')],
      children: <Widget>[
        WebSplit(
          main: WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const WebNotice(
                  'Al finalizar, la app de todos muestra que la alerta terminó y les pide contar cómo les fue en la evacuación.',
                ),
                const SizedBox(height: 16),
                if (_error != null) ...<Widget>[WebErrorNote(_error!), const SizedBox(height: 12)],
                Align(
                  alignment: Alignment.centerLeft,
                  child: WebButton(label: 'Finalizar alerta', dark: true, busy: _busy, onPressed: _finish),
                ),
              ],
            ),
          ),
          side: WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WebPanelHeader(title: 'Antes de finalizar'),
                const SizedBox(height: 12),
                if (b == null)
                  Text('No pudimos consultar el tablero.', style: WebText.small)
                else ...<Widget>[
                  check(b.safePercent >= 95, '${b.safe} de ${b.total} a salvo (${b.safePercent} %)'),
                  check(b.noResponse == 0, b.noResponse == 0 ? 'Nadie sin confirmar' : '${b.noResponse} personas sin confirmar'),
                  check(b.needHelp == 0, b.needHelp == 0 ? 'Nadie pide ayuda' : '${b.needHelp} personas piden ayuda'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
