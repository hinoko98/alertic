import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../onboarding/domain/enrollment.dart';

/// Pantalla 12: la ruta al punto de encuentro.
///
/// **Todo lo que dice viene del colegio**: el punto de la persona, de su perfil, y
/// los demás, de los que coordinación definió en el panel. No hay un plano dibujado
/// con bloques y salones inventados: un plano falso, en una evacuación, es peor
/// que ninguno. Cuando el colegio tenga un plano real, se agrega aquí.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
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
    final MeetingPoint mine = widget.student.meetingPoint;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.md,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          children: <Widget>[
            Text(
              'RUTA DE EVACUACIÓN',
              style: AppTextStyles.eyebrow.copyWith(color: AppColors.brand),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(mine.summary, style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.lg),
            _PointCard(
              point: mine,
              background: AppColors.brand,
              foreground: AppColors.onBrand,
              big: true,
              caption: 'TU PUNTO DE ENCUENTRO',
            ),
            const SizedBox(height: AppSpacing.xl),
            const Text('OTROS PUNTOS DEL COLEGIO', style: AppTextStyles.eyebrow),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
              )
            else if (_failed)
              Text(
                'No pudimos traer los demás puntos. Tu punto es el de arriba.',
                style: AppTextStyles.caption,
              )
            else if (_others.isEmpty)
              Text(
                'El colegio no definió otros puntos de encuentro.',
                style: AppTextStyles.caption,
              )
            else
              for (final MeetingPoint point in _others) ...<Widget>[
                _PointCard(
                  point: point,
                  background: AppColors.ink,
                  foreground: AppColors.onBrand,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

/// Un punto de encuentro: su código, su nombre y cómo llegar.
class _PointCard extends StatelessWidget {
  const _PointCard({
    required this.point,
    required this.background,
    required this.foreground,
    this.big = false,
    this.caption,
  });

  final MeetingPoint point;
  final Color background;
  final Color foreground;
  final bool big;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final Hazard? only = point.onlyFor;

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (caption != null) ...<Widget>[
            Text(
              caption!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                point.code,
                style: TextStyle(
                  fontSize: big ? 44 : 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: foreground,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  point.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: big ? 14 : 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          if (point.routeHint.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              point.routeHint,
              style: TextStyle(fontSize: 13, height: 1.35, color: foreground),
            ),
          ],
          if (only != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'SOLO ${only.label}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
