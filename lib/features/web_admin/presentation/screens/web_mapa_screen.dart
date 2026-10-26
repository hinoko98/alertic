import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';

String _hazardName(Hazard h) => switch (h) {
      Hazard.sismo => 'Sismos',
      Hazard.inundacion => 'Inundaciones',
      Hazard.lluvia => 'Lluvias',
      Hazard.incendio => 'Incendios',
    };

/// Puntos de encuentro y rutas: lo que la app muestra y a lo que guía a cada
/// persona. Los cambios llegan a los celulares al guardar.
class WebMapaScreen extends StatefulWidget {
  const WebMapaScreen({super.key});

  @override
  State<WebMapaScreen> createState() => _WebMapaScreenState();
}

class _WebMapaScreenState extends State<WebMapaScreen> {
  late Future<List<MeetingPoint>> _points;

  /// `null` crea uno nuevo; si no, el código del que se edita.
  String? _selected;
  bool _creating = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() => setState(() => _points = AppScope.of(context).panelRepository!.loadMeetingPoints());

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Mapa y rutas',
      subtitle: 'Edita los puntos de encuentro. Los cambios llegan a la app al guardar.',
      actions: <Widget>[
        WebButton(label: 'Ubicación en el GPS', secondary: true, icon: Icons.my_location, onPressed: () => nav.open(const WebGeorrefScreen())),
        WebButton(
          label: 'Nuevo punto',
          icon: Icons.add,
          onPressed: () => setState(() {
            _creating = true;
            _selected = null;
          }),
        ),
      ],
      children: <Widget>[
        WebFuture<List<MeetingPoint>>(
          future: _points,
          onRetry: _reload,
          builder: (BuildContext context, List<MeetingPoint> points) {
            MeetingPoint? current;
            for (final MeetingPoint p in points) {
              if (p.code == _selected) current = p;
            }
            final Widget editor = (_creating || current != null)
                ? _PointEditor(
                    key: ValueKey<String?>(current?.code ?? 'nuevo'),
                    point: current,
                    onDone: () {
                      setState(() {
                        _creating = false;
                        _selected = null;
                      });
                      _reload();
                    },
                  )
                : const WebUnavailable(
                    icon: Icons.touch_app_outlined,
                    title: 'Escoge un punto',
                    detail: 'Selecciónalo en la lista para editar su nombre, cómo llegar y su ubicación, o crea uno nuevo.',
                  );
            return WebSplit(
              main: WebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    WebPanelHeader(title: 'Puntos de encuentro', trailing: WebChip('${points.length}')),
                    const SizedBox(height: 10),
                    if (points.isEmpty) Text('Todavía no hay puntos de encuentro.', style: WebText.small),
                    for (final MeetingPoint p in points)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() {
                          _selected = p.code;
                          _creating = false;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.code == _selected ? WebColors.brandSoftest : Colors.white,
                            border: Border.all(color: p.code == _selected ? WebColors.brand : WebColors.line, width: p.code == _selected ? 2 : 1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: <Widget>[
                            WebChip(p.code, tone: WebChipTone.dark),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                                Text(p.name, style: WebText.strong),
                                Text(p.routeHint, style: WebText.small),
                              ]),
                            ),
                            if (p.onlyFor != null) WebChip('Solo ${_hazardName(p.onlyFor!).toLowerCase()}', tone: WebChipTone.warn),
                            const SizedBox(width: 8),
                            WebChip(p.location == null ? 'Sin ubicar' : 'Ubicado', tone: p.location == null ? WebChipTone.warn : WebChipTone.good),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              side: editor,
            );
          },
        ),
        const WebUnavailable(
          title: 'Plano, senderos y zonas a evitar',
          detail: 'Dibujar el plano, los senderos y las zonas a evitar todavía no se guarda en el servidor. Por ahora se administran los puntos de encuentro y su ubicación.',
          icon: Icons.map_outlined,
        ),
      ],
    );
  }
}

class _PointEditor extends StatefulWidget {
  const _PointEditor({required this.point, required this.onDone, super.key});

  final MeetingPoint? point;
  final VoidCallback onDone;

  @override
  State<_PointEditor> createState() => _PointEditorState();
}

