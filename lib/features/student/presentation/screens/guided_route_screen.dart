import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/location/geo.dart';
import '../../../../core/location/location_tracker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../help/presentation/help_screen.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../risks/domain/risk_repository.dart';
import '../../domain/route_steps.dart';
import '../widgets/live_route_map.dart';
import '../widgets/location_notice.dart';
import 'arrived_screen.dart';

/// Pantalla 09: la ruta guiada.
///
/// Paso a paso, pensada para leerse caminando: la instrucción de ahora en grande
/// y debajo todos los pasos con el progreso. Los pasos salen de lo que el colegio
/// escribió para el punto de encuentro (ver [routeSteps]).
///
/// Si el camino está bloqueado, un toque avisa a coordinación como un reporte de
/// riesgo: es información que el comité necesita y que el resto de la gente va a
/// encontrar igual de cerrada.
class GuidedRouteScreen extends StatefulWidget {
  const GuidedRouteScreen({
    required this.student,
    this.target,
    this.onResponded,
    super.key,
  });

  final StudentEnrollment student;

  /// El punto hacia el que se guía. Por omisión, el asignado al estudiante.
  final MeetingPoint? target;

  /// Se llama cuando la persona confirma que está a salvo, para que quien abrió
  /// la ruta —la pantalla de alerta— deje de pedirle que responda.
  final VoidCallback? onResponded;

  @override
  State<GuidedRouteScreen> createState() => _GuidedRouteScreenState();
}

class _GuidedRouteScreenState extends State<GuidedRouteScreen> {
  MeetingPoint get _point => widget.target ?? widget.student.meetingPoint;

  late final List<String> _steps = routeSteps(
    classroom: widget.student.classroom,
    point: _point,
    homeroomTeacher: widget.student.homeroomTeacher,
  );

  int _current = 0;
  Alert? _alert;
  bool _reportingBlock = false;
  bool _started = false;
  bool _autoArrived = false;
  LocationTracker? _tracker;

  /// A cuántos metros del punto se da por llegado. Debe ser mayor que el error
  /// típico del GPS, o nunca se daría.
  static const double _arrivalRadius = 15;

