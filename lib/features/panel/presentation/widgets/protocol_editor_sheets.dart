import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../alerts/domain/protocol.dart';
import '../../domain/community_admin.dart';
import '../../domain/panel_repository.dart';
import 'admin_fields.dart';

/// Abre el editor del protocolo de una amenaza.
Future<void> showProtocolEditor(
  BuildContext context, {
  required Protocol protocol,
  required VoidCallback onChanged,
}) {
  return _open(context, _ProtocolEditor(protocol: protocol, onChanged: onChanged));
}

/// Abre el editor de un punto de encuentro; sin [point], crea uno nuevo.
Future<void> showMeetingPointEditor(
  BuildContext context, {
  MeetingPoint? point,
  required VoidCallback onChanged,
}) {
  return _open(context, _MeetingPointEditor(point: point, onChanged: onChanged));
}

Future<void> _open(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext context) => child,
  );
}

/* -------------------------------------------------------------------------- */

class _ProtocolEditor extends StatefulWidget {
  const _ProtocolEditor({required this.protocol, required this.onChanged});

  final Protocol protocol;
  final VoidCallback onChanged;

  @override
  State<_ProtocolEditor> createState() => _ProtocolEditorState();
}

class _ProtocolEditorState extends State<_ProtocolEditor> {
  late final List<TextEditingController> _before = _controllers(widget.protocol.beforeSteps);
  late final List<TextEditingController> _during = _controllers(widget.protocol.duringSteps);
  late final List<TextEditingController> _after = _controllers(widget.protocol.afterSteps);

  /// El servidor acepta hasta ocho pasos por sección.
  static const int _maxSteps = 8;

  /// Lo que dice una alerta roja son los pasos de «durante»: la alerta los lleva
  /// tal cual, y una línea de más de 120 caracteres no cabe completa.
  static const int _maxLength = 120;

  bool _busy = false;
  String? _error;

  static List<TextEditingController> _controllers(List<String> steps) => <TextEditingController>[
        for (final String step in steps) TextEditingController(text: step),
      ];

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[..._before, ..._during, ..._after]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _steps(List<TextEditingController> controllers) => <String>[
        for (final TextEditingController c in controllers)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ];

