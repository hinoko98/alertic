import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert_level.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/hazard_watch.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';
import 'web_alerta_screen.dart';

String _ago(DateTime at) {
  final Duration d = DateTime.now().difference(at);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

String _hazardName(Hazard h) => switch (h) {
      Hazard.sismo => 'Sismo',
      Hazard.inundacion => 'Creciente o inundación',
      Hazard.lluvia => 'Lluvia fuerte',
      Hazard.incendio => 'Incendio',
    };

(String, WebChipTone) _levelChip(AlertLevel? level) => switch (level) {
      AlertLevel.roja => ('Sugiere evacuar', WebChipTone.brand),
      AlertLevel.naranja => ('Sugiere precaución', WebChipTone.warn),
      AlertLevel.amarilla => ('Sugiere informar', WebChipTone.neutral),
      null => ('Sin sugerencia', WebChipTone.neutral),
    };

/// Avisos de amenazas que **una persona** decide.
///
/// Las fuentes automáticas (sismos del USGS, lluvia y creciente súbita de
/// Open-Meteo) solo sugieren. Lo que ninguna fuente detecta —un incendio— lo
/// escribe alguien de coordinación o un docente, y necesita que **otra** persona
/// lo apruebe antes de convertirse en alerta: así un error de un solo teclado no
/// evacúa el colegio.
class WebFuentesScreen extends StatefulWidget {
  const WebFuentesScreen({super.key});

  @override
  State<WebFuentesScreen> createState() => _WebFuentesScreenState();
}

class _WebFuentesScreenState extends State<WebFuentesScreen> {
  SignalStatus _status = SignalStatus.pending;
  late Future<List<HazardSignal>> _signals;
  late Future<HazardWatchOverview> _watch;
  bool _started = false;

  PanelRepository get _repo => AppScope.of(context).panelRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() {
    setState(() {
      _signals = _repo.loadSignals(status: _status);
      _watch = _repo.loadHazardWatch();
    });
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      webToast(context, done);
      WebNav.of(context).refreshBadges();
      _reload();
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'aviso de amenaza (panel web)');
      if (mounted) webToast(context, 'No se pudo completar la acción.', error: true);
    }
  }

  Future<void> _report() async {
    final bool? sent = await showDialog<bool>(context: context, builder: (_) => const _ManualReportDialog());
    if (sent == true && mounted) {
      webToast(context, 'Aviso enviado. Otra persona tiene que aprobarlo antes de emitir la alerta.');
      WebNav.of(context).refreshBadges();
      setState(() => _status = SignalStatus.pending);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Alertas automáticas',
      subtitle: 'Las fuentes sugieren y una persona decide. Ningún aviso se envía solo.',
      actions: <Widget>[
        WebButton(label: 'Actualizar', secondary: true, icon: Icons.refresh, onPressed: _reload),
        WebButton(label: 'Reportar incendio u otra emergencia', icon: Icons.local_fire_department_outlined, onPressed: _report),
      ],
      children: <Widget>[
        const WebNotice(
          'Los sismos, la lluvia fuerte y el riesgo de creciente súbita (avalancha) llegan solos de fuentes oficiales y abiertas. '
          'Un incendio lo reporta una persona y necesita la aprobación de otra —coordinación o un docente— antes de convertirse en alerta.',
          icon: Icons.verified_user_outlined,
        ),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final (SignalStatus, String) t in <(SignalStatus, String)>[
            (SignalStatus.pending, 'Por revisar'),
            (SignalStatus.attended, 'Convertidos en alerta'),
            (SignalStatus.dismissed, 'Descartados'),
          ])
            WebOption(
              label: t.$2,
              selected: _status == t.$1,
              onTap: () {
                _status = t.$1;
                _reload();
              },
            ),
        ]),
        WebFuture<List<HazardSignal>>(
          future: _signals,
          onRetry: _reload,
          errorText: 'No pudimos consultar los avisos.',
          builder: (BuildContext context, List<HazardSignal> list) {
            if (list.isEmpty) {
              return WebUnavailable(
                icon: Icons.verified_user_outlined,
                title: _status == SignalStatus.pending ? 'Sin avisos por revisar' : 'Nada por aquí',
                detail: _status == SignalStatus.pending
                    ? 'Cuando una fuente detecte un sismo, lluvia fuerte o riesgo de creciente cerca del colegio, o alguien reporte un incendio, aparecerá aquí.'
                    : 'Todavía no hay avisos en esta lista.',
              );
            }
            return WebGrid(minWidth: 380, children: <Widget>[
              for (final HazardSignal s in list)
                _SignalCard(
                  signal: s,
                  onApprove: () => _run(() async => _repo.approveSignal(s.id), 'Aviso aprobado: ya se puede emitir la alerta'),
                  onDismiss: () => _run(() => _repo.dismissSignal(s.id), 'Aviso descartado'),
                  onEmit: () => nav.open(
                    WebAlertaScreen(
                      session: nav.session,
                      signalId: s.id,
                      hazard: s.hazard,
                      level: s.suggestedLevel ?? (s.hazard == Hazard.sismo ? AlertLevel.roja : AlertLevel.naranja),
                    ),
                  ),
                ),
            ]);
          },
        ),
        WebFuture<HazardWatchOverview>(
          future: _watch,
          onRetry: _reload,
          errorText: 'No pudimos consultar el estado de las fuentes.',
          builder: (BuildContext context, HazardWatchOverview w) => WebSplit(
            main: _SourcesPanel(watch: w),
            side: _SettingsPanel(settings: w.settings, onSaved: _reload),
          ),
        ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.signal,
    required this.onApprove,
    required this.onDismiss,
    required this.onEmit,
  });

  final HazardSignal signal;
  final VoidCallback onApprove;
  final VoidCallback onDismiss;
  final VoidCallback onEmit;

  @override
  Widget build(BuildContext context) {
    final HazardSignal s = signal;
    final (String levelText, WebChipTone levelTone) = _levelChip(s.suggestedLevel);
    final bool pending = s.status == SignalStatus.pending;

    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
            WebChip(_hazardName(s.hazard), tone: WebChipTone.dark),
            WebChip(levelText, tone: levelTone),
            Text('${s.source} · ${_ago(s.occurredAt)}', style: WebText.small),
          ]),
          const SizedBox(height: 12),
          Text(s.headline, style: WebText.panelTitle),
          const SizedBox(height: 4),
          Text(
            <String>[
              s.detail,
              if (s.magnitude != null) 'magnitud ${s.magnitude!.toStringAsFixed(1)}',
              Fmt.hour(s.occurredAt),
            ].where((String t) => t.isNotEmpty).join(' · '),
            style: WebText.small,
          ),
          if (s.hazard == Hazard.sismo && !s.isManual) ...<Widget>[
            const SizedBox(height: 12),
            const WebNotice('El reporte llega después del sismo: sirve para decidir si evacuar y revisar daños, no para avisar antes.'),
          ],
          if (s.isManual) ...<Widget>[
            const SizedBox(height: 12),
            if (s.awaitingApproval)
              WebNotice(
                'Lo reportó ${s.reportedBy ?? 'una persona'}. Necesita la aprobación de otra persona (coordinación o un docente) antes de enviarse como alerta.',
                icon: Icons.how_to_reg_outlined,
                tone: WebChipTone.warn,
              )
            else
              WebNotice(
                'Lo reportó ${s.reportedBy ?? 'una persona'} y lo aprobó ${s.approvedBy ?? 'otra persona'}'
                '${s.approvedAt == null ? '' : ' a las ${Fmt.hour(s.approvedAt!)}'}.',
                icon: Icons.verified_outlined,
                tone: WebChipTone.good,
              ),
          ],
          if (s.status == SignalStatus.attended)
            const Padding(padding: EdgeInsets.only(top: 12), child: WebChip('Se convirtió en alerta', tone: WebChipTone.good)),
          if (pending) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              if (s.awaitingApproval)
                WebButton(label: 'Aprobar: lo confirmo', small: true, dark: true, icon: Icons.how_to_reg_outlined, onPressed: onApprove),
              WebButton(
                label: s.hazard == Hazard.sismo ? 'Evacuar y revisar daños' : 'Emitir alerta',
                small: true,
                onPressed: s.canEmit ? onEmit : null,
              ),
              WebButton(label: 'Descartar', small: true, secondary: true, onPressed: onDismiss),
            ]),
          ],
        ],
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({required this.watch});

  final HazardWatchOverview watch;

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WebPanelHeader(
            title: 'Fuentes que se vigilan',
            subtitle: watch.place.isEmpty ? null : 'Alrededor de ${watch.place}',
            trailing: WebChip(
              watch.watching ? '● Vigilando' : 'Vigilancia apagada en el servidor',
              tone: watch.watching ? WebChipTone.good : WebChipTone.warn,
            ),
          ),
          const SizedBox(height: 10),
          WebTable(
            headers: const <String>['Fuente', 'Estado', 'Última consulta', 'Resultado'],
            rows: <List<Widget>>[
              for (final HazardSourceStatus src in watch.sources)
                <Widget>[
                  Text(src.label, style: WebText.strong),
                  !src.enabled
                      ? const WebChip('Apagada')
                      : src.failing
                          ? const WebChip('No responde', tone: WebChipTone.brand)
                          : (src.lastRunAt == null ? const WebChip('Sin consultar', tone: WebChipTone.warn) : const WebChip('Funcionando', tone: WebChipTone.good)),
                  Text(src.lastRunAt == null ? '—' : '${Fmt.dayMonthShort(src.lastRunAt!)} · ${Fmt.hour(src.lastRunAt!)}'),
                  Text(src.failing ? src.lastError! : '${src.lastCount} avisos', style: WebText.small),
                ],
            ],
          ),
          const SizedBox(height: 10),
          const WebNotice(
            'Sismos: USGS (todo Colombia). Lluvia y creciente: Open-Meteo, con el caudal modelado del río (GloFAS). '
            'Son modelos y redes globales, no sensores en el colegio: por eso sugieren y una persona confirma.',
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({required this.settings, required this.onSaved});

  final HazardSettings settings;
  final VoidCallback onSaved;

  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late HazardSettings _s = widget.settings;
  late final TextEditingController _magnitude = TextEditingController(text: _fmt(_s.quakeMinMagnitude));
  late final TextEditingController _radius = TextEditingController(text: '${_s.quakeRadiusKm}');
  late final TextEditingController _rain = TextEditingController(text: _fmt(_s.rainMmNext6h));
  late final TextEditingController _floodRain = TextEditingController(text: _fmt(_s.floodRainMm));
  late final TextEditingController _ratio = TextEditingController(text: _fmt(_s.floodDischargeRatio));
  late final TextEditingController _poll = TextEditingController(text: '${_s.pollMinutes}');
  bool _busy = false;
  String? _error;

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_magnitude, _radius, _rain, _floodRain, _ratio, _poll]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final double? magnitude = _num(_magnitude);
    final double? radius = _num(_radius);
    final double? rain = _num(_rain);
    final double? floodRain = _num(_floodRain);
    final double? ratio = _num(_ratio);
    final double? poll = _num(_poll);
    if (<double?>[magnitude, radius, rain, floodRain, ratio, poll].contains(null)) {
      setState(() => _error = 'Revisa que todos los valores sean números.');
      return;
    }
    final HazardSettings next = _s.copyWith(
      quakeMinMagnitude: magnitude,
      quakeRadiusKm: radius!.round(),
      rainMmNext6h: rain,
      floodRainMm: floodRain,
      floodDischargeRatio: ratio,
      pollMinutes: poll!.round(),
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final HazardSettings saved = await AppScope.of(context).panelRepository!.saveHazardSettings(next);
      if (!mounted) return;
      setState(() => _s = saved);
      webToast(context, 'Ajustes guardados: valen desde la próxima consulta');
      widget.onSaved();
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'ajustes de vigilancia (panel web)');
      if (mounted) setState(() => _error = 'No se pudieron guardar los ajustes.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WebPanelHeader(title: 'Ajustes de las fuentes', subtitle: 'Solo coordinación puede cambiarlos'),
          const SizedBox(height: 14),
          WebToggleRow(title: 'Sismos', value: _s.quakesEnabled, onChanged: (bool v) => setState(() => _s = _s.copyWith(quakesEnabled: v))),
          const SizedBox(height: 8),
          WebGrid(minWidth: 140, gap: 12, children: <Widget>[
            WebField(label: 'Magnitud mínima', controller: _magnitude, keyboardType: TextInputType.number),
            WebField(label: 'Distancia máxima (km)', controller: _radius, keyboardType: TextInputType.number),
          ]),
          const SizedBox(height: 16),
          WebToggleRow(
            title: 'Lluvia fuerte',
            subtitle: 'Milímetros esperados en las próximas 6 horas',
            value: _s.rainEnabled,
            onChanged: (bool v) => setState(() => _s = _s.copyWith(rainEnabled: v)),
          ),
          const SizedBox(height: 8),
          WebField(label: 'Avisar desde (mm)', controller: _rain, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          WebToggleRow(
            title: 'Creciente súbita o avalancha',
            subtitle: 'Lluvia de 24 h + 6 h y caudal del río frente al normal',
            value: _s.floodEnabled,
            onChanged: (bool v) => setState(() => _s = _s.copyWith(floodEnabled: v)),
          ),
          const SizedBox(height: 8),
          WebGrid(minWidth: 140, gap: 12, children: <Widget>[
            WebField(label: 'Lluvia acumulada (mm)', controller: _floodRain, keyboardType: TextInputType.number),
            WebField(label: 'Veces el caudal normal', controller: _ratio, keyboardType: TextInputType.number),
          ]),
          const SizedBox(height: 16),
          WebField(label: 'Consultar cada (minutos)', controller: _poll, keyboardType: TextInputType.number),
          if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: WebButton(label: 'Guardar ajustes', busy: _busy, onPressed: _save)),
        ],
      ),
    );
  }
}

