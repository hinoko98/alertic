import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/hazard.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../../alerts/domain/protocol.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';
import '../panel_layout.dart';
import '../widgets/protocol_editor_sheets.dart';

/// Protocolos y puntos de encuentro que el colegio publica.
///
/// Lo que se edita aquí es exactamente lo que la app guarda en cada celular
/// para consultarlo sin señal, y lo que dice una alerta roja cuando suena. No es
/// un documento suelto: es el contenido que va a leer un estudiante con el
/// edificio moviéndose.
class ProtocolsTab extends StatefulWidget {
  const ProtocolsTab({super.key});

  @override
  State<ProtocolsTab> createState() => _ProtocolsTabState();
}

class _ProtocolsTabState extends State<ProtocolsTab> {
  List<Protocol> _protocols = <Protocol>[];
  List<MeetingPoint> _points = <MeetingPoint>[];
  bool _loading = true;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final repository = AppScope.of(context).panelRepository!;
      final List<Protocol> protocols = await repository.loadProtocols();
      final List<MeetingPoint> points = await repository.loadMeetingPoints();
      if (mounted) {
        setState(() {
          _protocols = protocols;
          _points = points;
          _failed = false;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'protocolos');
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
    final bool compact = PanelLayout.isCompact(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: PanelLayout.headerPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'PROTOCOLOS',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Lo que se publica aquí queda guardado en cada celular y se lee '
                'sin conexión.',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.brand),
                )
              : _failed
                  ? Padding(
                      padding: EdgeInsets.all(PanelLayout.gutter(context)),
                      child: Text(
                        'No pudimos cargar los protocolos. Revisa que el servidor '
                        'esté encendido.',
                        style: AppTextStyles.body,
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: PanelLayout.gutter(context),
                        vertical: AppSpacing.sm,
                      ),
                      children: <Widget>[
                        // Dos protocolos lado a lado en el computador; uno debajo
                        // del otro en el celular, donde una tarjeta de media
                        // pantalla dejaría los pasos en una columna de tres
                        // palabras.
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: compact ? 1 : 2,
                          crossAxisSpacing: AppSpacing.lg,
                          mainAxisSpacing: AppSpacing.lg,
                          childAspectRatio: compact ? 1.25 : 1.6,
                          children: <Widget>[
                            for (final Protocol protocol in _protocols)
                              _ProtocolCard(
                                protocol: protocol,
                                onEdit: () => showProtocolEditor(
                                  context,
                                  protocol: protocol,
                                  onChanged: _load,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _MeetingPointsSection(points: _points, onChanged: _load),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({required this.protocol, required this.onEdit});

  final Protocol protocol;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  hazardIcon(protocol.hazard),
                  size: 20,
                  color: AppColors.brand,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    protocol.hazard.label,
                    style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                  child: const Text(
                    'EDITAR',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Section(title: 'Antes', steps: protocol.beforeSteps),
                    _Section(title: 'Durante', steps: protocol.duringSteps),
                    _Section(title: 'Después', steps: protocol.afterSteps),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title.toUpperCase(), style: AppTextStyles.eyebrow),
          for (final String step in steps)
            Text('· $step', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Los puntos de encuentro del colegio, con crear, editar y quitar.
///
/// Es de donde sale el punto de cada estudiante y a dónde manda una alerta roja:
/// por eso son del colegio y no están escritos en la app.
class _MeetingPointsSection extends StatelessWidget {
  const _MeetingPointsSection({required this.points, required this.onChanged});

  final List<MeetingPoint> points;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text('PUNTOS DE ENCUENTRO', style: AppTextStyles.eyebrow),
            ),
            TextButton(
              onPressed: () => showMeetingPointEditor(context, onChanged: onChanged),
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: const Text(
                '+ NUEVO PUNTO',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'A dónde va cada estudiante en una evacuación. Una alerta roja sin punto '
          'escogido usa el primer punto general.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: AppColors.border)),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < points.length; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1),
                _PointRow(
                  point: points[i],
                  onTap: () => showMeetingPointEditor(
                    context,
                    point: points[i],
                    onChanged: onChanged,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.point, required this.onTap});

  final MeetingPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Hazard? only = point.onlyFor;
    final String detail = <String>[
      point.routeHint,
      if (point.distanceMeters > 0) '${point.distanceMeters} m',
      if (point.walkMinutes > 0) '${point.walkMinutes} min',
      if (only != null) 'Solo ${only.label.toLowerCase()}',
    ].where((String part) => part.isNotEmpty).join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 44,
              child: Text(
                point.code,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(point.name, style: AppTextStyles.itemTitle),
                  if (detail.isNotEmpty)
                    Text(detail, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, size: 16, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