  /// Distancia al punto cuando se empezó, para medir el avance de la barra.
  double? _startDistance;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadAlert();
      // El GPS se enciende al abrir la ruta y se apaga al salir.
      _tracker = LocationTracker(AppScope.of(context).locationService)
        ..addListener(_onLocation)
        ..start();
    }
  }

  @override
  void dispose() {
    _tracker?.removeListener(_onLocation);
    _tracker?.dispose();
    super.dispose();
  }

  /// Cada ubicación nueva: fija de dónde se partió y, al llegar, avanza solo.
  void _onLocation() {
    final GeoPoint? me = _tracker?.fix?.point;
    final GeoPoint? target = _point.location;
    if (me == null || target == null || !mounted) return;

    final double meters = Geo.distance(me, target);
    _startDistance ??= meters;

    if (!_autoArrived && meters <= _arrivalRadius) {
      _autoArrived = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _arrived();
      });
    }
  }

  void _help() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            HelpScreen(alert: _alert, classroom: widget.student.classroom),
      ),
    );
  }

  /// Para decir de qué alerta es la ruta. Sin alerta (un repaso) la ruta sirve
  /// igual.
  Future<void> _loadAlert() async {
    try {
      final Alert? alert = await AppScope.of(context)
          .alertRepository
          .watchActiveAlert()
          .first
          .timeout(const Duration(seconds: 3));
      if (mounted) setState(() => _alert = alert);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'alerta para la ruta');
    }
  }

  Future<void> _blocked() async {
    final RiskRepository? risks = AppScope.of(context).riskRepository;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (risks == null || _reportingBlock) return;

    setState(() => _reportingBlock = true);
    try {
      await risks.report(
        kind: RiskKind.otro,
        place: 'Ruta bloqueada hacia el punto ${_point.code}',
        details: 'Desde ${widget.student.classroom}',
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Avisamos a coordinación. Sigue las indicaciones de tu docente y '
            'busca otro camino al punto.',
          ),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'ruta bloqueada');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos avisar. Sigue las indicaciones de tu docente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _reportingBlock = false);
    }
  }

  void _arrived() {
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ArrivedScreen(
          student: widget.student,
          point: _point,
          alert: _alert,
          onResponded: widget.onResponded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool last = _current >= _steps.length - 1;
    final String hazard = _alert == null ? 'Ruta' : _alert!.hazard.label;
    final LocationTracker tracker = _tracker!;

    return ListenableBuilder(
      listenable: tracker,
      builder: (BuildContext context, Widget? _) =>
          _scaffold(context, tracker, last: last, hazard: hazard),
    );
  }

  Widget _scaffold(
    BuildContext context,
    LocationTracker tracker, {
    required bool last,
    required String hazard,
  }) {
    final GeoPoint? targetPoint = _point.location;
    final GeoPoint? me = tracker.fix?.point;
    final bool live = tracker.isLive && targetPoint != null && me != null;
    final double? meters = live ? Geo.distance(me, targetPoint) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: <Widget>[
          Container(
            color: AppColors.ink,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.sm,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        InkResponse(
                          onTap: () => Navigator.of(context).maybePop(),
                          radius: 22,
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: AppColors.onBrand,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_cap(hazard)} · evacuación',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onBrand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Paso ${_current + 1} de ${_steps.length}',
                          key: const Key('paso-actual'),
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            last ? Icons.flag_outlined : Icons.arrow_upward,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _steps[_current],
                            key: const Key('instruccion-actual'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                              color: AppColors.onBrand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (live) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _LiveDirection(
                        meters: meters!,
                        bearing: Geo.bearing(me, targetPoint),
                        heading: tracker.fix?.heading,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              children: <Widget>[
                LocationNotice(tracker: tracker),
                if (targetPoint != null) ...<Widget>[
                  LiveRouteMap(
                    key: const Key('mapa-ruta-en-vivo'),
                    target: MapMarker(point: targetPoint, label: _point.code),
                    me: me,
                    accuracy: tracker.fix?.accuracy,
                    heading: tracker.fix?.heading,
                    trail: tracker.trail,
                    followMe: true,
                    height: 280,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (live)
                    _Progress(
                      meters: meters!,
                      startMeters: _startDistance ?? meters,
                      pointLabel: '${_point.code} · ${_point.name}',
                    ),
                  if (live) const SizedBox(height: AppSpacing.md),
                ] else ...<Widget>[
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'El colegio todavía no ubicó este punto en el mapa: sigue los '
                      'pasos escritos.',
                      key: Key('punto-sin-ubicar'),
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < _steps.length; i++)
                        _StepRow(
                          index: i,
                          text: _steps[i],
                          state: i < _current
                              ? _StepState.done
                              : i == _current
                                  ? _StepState.current
                                  : _StepState.pending,
                          onTap: () => setState(() => _current = i),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
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
                children: <Widget>[
                  if (!last)
                    PrimaryButton(
                      key: const Key('siguiente-paso'),
                      label: 'Listo, siguiente paso',
                      background: AppColors.ink,
                      onPressed: () => setState(() => _current++),
                    ),
                  if (!last) const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    key: const Key('llegue-al-punto'),
                    label: 'Llegué al punto de encuentro',
                    background: AppColors.success,
                    icon: null,
                    onPressed: _arrived,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: SecondaryButton(
                          key: const Key('ruta-bloqueada'),
                          label: 'Ruta bloqueada',
                          onPressed: _reportingBlock ? null : _blocked,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SecondaryButton(
                          key: const Key('ruta-necesito-ayuda'),
                          label: 'Necesito ayuda',
                          onPressed: _help,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _cap(String text) =>
      text.isEmpty ? text : '${text[0]}${text.substring(1).toLowerCase()}';
}

/// La dirección en vivo, en el encabezado: una flecha que apunta hacia dónde ir y
/// cuánto falta.
///
/// Si la persona va caminando, la flecha es relativa a hacia dónde mira (arriba
/// es «sigue de frente»). Si está quieta el GPS no sabe hacia dónde mira, y la
/// flecha apunta al rumbo real con el norte arriba, que también se dice en palabras.
class _LiveDirection extends StatelessWidget {
  const _LiveDirection({required this.meters, required this.bearing, this.heading});

  final double meters;
  final double bearing;
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final double turn = heading == null ? bearing : Geo.turnTo(heading!, bearing);
    final String words = Geo.compassWord(bearing);

    return Container(
      key: const Key('direccion-en-vivo'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        children: <Widget>[
          Transform.rotate(
            angle: turn * 3.141592653589793 / 180,
            child: const Icon(Icons.navigation, size: 30, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              meters <= 15
                  ? 'Ya estás en el punto de encuentro'
                  : 'Sigue hacia el $words · ${Geo.distanceLabel(meters)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuántos metros faltan, cuánto se tarda y el avance.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.meters,
    required this.startMeters,
    required this.pointLabel,
  });

  final double meters;
  final double startMeters;
  final String pointLabel;

  @override
  Widget build(BuildContext context) {
    final double progress =
        startMeters <= 0 ? 1 : (1 - meters / startMeters).clamp(0.0, 1.0);

    return AppCard(
      key: const Key('avance-ruta'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      Geo.distanceLabel(meters),
                      key: const Key('metros-restantes'),
                      style: AppTextStyles.screenTitle.copyWith(fontSize: 24),
                    ),
                    Text('hasta el punto $pointLabel', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    Geo.walkLabel(meters),
                    style: AppTextStyles.itemTitle.copyWith(
                      fontSize: 18,
                      color: AppColors.success,
                    ),
                  ),
                  const Text('caminando', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, current, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String text;
  final _StepState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Widget child) = switch (state) {
      _StepState.done => (
          AppColors.success,
          const Icon(Icons.check, size: 14, color: AppColors.onBrand),
        ),
      _StepState.current => (
          AppColors.brand,
          Text(
            '${index + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.onBrand),
          ),
        ),
      _StepState.pending => (
          AppColors.surfaceAlt,
          Text(
            '${index + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkMuted),
          ),
        ),
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: child,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  fontWeight: state == _StepState.current ? FontWeight.w800 : FontWeight.w400,
                  color: state == _StepState.pending ? AppColors.inkMuted : AppColors.ink,
                  decoration: state == _StepState.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
