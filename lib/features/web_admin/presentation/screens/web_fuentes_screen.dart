import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert_level.dart';
import '../../../alerts/domain/hazard.dart';
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

/// Avisos de fuentes oficiales (sismos del Servicio Geológico, lluvias) que
/// sugieren una alerta. Coordinación decide si se envía.
class WebFuentesScreen extends StatefulWidget {
  const WebFuentesScreen({super.key});

  @override
  State<WebFuentesScreen> createState() => _WebFuentesScreenState();
}

class _WebFuentesScreenState extends State<WebFuentesScreen> {
  late Future<List<HazardSignal>> _signals;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() => setState(() => _signals = AppScope.of(context).panelRepository!.loadSignals());

  Future<void> _dismiss(HazardSignal s) async {
    try {
      await AppScope.of(context).panelRepository!.dismissSignal(s.id);
      if (!mounted) return;
      WebNav.of(context).refreshBadges();
      _reload();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'descartar aviso (panel web)');
      if (mounted) webToast(context, 'No se pudo descartar el aviso.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Alertas automáticas',
      subtitle: 'Fuentes oficiales sugieren alertas. Tú decides si se envían.',
      actions: <Widget>[WebButton(label: 'Actualizar', secondary: true, icon: Icons.refresh, onPressed: _reload)],
      children: <Widget>[
        WebFuture<List<HazardSignal>>(
          future: _signals,
          onRetry: _reload,
          errorText: 'No pudimos consultar las fuentes.',
          builder: (BuildContext context, List<HazardSignal> list) {
            if (list.isEmpty) {
              return const WebUnavailable(
                icon: Icons.verified_user_outlined,
                title: 'Sin avisos pendientes',
                detail: 'Cuando una fuente oficial reporte un sismo o una lluvia fuerte cerca del colegio, aparecerá aquí con una sugerencia.',
              );
            }
            return WebGrid(minWidth: 380, children: <Widget>[
              for (final HazardSignal s in list)
                WebPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[
                        WebChip('Sugerencia · ${_ago(s.occurredAt)}', tone: s.hazard == Hazard.sismo ? WebChipTone.brand : WebChipTone.warn),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s.source, style: WebText.small, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 12),
                      Text(s.headline, style: WebText.panelTitle),
                      const SizedBox(height: 4),
                      Text(
                        <String>[
                          s.detail,
                          if (s.distanceKm != null) 'A ${s.distanceKm} km del colegio',
                          if (s.magnitude != null) 'magnitud ${s.magnitude}',
                          Fmt.hour(s.occurredAt),
                        ].where((String t) => t.isNotEmpty).join(' · '),
                        style: WebText.small,
                      ),
                      if (s.hazard == Hazard.sismo) ...<Widget>[
                        const SizedBox(height: 12),
                        const WebNotice('El reporte llega después del sismo: sirve para decidir si evacuar y revisar daños, no para avisar antes.'),
                      ],
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                        WebButton(
                          label: s.hazard == Hazard.sismo ? 'Evacuar y revisar daños' : 'Emitir aviso',
                          small: true,
                          onPressed: () => nav.open(
                            WebAlertaScreen(
                              session: nav.session,
                              hazard: s.hazard,
                              level: s.hazard == Hazard.sismo ? AlertLevel.roja : AlertLevel.naranja,
                            ),
                          ),
                        ),
                        WebButton(label: 'Descartar', small: true, secondary: true, onPressed: () => _dismiss(s)),
                      ]),
                    ],
                  ),
                ),
            ]);
          },
        ),
        const WebUnavailable(
          icon: Icons.sensors_outlined,
          title: 'Sensores del colegio y reglas automáticas',
          detail: 'Conectar sensores (nivel de agua, lluvia, vibración) y crear reglas que sugieran alertas todavía no existe en el servidor. Los avisos de fuentes oficiales de arriba sí funcionan.',
        ),
      ],
    );
  }
}
