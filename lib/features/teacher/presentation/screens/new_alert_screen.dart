import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/alert_level.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/protocol.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/panel_repository.dart';
import '../../../alerts/presentation/widgets/alert_level_style.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';
import '../../domain/teacher_repository.dart';
import '../widgets/hold_to_send_button.dart';

/// Pantalla 14: emitir una alerta.
///
/// Tres decisiones en una sola pantalla —qué pasa, qué tan grave, dónde— porque
/// quien la usa lo hace con el edificio moviéndose. Nada de pasos ni de
/// pantallas encadenadas.
class NewAlertScreen extends StatefulWidget {
  const NewAlertScreen({
    required this.groups,
    this.initialHazard,
    this.incidentId,
    super.key,
  });

  /// Grupos a cargo del docente, para poder acotar la zona.
  final List<String> groups;

  /// Amenaza ya escogida, cuando la alerta sale de un reporte: quien la emite
  /// ya sabe de qué se trata y no tiene por qué volver a decirlo.
  final Hazard? initialHazard;

  /// El reporte de la comunidad que motiva esta alerta, para dejarlo enlazado.
  final String? incidentId;

  @override
  State<NewAlertScreen> createState() => _NewAlertScreenState();
}

class _NewAlertScreenState extends State<NewAlertScreen> {
  late Hazard? _hazard = widget.initialHazard;
  AlertLevel? _level;
  String _scope = _everyone;
  bool _sending = false;

  /// A cuánta gente le llega, según el servidor. `null` mientras se consulta o
  /// si no se pudo saber.
  int? _reach;

  /// Dónde puede acotarse la alerta: todo el colegio, o uno de los grupos reales.
  ///
  /// No hay «Bloque A» ni «Patio»: esos nombres eran inventados, y el servidor no
  /// sabe cómo repartir una alerta por un lugar que no existe. Un docente acota a
  /// sus grupos; coordinación, a cualquiera de los del colegio.
  static const String _everyone = 'Todo el instituto';

  /// Los grupos entre los que se puede escoger. Para coordinación, que no tiene
  /// grupos propios, se piden al servidor.
  List<String> _groups = <String>[];

  @override
  void initState() {
    super.initState();
    _groups = widget.groups;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reachLoaded ??= _loadReach();
    _groupsLoaded ??= _loadGroups();
  }

  Future<void>? _groupsLoaded;

  Future<void> _loadGroups() async {
    if (widget.groups.isNotEmpty) {
      return;
    }
    final PanelRepository? panel = AppScope.of(context).panelRepository;
    if (panel == null) {
      return;
    }
    try {
      final List<GroupInfo> groups = await panel.loadGroups();
      if (mounted) {
        setState(() => _groups = <String>[for (final GroupInfo g in groups) g.grade]);
      }
    } catch (error, stack) {
      // Sin la lista se puede emitir igual, para todo el colegio.
      ErrorReporter.report(error, stack, context: 'grupos para acotar la alerta');
    }
  }

  Future<void>? _reachLoaded;

  Future<void> _loadReach() async {
    try {
      final int? reach = await AppScope.of(context).teacherRepository!.loadReach();
      if (mounted) {
        setState(() => _reach = reach);
      }
    } catch (error, stack) {
      // Sin el número se puede emitir igual: la pantalla dice la verdad en vez
      // de mostrar uno inventado.
      ErrorReporter.report(error, stack, context: 'alcance de la alerta');
    }
  }

  bool get _isComplete => _hazard != null && _level != null;