/// Reportar lo que ninguna fuente detecta. Queda pendiente de otra aprobación.
class _ManualReportDialog extends StatefulWidget {
  const _ManualReportDialog();

  @override
  State<_ManualReportDialog> createState() => _ManualReportDialogState();
}

class _ManualReportDialogState extends State<_ManualReportDialog> {
  Hazard _hazard = Hazard.incendio;
  AlertLevel _level = AlertLevel.roja;
  final TextEditingController _detail = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_detail.text.trim().length < 3) {
      setState(() => _error = 'Cuenta qué pasa y dónde.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).panelRepository!.reportHazard(
            ManualHazardReport(hazard: _hazard, detail: _detail.text, suggestedLevel: _level),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reportar amenaza (panel web)');
      if (mounted) setState(() => _error = 'No se pudo enviar el aviso.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar una emergencia'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('Qué pasa', style: WebText.label),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              for (final Hazard h in Hazard.values)
                WebOption(label: _hazardName(h), selected: _hazard == h, onTap: () => setState(() => _hazard = h)),
            ]),
            const SizedBox(height: 14),
            WebTextArea(label: 'Qué se ve y dónde', controller: _detail, minLines: 2, hint: 'Humo saliendo del laboratorio 2, bloque B'),
            const SizedBox(height: 14),
            Text('Qué sugieres', style: WebText.label),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              for (final (AlertLevel, String) l in <(AlertLevel, String)>[
                (AlertLevel.roja, 'Evacuar'),
                (AlertLevel.naranja, 'Precaución'),
                (AlertLevel.amarilla, 'Informar'),
              ])
                WebOption(label: l.$2, selected: _level == l.$1, onTap: () => setState(() => _level = l.$1)),
            ]),
            const SizedBox(height: 14),
            const WebNotice(
              'Para evitar alertas falsas, otra persona (coordinación o un docente) tiene que aprobar este aviso antes de emitir la alerta. '
              'Si el fuego es evidente y hay peligro inmediato, activa también la alarma del colegio.',
              icon: Icons.how_to_reg_outlined,
              tone: WebChipTone.warn,
            ),
            if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
          ]),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        TextButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'ENVIANDO…' : 'ENVIAR PARA APROBACIÓN')),
      ],
    );
  }
}
