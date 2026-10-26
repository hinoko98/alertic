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
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/format.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/live_updates.dart';
import '../../../drills/domain/drill_repository.dart';
import '../../../drills/presentation/drills_screen.dart';
import '../../../incidents/domain/incident.dart';
import '../../../risks/domain/risk_repository.dart';
import '../../../risks/presentation/risk_inbox_screen.dart';
import '../../../teacher/presentation/screens/new_alert_screen.dart';
import '../../domain/panel_repository.dart';
import '../screens/history_tab.dart';
import '../screens/protocols_tab.dart';
import 'admin_codes_screen.dart';
import 'admin_subpage.dart';
import 'admin_tracking_screen.dart';

/// Pantalla 50: el panel del colegio en el celular del administrador.
///
/// Arriba, lo único urgente: emitir una alerta o, si ya hay una, seguirla. Debajo,
/// el tamaño del colegio, lo que la comunidad reportó y la gestión de siempre. El
/// tablero completo sigue a un toque: aquí se resume, no se reemplaza.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  CommunityStats? _stats;
  List<RiskReport> _risks = const <RiskReport>[];
  Drill? _nextDrill;
  int? _meetingPoints;
  Alert? _active;
  int _openIncidents = 0;

  StreamSubscription<Alert?>? _alerts;
  StreamSubscription<LiveChange>? _live;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final AppScope scope = AppScope.of(context);
    _alerts = scope.alertRepository.watchActiveAlert().listen((Alert? alert) {
      if (mounted) setState(() => _active = alert);
    });
    // Un reporte de emergencia o de riesgo nuevo cambia lo que hay que mirar
    // primero: el panel se pone al día sin que coordinación tenga que bajar la lista.
    _live = scope.liveUpdates.changes
        .where((LiveChange c) => c == LiveChange.incidents || c == LiveChange.riskReports)
        .listen((_) => unawaited(_load()));
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_alerts?.cancel());
    unawaited(_live?.cancel());
    super.dispose();
  }

  /// Cada bloque carga por su cuenta: si los reportes fallan, las cifras igual
  /// se ven. Un panel en blanco porque falló una sola consulta no le sirve a nadie.
  Future<void> _load() async {
    final AppScope scope = AppScope.of(context);
    final PanelRepository? panel = scope.panelRepository;

    Future<void> guard(String what, Future<void> Function() load) async {
      try {
        await load();
      } catch (error, stack) {
        ErrorReporter.report(error, stack, context: what);
      }
    }

    await Future.wait(<Future<void>>[
      if (panel != null) ...<Future<void>>[
        guard('cifras del panel', () async {
          final CommunityStats stats = await panel.loadStats();
          if (mounted) setState(() => _stats = stats);
        }),
        guard('puntos de encuentro', () async {
          final int points = (await panel.loadMeetingPoints()).length;
          if (mounted) setState(() => _meetingPoints = points);
        }),
      ],
      if (scope.riskRepository != null)
        guard('reportes de riesgo', () async {
          final List<RiskReport> risks = await scope.riskRepository!.loadInbox();
          if (mounted) setState(() => _risks = risks);
        }),
      if (scope.incidentRepository != null)
        guard('reportes de emergencia', () async {
          final List<Incident> open = await scope.incidentRepository!.loadOpen();
          if (mounted) setState(() => _openIncidents = open.length);
        }),
      if (scope.drillRepository != null)
        guard('próximo simulacro', () async {
          final DrillOverview drills = await scope.drillRepository!.load();
          if (mounted) setState(() => _nextDrill = drills.next);
        }),
    ]);
  }

  /// El tablero es una pestaña: se cambia a ella en vez de abrir otra copia encima.
  void _openBoard() => ShellScope.maybeOf(context)?.openTab('Tablero');

  Future<void> _open(WidgetBuilder builder) async {
    await pushInShell<void>(context, builder);
    // Al volver de emitir o de revisar un reporte, las cifras pueden haber cambiado.
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final CommunityStats? stats = _stats;
    final List<RiskReport> open = _risks
        .where((RiskReport r) => r.status == RiskStatus.nuevo || r.status == RiskStatus.enRevision)
        .toList();
    final int fresh = _risks.where((RiskReport r) => r.status == RiskStatus.nuevo).length;
    final Alert? active = _active;

    return AppPage(
      title: 'Panel del colegio',
      subtitle: ShellScope.maybeOf(context)?.schoolName,
      showHelp: false,
      actions: const <Widget>[_AdminChip()],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.md,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          children: <Widget>[
            if (active != null)
              _ActiveAlertCard(
                alert: active,
                onTap: () => _open((_) => AdminTrackingScreen(alert: active)),
              )
            else
              _IssueButton(
                onPressed: () => _open((_) => const NewAlertScreen(groups: <String>[])),
              ),
            if (_openIncidents > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _IncidentsCard(count: _openIncidents, onTap: _openBoard),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              key: const Key('admin-cifras'),
              children: <Widget>[
                Expanded(child: _Figure(value: _count(stats?.byRole['estudiante']), label: 'Estudiantes')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Figure(
                    value: _count(stats == null
                        ? null
                        : (stats.byRole['docente'] ?? 0) + (stats.byRole['administrador'] ?? 0)),
                    label: 'Docentes y personal',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _Figure(
                    value: '$fresh',
                    label: 'Reportes nuevos',
                    color: fresh > 0 ? AppColors.brand : AppColors.ink,
                  ),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                const Expanded(child: SectionLabel('Reportes por revisar')),
                TextButton(
                  onPressed: () => _open((_) => const RiskInboxScreen(canManage: true)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.brandDark),
                  child: const Text('Ver todos', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (open.isEmpty)
              const AppCard(
                key: Key('admin-sin-reportes'),
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Nada por revisar. La comunidad no ha reportado riesgos nuevos.',
                    style: AppTextStyles.caption),
              )
            else
              AppCard(
                key: const Key('admin-reportes'),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < open.length && i < 3; i++) ...<Widget>[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      _RiskRow(report: open[i]),
                    ],
                  ],
                ),
              ),
            const SectionLabel('Gestión'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.45,
              children: <Widget>[
                _Tile(
                  key: const Key('admin-codigos'),
                  icon: Icons.badge_outlined,
                  title: 'Generar códigos',
                  subtitle: _codesSubtitle(stats),
                  onTap: () => _open((_) => const AdminCodesScreen()),
                ),
                _Tile(
                  icon: Icons.map_outlined,
                  title: 'Rutas y puntos',
                  subtitle: _meetingPoints == null
                      ? 'Puntos de encuentro'
                      : _meetingPoints == 1
                          ? '1 punto activo'
                          : '$_meetingPoints puntos activos',
                  onTap: () => _open((_) => const AdminSubpage(child: ProtocolsTab())),
                ),
                _Tile(
                  icon: Icons.event_outlined,
                  title: 'Simulacros',
                  subtitle: _nextDrill == null
                      ? 'Ninguno programado'
                      : 'Próximo: ${Fmt.dayMonthShort(_nextDrill!.scheduledAt)}',
                  onTap: () => _open((_) => const DrillsScreen(canSchedule: true)),
                ),
                _Tile(
                  icon: Icons.bar_chart,
                  title: 'Informes',
                  subtitle: 'Alertas anteriores',
                  onTap: () => _open((_) => const AdminSubpage(child: HistoryTab())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _count(int? value) => value == null ? '—' : _thousands(value);

  /// `1.248`, como se escriben los números en Colombia.
  static String _thousands(int value) {
    final String digits = '$value';
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    return out.toString();
  }

  static String _codesSubtitle(CommunityStats? stats) {
    if (stats == null) return 'Por persona o por curso';
    return stats.pendingCodes == 1 ? '1 código sin usar' : '${stats.pendingCodes} códigos sin usar';
  }
}

class _AdminChip extends StatelessWidget {
  const _AdminChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
      child: const Text(
        'Admin',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.onBrand),
      ),
    );
  }
}

class _IssueButton extends StatelessWidget {
  const _IssueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: FilledButton.icon(
        key: const Key('admin-emitir-alerta'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onBrand,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        icon: const Icon(Icons.warning_amber_rounded, size: 24),
        label: const Text('Emitir alerta'),
      ),
    );
  }
}

/// Con una alerta en curso, el botón de emitir cede su lugar al seguimiento.
class _ActiveAlertCard extends StatelessWidget {
  const _ActiveAlertCard({required this.alert, required this.onTap});

  final Alert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('admin-alerta-en-curso'),
      onTap: onTap,
      color: AppColors.brand,
      borderColor: AppColors.brand,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          const Icon(Icons.campaign_outlined, color: AppColors.onBrand, size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Alerta en curso · ${alert.title}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onBrand),
                ),
                Text(
                  'Desde ${alert.issuedAtLabel} · Ver seguimiento en vivo',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.onBrand),
        ],
      ),
    );
  }
}

