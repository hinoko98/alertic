import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/design/pill.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../core/location/geo.dart';
import '../../../../core/location/location_tracker.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../widgets/live_route_map.dart';
import '../widgets/location_notice.dart';
import 'guided_route_screen.dart';

/// Pantalla 08: el mapa de evacuación.
///
/// **Todo lo que dice viene del colegio**: el punto de la persona, de su perfil, y
/// los demás, de los que coordinación definió en el panel. No hay un plano
/// dibujado con bloques y salones inventados: un plano falso, en una evacuación,
/// es peor que ninguno. Lo que sí se dibuja es el recorrido con los dos extremos
/// que se conocen —el salón y el punto—; cuando el colegio tenga un plano real,
/// se agrega aquí.
class EvacuationMapScreen extends StatefulWidget {
  const EvacuationMapScreen({required this.student, super.key});

  final StudentEnrollment student;

  @override
  State<EvacuationMapScreen> createState() => _EvacuationMapScreenState();
}

class _EvacuationMapScreenState extends State<EvacuationMapScreen> {
  List<MeetingPoint> _others = <MeetingPoint>[];
  bool _loading = true;
  bool _failed = false;
  bool _started = false;

  /// El punto hacia el que se mira la ruta. Por omisión, el asignado.
  late MeetingPoint _selected = widget.student.meetingPoint;
  LocationTracker? _tracker;

