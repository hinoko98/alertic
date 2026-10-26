import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/protocol.dart';
import '../../../panel/domain/community_admin.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

String _hazardName(Hazard h) => switch (h) {
      Hazard.sismo => 'Sismo',
      Hazard.inundacion => 'Inundación',
      Hazard.lluvia => 'Lluvias fuertes',
      Hazard.incendio => 'Incendio',
    };

enum _Phase { before, during, after }

/// Los protocolos que la app le muestra a la comunidad antes, durante y después
/// de cada emergencia. Se guardan en cada celular para leerlos sin señal.
class WebContenidosScreen extends StatefulWidget {
  const WebContenidosScreen({super.key});

  @override
  State<WebContenidosScreen> createState() => _WebContenidosScreenState();
}

class _WebContenidosScreenState extends State<WebContenidosScreen> {
  late Future<List<Protocol>> _protocols;
  Hazard _hazard = Hazard.sismo;
  _Phase _phase = _Phase.during;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() => setState(() => _protocols = AppScope.of(context).panelRepository!.loadProtocols());

  @override
  Widget build(BuildContext context) {
    return WebPageFrame(
      title: 'Guías y asistente',
      subtitle: 'Lo que la app le dice a la comunidad antes, durante y después de una emergencia',
      children: <Widget>[
        WebFuture<List<Protocol>>(
          future: _protocols,
          onRetry: _reload,
          builder: (BuildContext context, List<Protocol> all) {
            Protocol? current;
            for (final Protocol p in all) {
              if (p.hazard == _hazard) current = p;
            }
            final Protocol protocol = current ?? Protocol(hazard: _hazard, beforeSteps: const <String>[], duringSteps: const <String>[], afterSteps: const <String>[]);
            return WebSplit(
              main: WebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    WebPanelHeader(
                      title: 'Editando · ${_hazardName(_hazard)}',
                      trailing: Wrap(spacing: 8, children: <Widget>[
                        for (final (_Phase, String) p in <(_Phase, String)>[(_Phase.before, 'Antes'), (_Phase.during, 'Durante'), (_Phase.after, 'Después')])
                          WebOption(label: p.$2, selected: _phase == p.$1, onTap: () => setState(() => _phase = p.$1)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    _StepsEditor(
                      key: ValueKey<String>('${_hazard.wire}-${_phase.name}-${all.length}-${protocol.duringSteps.length}'),
                      protocol: protocol,
                      phase: _phase,
                      onSaved: _reload,
                    ),
                  ],
                ),
              ),
              side: WebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const WebPanelHeader(title: 'Guías publicadas'),
                    const SizedBox(height: 10),
                    for (final Hazard h in Hazard.values)
                      InkWell(
                        onTap: () => setState(() => _hazard = h),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: <Widget>[
                            Expanded(child: Text(_hazardName(h), style: WebText.strong.copyWith(color: h == _hazard ? WebColors.brandDark : WebColors.ink))),
                            Builder(builder: (BuildContext context) {
                              final bool published = all.any((Protocol p) => p.hazard == h && p.duringSteps.isNotEmpty);
                              return WebChip(published ? 'Publicada' : 'Sin publicar', tone: published ? WebChipTone.good : WebChipTone.warn);
                            }),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const WebUnavailable(
          icon: Icons.forum_outlined,
          title: 'Guías nuevas y respuestas del asistente',
          detail: 'Crear guías de otros temas (vendaval, primeros auxilios) y editar las respuestas del asistente de riesgos todavía no existe en el servidor. Hoy se editan los protocolos de las cuatro amenazas.',
        ),
      ],
    );
  }
}

class _StepsEditor extends StatefulWidget {
  const _StepsEditor({required this.protocol, required this.phase, required this.onSaved, super.key});

  final Protocol protocol;
  final _Phase phase;
  final VoidCallback onSaved;

  @override
  State<_StepsEditor> createState() => _StepsEditorState();
}

class _StepsEditorState extends State<_StepsEditor> {
  late final List<TextEditingController> _steps;
  bool _busy = false;
  String? _error;

  static List<String> _of(Protocol p, _Phase phase) => switch (phase) {
        _Phase.before => p.beforeSteps,
        _Phase.during => p.duringSteps,
        _Phase.after => p.afterSteps,
      };

  @override
  void initState() {
    super.initState();
    _steps = <TextEditingController>[for (final String s in _of(widget.protocol, widget.phase)) TextEditingController(text: s)];
  }

  @override
  void dispose() {
    for (final TextEditingController c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final List<String> steps = _steps.map((TextEditingController c) => c.text.trim()).where((String t) => t.isNotEmpty).toList();
    if (widget.phase == _Phase.during && steps.isEmpty) {
      setState(() => _error = 'El «durante» necesita al menos un paso: es lo que sale en la alerta.');
      return;
    }
    if (steps.any((String s) => s.length < 3 || s.length > 160)) {
      setState(() => _error = 'Cada paso debe tener entre 3 y 160 caracteres.');
      return;
    }
    final Protocol p = widget.protocol;
    final Protocol next = Protocol(
      hazard: p.hazard,
      beforeSteps: widget.phase == _Phase.before ? steps : p.beforeSteps,
      duringSteps: widget.phase == _Phase.during ? steps : p.duringSteps,
      afterSteps: widget.phase == _Phase.after ? steps : p.afterSteps,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).panelRepository!.saveProtocol(next);
      if (!mounted) return;
      webToast(context, 'Guía publicada: llega a los celulares');
      widget.onSaved();
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'guardar protocolo (panel web)');
      if (mounted) setState(() => _error = 'No se pudo guardar la guía.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
              Expanded(child: WebField(label: 'Paso ${i + 1}', controller: _steps[i])),
              IconButton(
                tooltip: 'Quitar paso',
                onPressed: () => setState(() => _steps.removeAt(i).dispose()),
                icon: const Icon(Icons.close, size: 18, color: WebColors.inkMuted),
              ),
            ]),
          ),
        if (_steps.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Esta sección no tiene pasos.', style: WebText.small)),
        Align(
          alignment: Alignment.centerLeft,
          child: WebButton(
            label: 'Agregar paso',
            secondary: true,
            icon: Icons.add,
            onPressed: _steps.length >= 8 ? null : () => setState(() => _steps.add(TextEditingController())),
          ),
        ),
        if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
        const SizedBox(height: 16),
        const WebNotice('Al publicar, el cambio llega a todos los celulares y es lo que dice la alerta roja.'),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerRight, child: WebButton(label: 'Publicar cambios', busy: _busy, onPressed: _save)),
      ],
    );
  }
}
