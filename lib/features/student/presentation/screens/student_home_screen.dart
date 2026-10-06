import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/shell_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/design/status_banner.dart';
import '../../../../shared/format.dart';
import '../../../account/presentation/alerts_feed_screen.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/alert_level.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';
import '../../../drills/domain/drill_repository.dart';
import '../../../drills/presentation/drills_screen.dart';
import '../../../help/presentation/help_screen.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../onboarding/domain/person_name.dart';

/// Pantalla 06: el inicio del estudiante.
///
/// En calma responde una pregunta: ¿pasa algo? Un banner verde dice que no, y
/// debajo están los accesos que se usan antes de una emergencia. Con una alerta
/// activa, esa alerta manda sobre todo lo demás (la pone encima el `AlertGate`).
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({required this.student, super.key});

  final StudentEnrollment student;

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  Drill? _nextDrill;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadDrill();
    }
  }

  Future<void> _loadDrill() async {
    final DrillRepository? repository = AppScope.of(context).drillRepository;
    if (repository == null) return;
    try {
      final DrillOverview overview = await repository.load();
      if (mounted) setState(() => _nextDrill = overview.next);
    } catch (error, stack) {
      // El próximo simulacro es un extra: sin él, el inicio sirve igual.
      ErrorReporter.report(error, stack, context: 'próximo simulacro');
    }
  }

  void _openTab(String label) => ShellScope.maybeOf(context)?.openTab(label);

  void _openDrills() => _push(
        (_) => DrillsScreen(
          meetingPoint: widget.student.meetingPoint.code,
          onReviewRoute: () => _openTab('Mapa'),
        ),
      );

  Future<void> _push(WidgetBuilder builder) => pushInShell<void>(context, builder);

  @override
  Widget build(BuildContext context) {
    final AppScope scope = AppScope.of(context);
    final String? school = ShellScope.maybeOf(context)?.schoolName;
    final StudentEnrollment student = widget.student;

    return AppPage(
      title: 'Hola, ${PersonName.firstName(student.fullName)}',
      subtitle: <String>[?school, student.grade].join(' · '),
      body: StreamBuilder<Alert?>(
        stream: scope.alertRepository.watchActiveAlert(),
        builder: (BuildContext context, AsyncSnapshot<Alert?> snapshot) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            children: <Widget>[
              _SchoolStatus(alert: snapshot.data),
              const SectionLabel('Tu punto de encuentro'),
              _MeetingPointCard(student: student, onTap: () => _openTab('Mapa')),
              const SectionLabel('Accesos rápidos'),
              _QuickGrid(
                tiles: <_Tile>[
                  _Tile(
                    icon: Icons.map_outlined,
                    label: 'Mi ruta de evacuación',
                    onTap: () => _openTab('Mapa'),
                  ),
                  _Tile(
                    icon: Icons.menu_book_outlined,
                    label: 'Qué hacer si…',
                    onTap: () => _openTab('Guías'),
                  ),
                  _Tile(
                    icon: Icons.warning_amber_outlined,
                    label: 'Reportar un riesgo',
                    onTap: () => _openTab('Reportar'),
                  ),
                  _Tile(
                    icon: Icons.event_outlined,
                    label: 'Simulacros',
                    onTap: _openDrills,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_nextDrill != null)
                _NextDrillCard(
                  drill: _nextDrill!,
                  onTap: _openDrills,
                ),
              if (_nextDrill != null) const SizedBox(height: AppSpacing.sm),
              AppCard(
                key: const Key('alertas-y-avisos'),
                onTap: () => _push((_) => const AlertsFeedScreen()),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: const Row(
                  children: <Widget>[
                    IconBubble.neutral(icon: Icons.notifications_none, size: 38),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Alertas y avisos', style: AppTextStyles.itemTitle),
                          Text('Lo que pasó en tu colegio y tus reportes', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.inkMuted),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottom: _HelpBar(
        onTap: () => _push(
          (_) => HelpScreen(
            alert: null,
            classroom: student.classroom,
          ),
        ),
      ),
    );
  }
}

/// El estado del colegio: verde y tranquilo, o la alerta activa.
class _SchoolStatus extends StatelessWidget {
  const _SchoolStatus({required this.alert});

  final Alert? alert;

  @override
  Widget build(BuildContext context) {
    final Alert? active = alert;
    if (active == null) {
      return const StatusBanner(
        key: Key('sin-alertas'),
        icon: Icons.verified_user_outlined,
        title: 'Sin alertas activas',
        subtitle: 'Todo tranquilo en tu colegio',
      );
    }

    return StatusBanner(
      icon: hazardIcon(active.hazard),
      tone: active.level == AlertLevel.roja ? BannerTone.danger : BannerTone.warning,
      title: '${active.title} · ${active.issuedAtLabel}',
      subtitle: active.scope,
    );
  }
}

class _MeetingPointCard extends StatelessWidget {
  const _MeetingPointCard({required this.student, required this.onTap});

  final StudentEnrollment student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            alignment: Alignment.center,
            child: Text(
              student.meetingPoint.code,
              style: const TextStyle(
                fontSize: 14,
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
                Text(
                  student.meetingPoint.name,
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  student.meetingPoint.routeHint,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}

class _Tile {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    final double width =
        (MediaQuery.sizeOf(context).width - AppSpacing.screenGutter * 2 - AppSpacing.sm) / 2;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final _Tile tile in tiles)
          SizedBox(
            width: width,
            child: AppCard(
              onTap: tile.onTap,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                height: 76,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    IconBubble(icon: tile.icon, size: 34),
                    Text(
                      tile.label,
                      style: AppTextStyles.itemTitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NextDrillCard extends StatelessWidget {
  const _NextDrillCard({required this.drill, required this.onTap});

  final Drill drill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('proximo-simulacro'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  Fmt.monthTag(drill.scheduledAt),
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white70),
                ),
                Text(
                  '${drill.scheduledAt.day}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.onBrand),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Próximo simulacro de ${drill.hazard.label.toLowerCase()}',
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                ),
                Text(
                  '${Fmt.weekday(drill.scheduledAt)} · ${Fmt.hour(drill.scheduledAt)} · ${drill.scope}',
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

/// «Necesito ayuda»: siempre a un toque, encima de la barra de navegación.
class _HelpBar extends StatelessWidget {
  const _HelpBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.md,
      ),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          side: const BorderSide(color: AppColors.brand),
        ),
        child: InkWell(
          key: const Key('necesito-ayuda'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          onTap: onTap,
          child: const SizedBox(
            height: AppSpacing.buttonHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.error_outline, size: 18, color: AppColors.brand),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Necesito ayuda',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