class _PointEditorState extends State<_PointEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.point?.name ?? '');
  late final TextEditingController _route = TextEditingController(text: widget.point?.routeHint ?? '');
  late final TextEditingController _distance = TextEditingController(text: widget.point == null || widget.point!.distanceMeters == 0 ? '' : '${widget.point!.distanceMeters}');
  late final TextEditingController _walk = TextEditingController(text: widget.point == null || widget.point!.walkMinutes == 0 ? '' : '${widget.point!.walkMinutes}');
  late final TextEditingController _lat = TextEditingController(text: widget.point?.latitude?.toString() ?? '');
  late final TextEditingController _lng = TextEditingController(text: widget.point?.longitude?.toString() ?? '');
  late Hazard? _onlyFor = widget.point?.onlyFor;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_name, _route, _distance, _walk, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  MeetingPointDraft? _draft() {
    final double? lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final double? lng = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
    if (_name.text.trim().length < 2 || _route.text.trim().length < 2) {
      setState(() => _error = 'El nombre y cómo llegar son obligatorios.');
      return null;
    }
    if ((lat == null) != (lng == null)) {
      setState(() => _error = 'La latitud y la longitud van juntas.');
      return null;
    }
    return MeetingPointDraft(
      name: _name.text.trim(),
      routeHint: _route.text.trim(),
      distanceMeters: int.tryParse(_distance.text.trim()) ?? 0,
      walkMinutes: int.tryParse(_walk.text.trim()) ?? 0,
      onlyFor: _onlyFor,
      latitude: lat,
      longitude: lng,
    );
  }

  Future<void> _save() async {
    final MeetingPointDraft? draft = _draft();
    if (draft == null) return;
    final PanelRepository repo = AppScope.of(context).panelRepository!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.point == null) {
        await repo.createMeetingPoint(draft);
      } else {
        await repo.updateMeetingPoint(widget.point!.code, draft);
      }
      if (!mounted) return;
      webToast(context, 'Punto guardado');
      widget.onDone();
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'guardar punto (panel web)');
      if (mounted) setState(() => _error = 'No se pudo guardar el punto.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final MeetingPoint p = widget.point!;
    final bool ok = await webConfirm(
      context,
      title: 'Quitar ${p.code}',
      message: 'Se quita «${p.name}». Si tiene estudiantes asignados o es el último punto general, el sistema lo impide.',
      confirm: 'Quitar',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await AppScope.of(context).panelRepository!.deleteMeetingPoint(p.code);
      if (mounted) widget.onDone();
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'quitar punto (panel web)');
      if (mounted) webToast(context, 'No se pudo quitar el punto.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          WebPanelHeader(
            title: widget.point == null ? 'Nuevo punto' : '${widget.point!.code} · ${widget.point!.name}',
            trailing: WebChip(widget.point == null ? 'Creando' : 'Editando', tone: WebChipTone.dark),
          ),
          const SizedBox(height: 14),
          WebField(label: 'Nombre visible', controller: _name),
          const SizedBox(height: 14),
          WebField(label: 'Cómo llegar', controller: _route, hint: 'Desde Aula 7 · por el corredor sur'),
          const SizedBox(height: 14),
          WebGrid(minWidth: 140, gap: 12, children: <Widget>[
            WebField(label: 'Distancia (m)', controller: _distance, keyboardType: TextInputType.number),
            WebField(label: 'Caminando (min)', controller: _walk, keyboardType: TextInputType.number),
          ]),
          const SizedBox(height: 14),
          WebSelect<Hazard?>(
            label: 'Solo para',
            value: _onlyFor,
            items: <Hazard?, String>{null: 'Todas las amenazas', for (final Hazard h in Hazard.values) h: _hazardName(h)},
            onChanged: (Hazard? v) => setState(() => _onlyFor = v),
          ),
          const SizedBox(height: 14),
          WebGrid(minWidth: 140, gap: 12, children: <Widget>[
            WebField(label: 'Latitud', controller: _lat, hint: '6.4372'),
            WebField(label: 'Longitud', controller: _lng, hint: '-73.6122'),
          ]),
          if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: <Widget>[
            if (widget.point != null) WebButton(label: 'Quitar', secondary: true, onPressed: _busy ? null : _delete),
            WebButton(label: 'Guardar', busy: _busy, onPressed: _save),
          ]),
        ],
      ),
    );
  }
}

/// Dónde está cada punto en el GPS: es lo que permite a la app guiar en vivo.
class WebGeorrefScreen extends StatefulWidget {
  const WebGeorrefScreen({super.key});

  @override
  State<WebGeorrefScreen> createState() => _WebGeorrefScreenState();
}

class _WebGeorrefScreenState extends State<WebGeorrefScreen> {
  late Future<List<MeetingPoint>> _points;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _points = AppScope.of(context).panelRepository!.loadMeetingPoints();
  }

  @override
  Widget build(BuildContext context) {
    return WebPageFrame(
      title: 'Ubicación en el GPS',
      subtitle: 'Con la ubicación de cada punto, la app puede guiar a la gente en vivo',
      actions: const <Widget>[WebBackButton(label: 'Volver al mapa')],
      children: <Widget>[
        WebFuture<List<MeetingPoint>>(
          future: _points,
          onRetry: () => setState(() => _points = AppScope.of(context).panelRepository!.loadMeetingPoints()),
          builder: (BuildContext context, List<MeetingPoint> points) {
            final int placed = points.where((MeetingPoint p) => p.location != null).length;
            return WebPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  WebPanelHeader(title: 'Puntos de control', subtitle: '$placed de ${points.length} ubicados'),
                  const SizedBox(height: 8),
                  WebTable(
                    headers: const <String>['Punto', 'Nombre', 'Latitud', 'Longitud', 'Estado', ''],
                    empty: 'No hay puntos de encuentro.',
                    rows: <List<Widget>>[
                      for (final MeetingPoint p in points)
                        <Widget>[
                          Text(p.code, style: WebText.strong),
                          Text(p.name),
                          Text(p.latitude?.toStringAsFixed(6) ?? '—'),
                          Text(p.longitude?.toStringAsFixed(6) ?? '—'),
                          WebChip(p.location == null ? 'Sin ubicar' : 'Ubicado', tone: p.location == null ? WebChipTone.warn : WebChipTone.good),
                          p.location == null
                              ? const SizedBox.shrink()
                              : WebButton(
                                  label: 'Ver en el mapa',
                                  secondary: true,
                                  small: true,
                                  onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps?q=${p.latitude},${p.longitude}')),
                                ),
                        ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  const WebNotice(
                    'Para ubicar un punto, edítalo en «Mapa y rutas» y escribe su latitud y longitud (puedes copiarlas de Google Maps haciendo clic derecho sobre el lugar).',
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
