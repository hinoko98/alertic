import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/live_updates.dart';
import '../../../alerts/presentation/widgets/alert_level_style.dart';
import '../../../alerts/presentation/widgets/end_alert.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';
import '../../../incidents/domain/incident.dart';
import '../../../incidents/presentation/incident_inbox.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../../teacher/presentation/screens/new_alert_screen.dart';
import '../../domain/panel_repository.dart';
import '../panel_layout.dart';

/// Pantalla 18: el tablero de emergencia en vivo.
///
/// Está pensado para verse de lejos, proyectado o en una pantalla que nadie
/// toca durante la emergencia. Por eso las cifras son enormes y lo que exige
/// acción —quién necesita ayuda— está a la derecha, siempre visible, sin
/// desplazar.
class EmergencyTab extends StatefulWidget {
  const EmergencyTab({super.key});

  @override
  State<EmergencyTab> createState() => _EmergencyTabState();
}

class _EmergencyTabState extends State<EmergencyTab> {
  EmergencyBoard? _board;
  List<HazardSignal> _signals = <HazardSignal>[];
  String? _loadedAlertId;

  /// En calma no hay alerta, así que comparar el id cargado con el actual da
  /// «ya está» y nunca se pedirían los avisos externos.
  bool _hasLoaded = false;

  StreamSubscription<LiveChange>? _live;
  bool _refreshing = false;
  bool _refreshAgain = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Una sola suscripción, aunque este método se llame varias veces.
    _live ??= AppScope.of(context).liveUpdates.changes.listen(_onLiveChange);
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    super.dispose();
  }

  /// Algo cambió en el servidor: se vuelve a pedir lo que corresponde.
  ///
  /// No se usa el aviso como dato. Se pide el tablero completo cada vez, así
  /// que un aviso perdido no deja los números viejos para siempre.
  void _onLiveChange(LiveChange change) {
    switch (change) {
      case LiveChange.reports:
        unawaited(_refreshBoard());
      case LiveChange.hazardSignals:
        unawaited(_refreshSignals());
      // Los reportes de la comunidad los recarga la propia bandeja.
      case LiveChange.myChildren:
      case LiveChange.incidents:
        break;
    }
  }

  /// Vuelve a pedir el tablero sin apilar peticiones.
  ///
  /// Si llega otro aviso mientras la consulta va en camino no se lanza una
  /// segunda en paralelo: se anota y se repite una vez al terminar. Así durante
  /// una alerta roja, con cientos de avisos, nunca hay más de una consulta del
  /// tablero en vuelo.
  Future<void> _refreshBoard() async {
    final String? alertId = _loadedAlertId;
    if (alertId == null || !mounted) {
      return;
    }
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }

    _refreshing = true;
    try {
      final EmergencyBoard board =
          await AppScope.of(context).panelRepository!.loadBoard(alertId);
      if (mounted && _loadedAlertId == alertId) {
        setState(() => _board = board);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'tablero en vivo');
    } finally {
      _refreshing = false;
      if (_refreshAgain) {
        _refreshAgain = false;
        unawaited(_refreshBoard());
      }
    }
  }

  Future<void> _refreshSignals() async {
    if (!mounted) {
      return;
    }
    try {
      final List<HazardSignal> signals =
          await AppScope.of(context).panelRepository!.loadSignals();
      if (mounted) {
        setState(() => _signals = signals);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'avisos externos en vivo');
    }
  }

  Future<void> _load(Alert? alert) async {
    try {
      final PanelRepository repository = AppScope.of(context).panelRepository!;
      final List<HazardSignal> signals = await repository.loadSignals();
      final EmergencyBoard? board =
          alert == null ? null : await repository.loadBoard(alert.id);

      if (mounted) {
        setState(() {
          _board = board;
          _signals = signals;
          _loadedAlertId = alert?.id;
          _hasLoaded = true;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'tablero');
    }
  }

  Future<void> _dismiss(HazardSignal signal) async {
    await AppScope.of(context).panelRepository!.dismissSignal(signal.id);
    if (mounted) {
      setState(() =>
          _signals = _signals.where((HazardSignal s) => s.id != signal.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);

    return StreamBuilder<Alert?>(
      stream: scope.alertRepository.watchActiveAlert(),
      builder: (BuildContext context, AsyncSnapshot<Alert?> snapshot) {
        final Alert? alert = snapshot.data;

        if (snapshot.connectionState != ConnectionState.waiting &&
            (!_hasLoaded || _loadedAlertId != alert?.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _load(alert);
          });
        }

        final bool compact = PanelLayout.isCompact(context);

        return Column(
          children: <Widget>[
            if (alert != null) _AlertHeader(alert: alert),
            Expanded(
              child: compact
                  // En el celular las dos columnas se apilan en un solo
                  // desplazamiento. Lo primero que se ve sigue siendo el
                  // tablero: quien abre esto en una emergencia quiere el
                  // número de personas a salvo, no la lista de avisos.
                  ? ListView(
                      children: <Widget>[
                        if (alert == null)
                          const _CalmState()
                        else
                          _BoardPanel(board: _board, compact: true),
                        const Divider(height: 1, color: AppColors.border),
                        _SidePanel(
                          board: _board,
                          signals: _signals,
                          onDismiss: _dismiss,
                          compact: true,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: alert == null
                              ? const _CalmState()
                              : _BoardPanel(board: _board),
                        ),
                        const VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: AppColors.border,
                        ),
                        Expanded(
                          flex: 2,
                          child: _SidePanel(
                            board: _board,
                            signals: _signals,
                            onDismiss: _dismiss,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Franja roja con la alerta activa y sus acciones.
class _AlertHeader extends StatelessWidget {
  const _AlertHeader({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final AlertLevelStyle style = AlertLevelStyle.of(alert.level);
    final Duration elapsed = DateTime.now().difference(alert.issuedAt);

    final bool compact = PanelLayout.isCompact(context);

    final Widget summary = Row(
      children: <Widget>[
        Icon(style.icon, size: compact ? 22 : 26, color: style.headerForeground),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'ALERTA ${alert.level.label} · EMITIDA ${alert.issuedAtLabel}'
                '${alert.issuedBy == null ? '' : ' POR ${alert.issuedBy!.toUpperCase()}'}'
                ' · HACE ${elapsed.inMinutes} MIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: style.headerForeground,
                ),
              ),
              Text(
                '${alert.title} · ${alert.scope}',
                style: TextStyle(
                  fontSize: compact ? 19 : 24,
                  fontWeight: FontWeight.w900,
                  color: style.headerForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final List<Widget> actions = <Widget>[
      _HeaderButton(
        label: 'ENVIAR ACTUALIZACIÓN',
        onTap: () => _updatesPending(context),
      ),
      const SizedBox(width: AppSpacing.sm),
      _HeaderButton(
        label: 'FINALIZAR ALERTA',
        filled: true,
        // Pide confirmación: terminar una evacuación por un toque accidental es
        // tan grave como emitirla por uno.
        onTap: () => confirmEndAlert(context, alert),
      ),
    ];

    return Container(
      color: style.headerColor,
      // En el celular la franja llega hasta el borde de arriba, así que hay que
      // sumarle el alto de la barra de estado: sin eso el título queda debajo
      // del reloj y no se lee. En el computador ese hueco es cero.
      padding: EdgeInsets.fromLTRB(
        PanelLayout.gutter(context),
        AppSpacing.md + MediaQuery.paddingOf(context).top,
        PanelLayout.gutter(context),
        AppSpacing.md,
      ),
      // En el celular los botones bajan a su propia línea. Puestos al lado del
      // título, «FINALIZAR ALERTA» quedaría a un dedo de distancia del texto que
      // dice qué está pasando, y es el botón que apaga la evacuación.
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                summary,
                const SizedBox(height: AppSpacing.md),
                Row(children: <Widget>[
                  for (final Widget action in actions)
                    if (action is _HeaderButton) Expanded(child: action) else action,
                ]),
              ],
            )
          : Row(children: <Widget>[Expanded(child: summary), ...actions]),
    );
  }

  /// Las actualizaciones a la comunidad («ya estamos en el punto», «falta el
  /// bloque B») necesitan una ruta en el servidor que todavía no existe. Se dice
  /// así, en vez de fingir que se mandó.
  static void _updatesPending(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('El envío de actualizaciones a la comunidad llega después.'),
        ),
      );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.dark = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  /// Para usarlo sobre fondo blanco (en calma) y no sobre la franja roja de la
  /// alerta, que es para lo que se diseñó el botón.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark
          ? AppColors.brand
          : (filled ? AppColors.ink : Colors.transparent),
      shape: Border.fromBorderSide(
        BorderSide(color: dark ? AppColors.brand : AppColors.onBrand),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.onBrand,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalmState extends StatelessWidget {
  const _CalmState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('ESTADO DEL COLEGIO', style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'SIN ALERTAS',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Jornada normal. El tablero se llena solo cuando hay una alerta '
            'activa.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Coordinación puede emitir desde aquí: el panel es donde se maneja
          // todo sobre las alertas, y no tiene que ir a buscar un celular de
          // docente. Pide sostener el botón, como en la app del docente.
          Align(
            alignment: Alignment.centerLeft,
            child: _HeaderButton(
              label: 'EMITIR ALERTA',
              filled: true,
              dark: true,
              onTap: () => _openIssueAlert(context),
            ),
          ),
          // Los reportes de la comunidad están en el panel lateral, que se ve
          // siempre —con alerta y en calma—. Ponerlos aquí también dibujaba la
          // bandeja dos veces.
        ],
      ),
    );
  }
}

/// Las cifras y el avance por grado.
class _BoardPanel extends StatelessWidget {
  const _BoardPanel({required this.board, this.compact = false});

  final EmergencyBoard? board;

  /// Apilado dentro de otro desplazamiento: entonces este no se desplaza solo,
  /// porque dos barras de desplazamiento anidadas no se pueden usar con el
  /// pulgar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final EmergencyBoard? data = board;
    if (data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brand),
      );
    }

    return ListView(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      shrinkWrap: compact,
      physics: compact ? const NeverScrollableScrollPhysics() : null,
      children: <Widget>[
        IntrinsicHeight(
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _BigStat(
                    value: _thousands(data.safe),
                    label: 'A salvo · ${data.safePercent} %',
                    emphasis: true,
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: _BigStat(
                    value: '${data.needHelp}',
                    label: 'Necesitan ayuda',
                    emphasis: data.needHelp > 0,
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.border),
                Expanded(
                  child: _BigStat(
                    value: '${data.noResponse}',
                    label: 'Sin respuesta',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const Text('POR GRADO', style: AppTextStyles.eyebrow),
        const SizedBox(height: AppSpacing.md),
        for (final GradeProgress grade in data.byGrade)
          _GradeRow(grade: grade),
      ],
    );
  }

  /// `1106` se lee mejor como `1.106` en una pantalla que se mira de lejos.
  static String _thousands(int value) {
    final String digits = value.toString();
    if (digits.length <= 3) return digits;
    final int cut = digits.length - 3;
    return '${digits.substring(0, cut)}.${digits.substring(cut)}';
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.value,
    required this.label,
    this.emphasis = false,
  });

  final String value;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1.5,
              color: emphasis ? AppColors.brand : AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.grade});

  final GradeProgress grade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              grade.grade,
              style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: grade.progress,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 72,
            child: Text(
              '${grade.safe}/${grade.total}',
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${grade.needHelp}',
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: grade.needHelp > 0 ? FontWeight.w900 : FontWeight.w400,
                color: grade.needHelp > 0 ? AppColors.brand : AppColors.inkMuted,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${grade.noResponse}',
              textAlign: TextAlign.right,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Columna derecha: quién necesita ayuda y los avisos externos.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.board,
    required this.signals,
    required this.onDismiss,
    this.compact = false,
  });

  final EmergencyBoard? board;
  final List<HazardSignal> signals;
  final Future<void> Function(HazardSignal) onDismiss;

  /// Apilado bajo el tablero, en el celular.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final EmergencyBoard? data = board;

    return ListView(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      shrinkWrap: compact,
      physics: compact ? const NeverScrollableScrollPhysics() : null,
      children: <Widget>[
        // Los reportes de la comunidad van primero: un reporte nuevo durante una
        // alerta puede ser lo que cambie lo que hay que hacer.
        const Text('REPORTES DE LA COMUNIDAD', style: AppTextStyles.eyebrow),
        const SizedBox(height: AppSpacing.md),
        IncidentInbox(
          onEscalate: (Incident incident) =>
              _openIssueAlert(context, incident: incident),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (data != null && data.needHelpList.isNotEmpty) ...<Widget>[
          Text(
            'NECESITAN AYUDA · ${data.needHelpList.length}',
            style: AppTextStyles.eyebrow.copyWith(color: AppColors.brand),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final HelpRequest request in data.needHelpList)
            _HelpRow(request: request),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (data != null && data.byMeetingPoint.isNotEmpty) ...<Widget>[
          const Text('PUNTOS DE ENCUENTRO', style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (final MeetingPointCount point in data.byMeetingPoint) ...<Widget>[
                Expanded(
                  child: Container(
                    color: point.code == 'P1' ? AppColors.brand : AppColors.ink,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${point.count}',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: AppColors.onBrand,
                          ),
                        ),
                        Text(
                          point.code,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            color: AppColors.onBrand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (point != data.byMeetingPoint.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        _SignalsSection(signals: signals, onDismiss: onDismiss),
      ],
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEDEA),
        border: Border.all(color: AppColors.brand),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 18, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${PersonName.short(request.fullName)} · ${request.grade}',
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                ),
                Text(
                  '${request.location} · '
                  '${request.reportedAt.hour}:'
                  '${request.reportedAt.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              // TODO(brigadas): asignar brigadista desde el panel.
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  const SnackBar(content: Text('Asignación de brigadas: pendiente.')),
                );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border),
              shape: const RoundedRectangleBorder(),
            ),
            child: const Text(
              'ASIGNAR BRIGADA',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avisos de fuentes externas.
///
/// Nunca disparan una alerta solos: aparecen aquí como sugerencia y coordinación
/// decide. Evacuar 1.248 personas tiene sus propios riesgos, y esa decisión no
/// la puede tomar una API.
class _SignalsSection extends StatelessWidget {
  const _SignalsSection({required this.signals, required this.onDismiss});

  final List<HazardSignal> signals;
  final Future<void> Function(HazardSignal) onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('AVISOS EXTERNOS', style: AppTextStyles.eyebrow),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Sugerencias de fuentes públicas. Coordinación decide si se convierten '
          'en alerta.',
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
        const SizedBox(height: AppSpacing.md),
        if (signals.isEmpty)
          Text('Sin avisos por ahora.', style: AppTextStyles.caption)
        else
          for (final HazardSignal signal in signals)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration:
                  BoxDecoration(border: Border.all(color: AppColors.border)),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    hazardIcon(signal.hazard),
                    size: 18,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          signal.headline,
                          style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${signal.detail} · ${signal.source}',
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onDismiss(signal),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.inkMuted,
                    ),
                    child: const Text(
                      'DESCARTAR',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}


/// Abre la pantalla de emitir una alerta desde el panel.
///
/// Con [incident], la alerta sale de un reporte de la comunidad: ya se sabe de
/// qué amenaza se trata y queda enlazada al reporte que la motivó. Sin grupos:
/// coordinación no está acotada a ninguno, su alcance es el colegio.
void _openIssueAlert(BuildContext context, {Incident? incident}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => NewAlertScreen(
        groups: const <String>[],
        initialHazard: incident?.hazard,
        incidentId: incident?.id,
      ),
    ),
  );
}
