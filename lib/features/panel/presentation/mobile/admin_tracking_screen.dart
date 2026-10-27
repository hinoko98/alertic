import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/shell_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/live_updates.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../alerts/presentation/widgets/end_alert.dart';
import '../../../coordination/domain/coordination_repository.dart';
import '../../../coordination/presentation/coordination_actions.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../domain/panel_repository.dart';

/// Pantalla 52: seguimiento en vivo de una alerta, en el celular de coordinación.
///
/// Tres preguntas, en este orden: cuántos están a salvo, quién pide ayuda y
/// dónde está la gente. Los números son los del servidor y se refrescan solos
/// con cada reporte; el tablero completo, por grado, está a un toque.
class AdminTrackingScreen extends StatefulWidget {
  const AdminTrackingScreen({required this.alert, super.key});

  final Alert alert;

  @override
  State<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends State<AdminTrackingScreen> {
  EmergencyBoard? _board;
  Map<String, String> _pointNames = const <String, String>{};
  bool _failed = false;

  /// Quién va por cada persona que pidió ayuda: id de la persona → nombre.
  Map<String, String> _assignees = const <String, String>{};

  /// Las listas que ya entregaron los docentes.
  List<DeliveredRoster> _rosters = const <DeliveredRoster>[];

  StreamSubscription<LiveChange>? _live;
  StreamSubscription<Alert?>? _active;
  Timer? _clock;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final AppScope scope = AppScope.of(context);
    _live = scope.liveUpdates.changes
        .where((LiveChange c) => c == LiveChange.reports)
        .listen((_) => unawaited(_load()));
    // Si la alerta termina (aquí o en otro celular), no tiene sentido seguir
    // mostrando sus números como si estuviera en curso.
    _active = scope.alertRepository.watchActiveAlert().listen((Alert? alert) {
      if (mounted && alert?.id != widget.alert.id) Navigator.of(context).maybePop();
    });
    // Los minutos transcurridos avanzan aunque nadie reporte.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    unawaited(_load());
    unawaited(_loadPoints());
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    unawaited(_active?.cancel());
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final PanelRepository? panel = AppScope.of(context).panelRepository;
    if (panel == null) return;
    unawaited(_loadCoordination());
    try {
      final EmergencyBoard board = await panel.loadBoard(widget.alert.id);
      if (mounted) {
        setState(() {
          _board = board;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'seguimiento en vivo');
      if (mounted) setState(() => _failed = true);
    }
  }

  /// A quién se mandó por cada pedido y qué listas llegaron. Si falla, el
  /// tablero se ve igual: solo faltan esos dos datos.
  Future<void> _loadCoordination() async {
    final CoordinationRepository? coordination = AppScope.of(context).coordinationRepository;
    if (coordination == null) return;
    try {
      final List<HelpAssignment> assignments = await coordination.loadHelpAssignments(widget.alert.id);
      final List<DeliveredRoster> rosters = await coordination.loadDeliveredRosters(widget.alert.id);
      if (!mounted) return;
      setState(() {
        _assignees = <String, String>{for (final HelpAssignment a in assignments) a.personId: a.assignee};
        _rosters = rosters;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'brigadistas y listas');
    }
  }

  Future<void> _assign(HelpRequest request) async {
    final String? who = await assignHelp(
      context,
      alertId: widget.alert.id,
      personId: request.personId,
      personName: request.fullName,
    );
    if (who != null && mounted) {
      setState(() => _assignees = <String, String>{..._assignees, request.personId: who});
    }
  }

  /// Solo para poner nombre a los códigos de punto («P1 · Cancha»). Sin ellos se
  /// muestra el código, que también se entiende.
  Future<void> _loadPoints() async {
    try {
      final List<MeetingPoint> points =
          await AppScope.of(context).panelRepository?.loadMeetingPoints() ?? const <MeetingPoint>[];
      if (mounted) {
        setState(() => _pointNames = <String, String>{for (final MeetingPoint p in points) p.code: p.name});
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'nombres de los puntos');
    }
  }

  void _openBoard() {
    final ShellScope? shell = ShellScope.maybeOf(context);
    Navigator.of(context).maybePop();
    shell?.openTab('Tablero');
  }

  @override
  Widget build(BuildContext context) {
    final EmergencyBoard? board = _board;
    final int minutes = DateTime.now().difference(widget.alert.issuedAt).inMinutes;

    return AppPage(
      title: 'Seguimiento en vivo',
      subtitle: '${widget.alert.title} · desde ${widget.alert.issuedAtLabel} · $minutes min',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      actions: const <Widget>[_LiveChip()],
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.screenGutter,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('seguimiento-actualizacion'),
                onPressed: () => sendAlertUpdate(context, widget.alert),
                icon: const Icon(Icons.campaign_outlined, size: 20),
                label: const Text('Enviar actualización', style: TextStyle(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.brandDark,
                  side: const BorderSide(color: AppColors.brandSoft),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: const Key('seguimiento-tablero'),
                  onPressed: _openBoard,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Tablero completo', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  key: const Key('seguimiento-finalizar'),
                  onPressed: () => confirmEndAlert(context, widget.alert),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.ink,
                  ),
                  child: const Text('Finalizar alerta', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
      body: board == null
          ? Center(
              child: _failed
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.screenGutter),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text('No pudimos traer los números. Intenta otra vez.',
                              style: AppTextStyles.body, textAlign: TextAlign.center),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(color: AppColors.brand),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.md,
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                ),
                children: <Widget>[
                  _SafeCard(board: board),
                  const SectionLabel('Pedidos de ayuda'),
                  if (board.needHelpList.isEmpty)
                    const AppCard(
                      key: Key('seguimiento-sin-ayuda'),
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text('Nadie ha pedido ayuda.', style: AppTextStyles.caption),
                    )
                  else
                    AppCard(
                      key: const Key('seguimiento-ayuda'),
                      borderColor: AppColors.brandSoft,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < board.needHelpList.length; i++) ...<Widget>[
                            if (i > 0) const Divider(height: 1, color: AppColors.border),
                            _HelpRow(
                              request: board.needHelpList[i],
                              assignee: _assignees[board.needHelpList[i].personId],
                              onAssign: () => _assign(board.needHelpList[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (_rosters.isNotEmpty) ...<Widget>[
                    const SectionLabel('Listas entregadas'),
                    AppCard(
                      key: const Key('seguimiento-listas'),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Column(
                        children: <Widget>[
                          for (int i = 0; i < _rosters.length; i++) ...<Widget>[
                            if (i > 0) const Divider(height: 1, color: AppColors.border),
                            _RosterRow(roster: _rosters[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (board.byMeetingPoint.isNotEmpty) ...<Widget>[
                    const SectionLabel('Por punto de encuentro'),
                    AppCard(
                      key: const Key('seguimiento-puntos'),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: <Widget>[
                          for (final MeetingPointCount point in board.byMeetingPoint)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      _pointNames[point.code] == null
                                          ? point.code
                                          : '${point.code} · ${_pointNames[point.code]}',
                                      style: AppTextStyles.itemTitle,
                                    ),
                                  ),
                                  Text('${point.count}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.brandSoft, borderRadius: BorderRadius.circular(999)),
      child: const Text(
        '● En curso',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brand),
      ),
    );
  }
}

/// El número grande: a salvo, de cuántos, y lo que falta.
class _SafeCard extends StatelessWidget {
  const _SafeCard({required this.board});

  final EmergencyBoard board;

  @override
  Widget build(BuildContext context) {
    final double safe = board.total == 0 ? 0 : board.safe / board.total;
    final double help = board.total == 0 ? 0 : board.needHelp / board.total;

    return AppCard(
      key: const Key('seguimiento-a-salvo'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('A SALVO', style: AppTextStyles.eyebrow),
                    Text(
                      '${board.safe}',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.success),
                    ),
                  ],
                ),
              ),
              Text(
                'de ${board.total} · ${board.safePercent} %',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: '${board.safePercent} por ciento a salvo',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: <Widget>[
                    Expanded(flex: (safe * 1000).round(), child: const ColoredBox(color: AppColors.success)),
                    Expanded(flex: (help * 1000).round(), child: const ColoredBox(color: AppColors.brand)),
                    Expanded(
                      flex: ((1 - safe - help).clamp(0, 1) * 1000).round(),
                      child: const ColoredBox(color: AppColors.border),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _Box(
                  value: board.noResponse,
                  label: 'Sin confirmar',
                  background: AppColors.warningSoft,
                  foreground: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Box(
                  value: board.needHelp,
                  label: 'Piden ayuda',
                  background: AppColors.brandSoft,
                  foreground: AppColors.brandDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.value, required this.label, required this.background, required this.foreground});

  final int value;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: foreground)),
          Text(label, style: TextStyle(fontSize: 12, color: foreground)),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.request, required this.assignee, required this.onAssign});

  final HelpRequest request;

  /// Quién va, si coordinación ya mandó a alguien.
  final String? assignee;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final String what = request.helpKindLabel ?? 'Pidió ayuda';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(_icon(request.helpKind), size: 20, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$what · ${request.location}', style: AppTextStyles.itemTitle),
                Text(
                  '${request.fullName} · ${request.grade} · ${Fmt.ago(request.reportedAt)}',
                  style: AppTextStyles.caption,
                ),
                if (request.helpDetails != null && request.helpDetails!.isNotEmpty)
                  Text('«${request.helpDetails}»', style: AppTextStyles.caption),
                // Solo coordinación lo recibe: es lo que necesita un brigadista.
                if (request.medicalInfo != null && request.medicalInfo!.isNotEmpty)
                  Text(
                    'Información médica: ${request.medicalInfo}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.brandDark, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Ya asignado se puede reasignar: quien iba puede estar atendiendo a otro.
          if (assignee != null)
            ActionChip(
              key: Key('ayuda-asignada-${request.personId}'),
              onPressed: onAssign,
              backgroundColor: AppColors.successSoft,
              side: BorderSide.none,
              label: Text(
                'Va ${PersonName.firstName(assignee!)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.success),
              ),
            )
          else
            FilledButton(
              key: Key('ayuda-asignar-${request.personId}'),
              onPressed: onAssign,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Asignar', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  static IconData _icon(String? kind) => switch (kind) {
        'herido' => Icons.medical_services_outlined,
        'atrapado' => Icons.door_front_door_outlined,
        'otra_persona' => Icons.person_search_outlined,
        _ => Icons.error_outline,
      };
}

/// Una lista de grupo que llegó de un docente.
class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.roster});

  final DeliveredRoster roster;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${roster.grade} · ${PersonName.short(roster.teacher)}', style: AppTextStyles.itemTitle),
                Text(
                  '${roster.safe} a salvo · ${roster.needHelp} con ayuda · ${roster.pending} sin respuesta',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Text(Fmt.hour(roster.submittedAt), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