/// Reportes de emergencia de la comunidad sin atender: van antes que todo lo demás.
class _IncidentsCard extends StatelessWidget {
  const _IncidentsCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('admin-emergencias-abiertas'),
      onTap: onTap,
      color: AppColors.brandSoft,
      borderColor: AppColors.brand,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          const Icon(Icons.local_fire_department_outlined, color: AppColors.brand),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              count == 1
                  ? '1 reporte de emergencia sin atender'
                  : '$count reportes de emergencia sin atender',
              style: AppTextStyles.itemTitle.copyWith(color: AppColors.brandDark),
            ),
          ),
          const Text('Ver', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.brand)),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.color = AppColors.ink});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.report});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    final bool fresh = report.status == RiskStatus.nuevo;
    final String who = <String>[
      if (report.reporterRole != null) _role(report.reporterRole!),
      if (report.reporterGrade != null) report.reporterGrade!,
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          IconBubble(icon: Icons.warning_amber_outlined, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${report.kind.label} · ${report.place}', style: AppTextStyles.itemTitle),
                Text(
                  <String>[if (who.isNotEmpty) who, Fmt.ago(report.createdAt)].join(' · '),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          _StatusChip(label: report.status.label, urgent: fresh),
        ],
      ),
    );
  }

  static String _role(String wire) => switch (wire) {
        'estudiante' => 'Estudiante',
        'docente' => 'Docente',
        'administrador' => 'Coordinación',
        'acudiente' => 'Acudiente',
        _ => wire,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.urgent});

  final String label;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: urgent ? AppColors.brandSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: urgent ? AppColors.brand : AppColors.warning,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconBubble.neutral(icon: icon, size: 36),
          const Spacer(),
          Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
          Text(subtitle, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