  Future<void> _save() async {
    if (_busy) return;

    final List<String> during = _steps(_during);
    if (during.isEmpty) {
      setState(() => _error = 'Escribe al menos un paso en «Durante»: es lo que dice la alerta.');
      return;
    }
    final List<String> all = <String>[..._steps(_before), ...during, ..._steps(_after)];
    if (all.any((String step) => step.length < 3)) {
      setState(() => _error = 'Cada paso necesita al menos tres letras.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final NavigatorState navigator = Navigator.of(context);
    final PanelRepository repository = AppScope.of(context).panelRepository!;

    try {
      await repository.saveProtocol(
        Protocol(
          hazard: widget.protocol.hazard,
          beforeSteps: _steps(_before),
          duringSteps: during,
          afterSteps: _steps(_after),
        ),
      );
      widget.onChanged();
      navigator.pop();
    } on PanelActionFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'guardar protocolo');
      if (mounted) {
        setState(() => _error = 'No pudimos guardar. Revisa la conexión e intenta otra vez.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _section(String title, String hint, List<TextEditingController> controllers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FormSection(title, hint: hint),
        for (int i = 0; i < controllers.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: AdminTextField(
                  label: 'Paso ${i + 1}',
                  controller: controllers[i],
                  maxLength: _maxLength,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: IconButton(
                  tooltip: 'Quitar paso',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    controllers.removeAt(i).dispose();
                  }),
                ),
              ),
            ],
          ),
        if (controllers.length < _maxSteps)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SheetButton(
                label: '+ AGREGAR PASO',
                onTap: () => setState(() => controllers.add(TextEditingController())),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetHeader(title: widget.protocol.hazard.label, subtitle: 'Protocolo'),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: <Widget>[
                if (_error != null) InlineNotice(_error!),
                _section('Antes', 'Cómo prepararse.', _before),
                _section(
                  'Durante',
                  'Es lo que dice la alerta roja cuando suena. Máximo 120 letras por '
                      'paso.',
                  _during,
                ),
                _section('Después', 'Qué hacer al terminar.', _after),
                const SizedBox(height: AppSpacing.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SheetButton(
                    label: 'GUARDAR PROTOCOLO',
                    filled: true,
                    busy: _busy,
                    onTap: _save,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Cada celular guarda este texto y lo lee sin conexión.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _MeetingPointEditor extends StatefulWidget {
  const _MeetingPointEditor({required this.point, required this.onChanged});

  final MeetingPoint? point;
  final VoidCallback onChanged;

  @override
  State<_MeetingPointEditor> createState() => _MeetingPointEditorState();
}

class _MeetingPointEditorState extends State<_MeetingPointEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.point?.name ?? '');
  late final TextEditingController _route = TextEditingController(text: widget.point?.routeHint ?? '');
  late final TextEditingController _distance = TextEditingController(
    text: (widget.point?.distanceMeters ?? 0) > 0 ? '${widget.point!.distanceMeters}' : '',
  );
  late final TextEditingController _minutes = TextEditingController(
    text: (widget.point?.walkMinutes ?? 0) > 0 ? '${widget.point!.walkMinutes}' : '',
  );
  late Hazard? _onlyFor = widget.point?.onlyFor;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _route.dispose();
    _distance.dispose();
    _minutes.dispose();
    super.dispose();
  }

  /// Un número opcional: vacío es cero, y lo que no es número se rechaza en vez de
  /// guardarse como cero sin avisar.
  int? _number(TextEditingController controller) {
    final String text = controller.text.trim();
    if (text.isEmpty) return 0;
    return int.tryParse(text);
  }

  Future<void> _run(Future<void> Function(PanelRepository repository) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final NavigatorState navigator = Navigator.of(context);
    final PanelRepository repository = AppScope.of(context).panelRepository!;

    try {
      await action(repository);
      widget.onChanged();
      navigator.pop();
    } on PanelActionFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'punto de encuentro');
      if (mounted) {
        setState(() => _error = 'No pudimos completar el cambio. Revisa la conexión.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    final String route = _route.text.trim();
    final int? distance = _number(_distance);
    final int? minutes = _number(_minutes);

    if (name.length < 2) {
      setState(() => _error = 'Ponle un nombre al punto de encuentro.');
      return;
    }
    if (route.length < 2) {
      setState(() => _error = 'Explica cómo llegar, aunque sea en una frase.');
      return;
    }
    if (distance == null || minutes == null) {
      setState(() => _error = 'La distancia y el tiempo son números, o déjalos vacíos.');
      return;
    }

    final MeetingPointDraft draft = MeetingPointDraft(
      name: name,
      routeHint: route,
      distanceMeters: distance,
      walkMinutes: minutes,
      onlyFor: _onlyFor,
    );
    final MeetingPoint? existing = widget.point;

    await _run((PanelRepository repository) async {
      if (existing == null) {
        await repository.createMeetingPoint(draft);
      } else {
        await repository.updateMeetingPoint(existing.code, draft);
      }
    });
  }

  Future<void> _delete() async {
    final MeetingPoint point = widget.point!;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(),
        title: Text('¿Quitar ${point.code}?'),
        content: const Text(
          'Si hay estudiantes asignados a este punto, o es el único punto general, '
          'el servidor no lo permite.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: const Text('QUITAR'),
          ),
        ],
      ),
    );
    if (yes != true) return;

    await _run((PanelRepository repository) => repository.deleteMeetingPoint(point.code));
  }

  @override
  Widget build(BuildContext context) {
    final MeetingPoint? point = widget.point;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetHeader(
            title: point == null ? 'Nuevo punto de encuentro' : '${point.code} · ${point.name}',
            subtitle: 'Punto de encuentro',
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: <Widget>[
                if (_error != null) InlineNotice(_error!),
                AdminTextField(label: 'Nombre', controller: _name, maxLength: 60),
                AdminTextField(
                  label: 'Cómo llegar',
                  controller: _route,
                  maxLength: 120,
                ),
                AdminTextField(
                  label: 'Distancia en metros (opcional)',
                  controller: _distance,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
                AdminTextField(
                  label: 'Minutos caminando (opcional)',
                  controller: _minutes,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                ),
                const FormSection(
                  'Para qué amenaza',
                  hint: 'Un punto general sirve para todas. Uno solo para una amenaza '
                      '—la zona alta, en una inundación— no se usa en las demás.',
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    ChoiceBox(
                      label: 'TODAS',
                      selected: _onlyFor == null,
                      onTap: () => setState(() => _onlyFor = null),
                    ),
                    for (final Hazard hazard in Hazard.values)
                      ChoiceBox(
                        label: hazard.label,
                        selected: _onlyFor == hazard,
                        onTap: () => setState(() => _onlyFor = hazard),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    SheetButton(
                      label: point == null ? 'CREAR PUNTO' : 'GUARDAR CAMBIOS',
                      filled: true,
                      busy: _busy,
                      onTap: _save,
                    ),
                    if (point != null)
                      SheetButton(
                        label: 'QUITAR',
                        destructive: true,
                        onTap: _busy ? null : _delete,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