  @override
  void dispose() {
    _tracker?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
      // El GPS se enciende al abrir el mapa y se apaga al salir.
      _tracker = LocationTracker(AppScope.of(context).locationService)..start();
    }
  }

  Future<void> _load() async {
    try {
      final List<MeetingPoint> all =
          await AppScope.of(context).alertRepository.loadMeetingPoints();
      if (mounted) {
        setState(() {
          _others = all
              .where((MeetingPoint p) => p.code != widget.student.meetingPoint.code)
              .toList();
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'puntos de encuentro');
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentEnrollment student = widget.student;
    final MeetingPoint mine = student.meetingPoint;
    final LocationTracker tracker = _tracker!;

    return ListenableBuilder(
      listenable: tracker,
      builder: (BuildContext context, Widget? _) {
        final MeetingPoint selected = _selected;
        final GeoPoint? targetPoint = selected.location;
        final GeoPoint? me = tracker.fix?.point;
        final double? meters =
            me != null && targetPoint != null ? Geo.distance(me, targetPoint) : null;
        final List<MeetingPoint> choices = <MeetingPoint>[mine, ..._others]
            .where((MeetingPoint p) => p.location != null)
            .toList();

        return AppPage(
          title: 'Mapa de evacuación',
          subtitle: 'Rutas y puntos de encuentro',
          bottom: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.sm,
              AppSpacing.screenGutter,
              AppSpacing.md,
            ),
            child: PrimaryButton(
              key: const Key('iniciar-ruta'),
              label: 'Iniciar ruta en vivo',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      GuidedRouteScreen(student: student, target: selected),
                ),
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  LiveStatusPill(tracker: tracker),
                  Pill(student.classroom),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              LocationNotice(tracker: tracker),
              if (targetPoint != null)
                LiveRouteMap(
                  key: const Key('mapa-en-vivo'),
                  target: MapMarker(point: targetPoint, label: selected.code),
                  me: me,
                  accuracy: tracker.fix?.accuracy,
                  heading: tracker.fix?.heading,
                  trail: tracker.trail,
                  others: <MapMarker>[
                    for (final MeetingPoint p in choices)
                      if (p.code != selected.code)
                        MapMarker(point: p.location!, label: p.code),
                  ],
                )
              else ...<Widget>[
                _RouteDiagram(student: student),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'El colegio todavía no ubicó este punto en el mapa, así que no se '
                  'puede mostrar la ruta en vivo. Sigue las indicaciones escritas.',
                  key: Key('punto-sin-ubicar'),
                  style: AppTextStyles.caption,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (meters != null) ...<Widget>[
                AppCard(
                  key: const Key('distancia-al-punto'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      const IconBubble(icon: Icons.navigation_outlined, size: 38),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Estás a ${Geo.distanceLabel(meters)} del punto ${selected.code}',
                              style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                            ),
                            Text(
                              '${Geo.walkLabel(meters)} caminando · hacia el '
                              '${Geo.compassWord(Geo.bearing(me!, targetPoint!))}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (choices.length > 1) ...<Widget>[
                const SectionLabel('Elige tu punto'),
                Row(
                  children: <Widget>[
                    for (final MeetingPoint p in choices)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: _PointChoice(
                            point: p,
                            recommended: p.code == mine.code,
                            selected: p.code == selected.code,
                            distance: me == null ? null : Geo.distance(me, p.location!),
                            onTap: () => setState(() => _selected = p),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    const IconBubble.success(icon: Icons.location_on_outlined, size: 38),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Salón → ${mine.code} · ${mine.name}',
                            style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            <String>[
                              if (mine.distanceMeters > 0) '${mine.distanceMeters} m',
                              if (mine.walkMinutes > 0) 'unos ${mine.walkMinutes} min caminando',
                              if (mine.routeHint.isNotEmpty) mine.routeHint,
                            ].join(' · '),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionLabel('Otros puntos del colegio'),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
                )
              else if (_failed)
                const Text(
                  'No pudimos traer los demás puntos. Tu punto es el de arriba.',
                  style: AppTextStyles.caption,
                )
              else if (_others.isEmpty)
                const Text(
                  'El colegio no definió otros puntos de encuentro.',
                  style: AppTextStyles.caption,
                )
              else
                for (final MeetingPoint point in _others) ...<Widget>[
                  _OtherPoint(point: point),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        );
      },
    );
  }
}

/// Un punto entre los que se pueden escoger: su código, su nombre y a cuánto está.
class _PointChoice extends StatelessWidget {
  const _PointChoice({
    required this.point,
    required this.recommended,
    required this.selected,
    required this.onTap,
    this.distance,
  });

  final MeetingPoint point;
  final bool recommended;
  final bool selected;
  final double? distance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brandSoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        side: BorderSide(color: selected ? AppColors.brand : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('punto-${point.code}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Punto ${point.code} · ${point.name}',
                style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                distance == null
                    ? point.summary
                    : '${Geo.distanceLabel(distance!)} · ${Geo.walkLabel(distance!)}',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              if (recommended)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Pill('Recomendado', tone: PillTone.success),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El recorrido: de tu salón al punto. Solo dibuja lo que el colegio ya dijo.
class _RouteDiagram extends StatelessWidget {
  const _RouteDiagram({required this.student});

  final StudentEnrollment student;

  @override
  Widget build(BuildContext context) {
    final MeetingPoint point = student.meetingPoint;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          _Stop(
            icon: Icons.circle,
            color: AppColors.brand,
            title: 'Tú · ${student.grade}',
            subtitle: student.classroom,
            filled: false,
          ),
          const _DashedConnector(),
          _Stop(
            icon: Icons.check,
            color: AppColors.success,
            title: 'Punto ${point.code} · ${point.name}',
            subtitle: point.summary,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.filled,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: filled ? AppColors.successSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: color, width: filled ? 1.5 : 1),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: filled ? 16 : 8, color: AppColors.onBrand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 13)),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedConnector extends StatelessWidget {
  const _DashedConnector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < 4; i++)
            Container(
              width: 2.5,
              height: 6,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: AppColors.brand,
            ),
        ],
      ),
    );
  }
}

/// Otro punto del colegio: su código, su nombre y cómo llegar.
class _OtherPoint extends StatelessWidget {
  const _OtherPoint({required this.point});

  final MeetingPoint point;

  @override
  Widget build(BuildContext context) {
    final Hazard? only = point.onlyFor;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            alignment: Alignment.center,
            child: Text(
              point.code,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.onBrand,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(point.name, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                if (point.routeHint.isNotEmpty)
                  Text(point.routeHint, style: AppTextStyles.caption),
                if (only != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Pill('Solo ${only.label.toLowerCase()}', tone: PillTone.warning),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