  Future<void> _send() async {
    final Hazard? hazard = _hazard;
    final AlertLevel? level = _level;
    if (hazard == null || level == null || _sending) {
      return;
    }

    setState(() => _sending = true);
    final NavigatorState navigator = Navigator.of(context);
    final AppScope scope = AppScope.of(context);

    try {
      final AlertDraft draft = AlertDraft(
        level: level,
        hazard: hazard,
        title: _titleFor(hazard, level),
        scope: _scope,
        // Sin punto: el servidor usa el principal del colegio, el que coordinación
        // definió. Escribir «P1» aquí era suponer que existe uno con ese código.
        meetingPoint: null,
        instructions: await _instructionsFor(hazard, level, scope),
        incidentId: widget.incidentId,
      );

      final Alert alert =
          await scope.teacherRepository!.issueAlert(draft);
      ErrorReporter.trace('alerta ${alert.level.wire} emitida', context: 'docente');

      if (mounted) {
        navigator.pop();
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'emitir alerta');
      if (mounted) {
        // Si el servidor respondió, dice por qué («ya hay una alerta activa») y
        // eso es lo que hay que mostrar. Si ni siquiera respondió, no se sabe
        // si la alerta salió: se manda a la radio, que no depende de la red.
        final String message = error is ApiException && error.statusCode != null
            ? error.message
            : 'No se pudo emitir la alerta. Avisa a coordinación por radio.';
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('NUEVA ALERTA', style: AppTextStyles.screenTitle),
                  ),
                  TextButton(
                    onPressed: _sending ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkMuted,
                    ),
                    child: const Text('CANCELAR'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenGutter,
                ),
                children: <Widget>[
                  const _StepLabel(number: 1, label: 'Qué pasa'),
                  _HazardPicker(
                    selected: _hazard,
                    onChanged: (Hazard value) => setState(() => _hazard = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _StepLabel(number: 2, label: 'Qué tan grave'),
                  for (final AlertLevel level in AlertLevel.values)
                    _LevelOption(
                      level: level,
                      selected: _level == level,
                      onTap: () => setState(() => _level = level),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  const _StepLabel(number: 3, label: 'Dónde'),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final String scope in <String>[_everyone, ..._groups])
                        _ScopeChip(
                          label: scope,
                          selected: _scope == scope,
                          onTap: () => setState(() => _scope = scope),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    // Con el número real del servidor. Mientras llega, o si no
                    // se pudo saber, se dice sin inventar una cifra.
                    '${_reach == null ? 'Llega a toda la comunidad registrada' : 'Llega a $_reach personas'}: '
                    'estudiantes, docentes, acudientes y Defensa Civil Barbosa.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HoldToSendButton(
                    label: 'MANTÉN PARA ENVIAR',
                    enabled: _isComplete && !_sending,
                    isSending: _sending,
                    background: _level == null
                        ? AppColors.brand
                        : AlertLevelStyle.of(_level!).headerColor,
                    foreground: _level == AlertLevel.amarilla
                        ? AppColors.ink
                        : AppColors.onBrand,
                    onCompleted: _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Título por defecto según lo escogido.
  ///
  /// El docente no escribe: en una emergencia no hay tiempo, y un texto libre
  /// que le llega a 1.248 personas es un riesgo que no hace falta correr.
  static String _titleFor(Hazard hazard, AlertLevel level) {
    return switch (hazard) {
      Hazard.sismo => level == AlertLevel.roja ? 'SISMO' : 'SISMO REPORTADO',
      Hazard.incendio => 'INCENDIO',
      Hazard.inundacion => 'CRECIENTE DE LA QUEBRADA',
      Hazard.lluvia => 'LLUVIA FUERTE',
    };
  }

  /// Lo que dice la alerta que llega a la gente.
  ///
  /// En una roja son los pasos de **«durante»** del protocolo que coordinación
  /// publicó para esa amenaza: lo que se edita en Protocolos es exactamente lo que
  /// le llega a cada celular, y no hay un texto aparte escrito en la app con
  /// lugares inventados. Si el protocolo no se pudo traer, se usan instrucciones
  /// generales que no nombran ningún sitio.
  Future<List<String>> _instructionsFor(
    Hazard hazard,
    AlertLevel level,
    AppScope scope,
  ) async {
    if (level == AlertLevel.roja) {
      try {
        final List<Protocol> protocols =
            await scope.alertRepository.loadProtocols();
        for (final Protocol protocol in protocols) {
          if (protocol.hazard == hazard && protocol.duringSteps.isNotEmpty) {
            // El servidor acepta hasta 6 pasos de 120 caracteres.
            return <String>[
              for (final String step in protocol.duringSteps.take(6))
                step.length > 120 ? step.substring(0, 120) : step,
            ];
          }
        }
      } catch (error, stack) {
        ErrorReporter.report(error, stack, context: 'protocolo de la alerta');
      }
      return const <String>[
        'Sal con tu grupo, en fila y sin correr',
        'No vuelvas por nada',
        'Ve a tu punto de encuentro',
      ];
    }

    if (level == AlertLevel.naranja) {
      return const <String>[
        'Guarda tus cosas',
        'Ubícate cerca de la puerta con tu grupo',
        'Espera la indicación de salir',
      ];
    }

    return const <String>[
      'Quédate en tu salón',
      'Espera nuevas indicaciones',
    ];
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        '$number · ${label.toUpperCase()}',
        style: AppTextStyles.eyebrow,
      ),
    );
  }
}

class _HazardPicker extends StatelessWidget {
  const _HazardPicker({required this.selected, required this.onChanged});

  final Hazard? selected;
  final ValueChanged<Hazard> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final Hazard hazard in Hazard.values) ...<Widget>[
          if (hazard != Hazard.values.first) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Material(
              color: selected == hazard ? AppColors.brand : AppColors.surface,
              shape: Border.fromBorderSide(
                BorderSide(
                  color: selected == hazard ? AppColors.brand : AppColors.border,
                ),
              ),
              child: InkWell(
                onTap: () => onChanged(hazard),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        hazardIcon(hazard),
                        size: 20,
                        color: selected == hazard
                            ? AppColors.onBrand
                            : AppColors.ink,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        hazard.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: selected == hazard
                              ? AppColors.onBrand
                              : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LevelOption extends StatelessWidget {
  const _LevelOption({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  final AlertLevel level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AlertLevelStyle style = AlertLevelStyle.of(level);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected ? const Color(0xFFFDEDEA) : AppColors.surface,
        shape: Border.fromBorderSide(
          BorderSide(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(width: 18, height: 18, color: style.headerColor),
                const SizedBox(width: AppSpacing.md),
                Text(
                  level.label,
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '· ${level.meaning}',
                    style: AppTextStyles.caption,
                  ),
                ),
                if (selected)
                  const Icon(Icons.check, size: 18, color: AppColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.surface,
      shape: Border.fromBorderSide(
        BorderSide(color: selected ? AppColors.ink : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: selected ? AppColors.onBrand : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
