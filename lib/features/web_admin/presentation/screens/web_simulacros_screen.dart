import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../drills/domain/drill_repository.dart';
import '../../../panel/domain/community_admin.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';
import 'web_alerta_screen.dart';

String _hazardName(Hazard h) => switch (h) {
      Hazard.sismo => 'Sismo',
      Hazard.inundacion => 'Inundación',
      Hazard.lluvia => 'Lluvias fuertes',
      Hazard.incendio => 'Incendio',
    };

/// Programar simulacros y ver cómo salió cada uno.
class WebSimulacrosScreen extends StatefulWidget {
  const WebSimulacrosScreen({super.key});

  @override
  State<WebSimulacrosScreen> createState() => _WebSimulacrosScreenState();
}

class _WebSimulacrosScreenState extends State<WebSimulacrosScreen> {
  late Future<DrillOverview> _overview;
  Hazard _hazard = Hazard.sismo;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  String _scope = 'Todo el colegio';
  List<GroupInfo> _groups = const <GroupInfo>[];
  final TextEditingController _note = TextEditingController();
  bool _busy = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
    AppScope.of(context).panelRepository?.loadGroups().then((List<GroupInfo> g) {
      if (mounted) setState(() => _groups = g);
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report(e, s, context: 'grupos (simulacros web)');
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _overview = AppScope.of(context).drillRepository!.load());

  DateTime get _at => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _schedule() async {
    if (!_at.isAfter(DateTime.now())) {
      webToast(context, 'Escoge una fecha y hora que todavía no hayan pasado.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).drillRepository!.schedule(
            hazard: _hazard,
            at: _at,
            scope: _scope,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      if (!mounted) return;
      _note.clear();
      webToast(context, 'Simulacro programado');
      _reload();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'programar simulacro (panel web)');
      if (mounted) webToast(context, 'No se pudo programar el simulacro.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(Drill d) async {
    final bool ok = await webConfirm(
      context,
      title: 'Cancelar simulacro',
      message: 'Se quita ${_hazardName(d.hazard).toLowerCase()} del ${Fmt.dayMonth(d.scheduledAt)}.',
      confirm: 'Cancelar simulacro',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await AppScope.of(context).drillRepository!.cancel(d.id);
      if (mounted) _reload();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cancelar simulacro (panel web)');
      if (mounted) webToast(context, 'No se pudo cancelar.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    final Map<String, String> scopes = <String, String>{
      'Todo el colegio': 'Todo el colegio',
      for (final GroupInfo g in _groups) g.grade: g.grade,
    };
    return WebPageFrame(
      title: 'Simulacros',
      subtitle: 'Programa prácticas y mide cómo mejora el colegio',
      children: <Widget>[
        WebSplit(
          main: WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WebPanelHeader(title: 'Programar simulacro'),
                const SizedBox(height: 14),
                WebLabeled(
                  label: 'Tipo',
                  child: Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                    for (final Hazard h in Hazard.values)
                      WebOption(label: _hazardName(h), selected: h == _hazard, onTap: () => setState(() => _hazard = h)),
                  ]),
                ),
                const SizedBox(height: 16),
                WebGrid(minWidth: 200, children: <Widget>[
                  WebLabeled(
                    label: 'Fecha',
                    child: WebButton(label: '${Fmt.weekday(_date)} ${Fmt.dayMonth(_date)}', secondary: true, icon: Icons.event, onPressed: _pickDate),
                  ),
                  WebLabeled(
                    label: 'Hora',
                    child: WebButton(label: Fmt.hour(DateTime(2000, 1, 1, _time.hour, _time.minute)), secondary: true, icon: Icons.schedule, onPressed: _pickTime),
                  ),
                  WebSelect<String>(label: 'Alcance', value: _scope, items: scopes, onChanged: (String? v) => setState(() => _scope = v ?? _scope)),
                ]),
                const SizedBox(height: 16),
                WebTextArea(label: 'Nota (opcional)', controller: _note, minLines: 2),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: WebButton(label: 'Programar simulacro', busy: _busy, onPressed: _schedule),
                ),
              ],
            ),
          ),
          side: WebFuture<DrillOverview>(
            future: _overview,
            onRetry: _reload,
            builder: (BuildContext context, DrillOverview o) => WebPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const WebPanelHeader(title: 'Próximos'),
                  const SizedBox(height: 12),
                  if (o.upcoming.isEmpty) Text('No hay simulacros programados.', style: WebText.small),
                  for (final Drill d in o.upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(children: <Widget>[
                        Container(
                          width: 52,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(color: WebColors.page, borderRadius: BorderRadius.circular(10)),
                          child: Column(children: <Widget>[
                            Text(Fmt.monthTag(d.scheduledAt), style: WebText.th),
                            Text('${d.scheduledAt.day}', style: WebText.panelTitle.copyWith(fontSize: 20)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text('${_hazardName(d.hazard)} · ${d.scope}', style: WebText.strong),
                            Text(Fmt.hour(d.scheduledAt), style: WebText.small),
                          ]),
                        ),
                        Wrap(spacing: 6, children: <Widget>[
                          WebButton(
                            label: 'Iniciar',
                            small: true,
                            onPressed: () => nav.open(
                              WebAlertaScreen(
                                session: nav.session,
                                hazard: d.hazard,
                                drillId: d.id,
                              ),
                            ),
                          ),
                          WebButton(label: 'Cancelar', small: true, secondary: true, onPressed: () => _cancel(d)),
                        ]),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
        WebFuture<DrillOverview>(
          future: _overview,
          onRetry: _reload,
          builder: (BuildContext context, DrillOverview o) => WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                WebPanelHeader(
                  title: 'Resultados',
                  subtitle: 'Meta: confirmar a salvo en ${(o.goalSeconds / 60).toStringAsFixed(o.goalSeconds % 60 == 0 ? 0 : 1)} min',
                  trailing: TextButton(onPressed: () => nav.go(WebPage.informes), child: const Text('Ver informes')),
                ),
                const SizedBox(height: 8),
                WebTable(
                  headers: const <String>['Fecha', 'Tipo', 'A salvo en la meta', 'Resultado'],
                  empty: 'Todavía no se ha hecho ningún simulacro.',
                  rows: <List<Widget>>[
                    for (final DrillResult r in o.history)
                      <Widget>[
                        Text(Fmt.dayMonthShort(r.at)),
                        Text(_hazardName(r.hazard), style: WebText.strong),
                        Text('${r.schoolPercent} %'),
                        WebChip(r.schoolPercent >= 95 ? 'Meta cumplida' : 'Mejorable', tone: r.schoolPercent >= 95 ? WebChipTone.good : WebChipTone.warn),
                      ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
