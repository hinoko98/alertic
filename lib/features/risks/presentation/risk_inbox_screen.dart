import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/design/icon_bubble.dart';
import '../../../shared/design/pill.dart';
import '../../../shared/format.dart';
import '../../alerts/domain/live_updates.dart';
import '../domain/risk_repository.dart';

/// Pantalla 53: la bandeja de reportes de riesgo, lo que la comunidad ve (una
/// grieta, un cable suelto) y el colegio debe revisar.
///
/// Se lee por estado, empezando por lo nuevo: lo que nadie ha mirado es lo que
/// puede hacer daño. El reporte abierto muestra su detalle y qué hacer con él;
/// los demás quedan en filas cortas. Coordinación cambia el estado; un docente
/// solo ve los de sus grupos.
class RiskInboxScreen extends StatefulWidget {
  const RiskInboxScreen({this.canManage = false, super.key});

  /// Quién puede cambiar el estado (coordinación).
  final bool canManage;

  @override
  State<RiskInboxScreen> createState() => _RiskInboxScreenState();
}

/// Los tres filtros de la bandeja. «Resueltos» junta atendidos y descartados.
enum _Filter { fresh, reviewing, closed }

class _RiskInboxScreenState extends State<RiskInboxScreen> {
  List<RiskReport>? _reports;
  bool _failed = false;
  StreamSubscription<LiveChange>? _live;

  /// `null` hasta que llegan los reportes: entonces se abre el primer filtro que
  /// tenga algo.
  _Filter? _filter;
  String? _openId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange c) => c == LiveChange.riskReports)
          .listen((_) => _load());
      _load();
    }
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<RiskReport> reports =
          await AppScope.of(context).riskRepository!.loadInbox();
      if (mounted) {
        setState(() {
          _reports = reports;
          _failed = false;
          _filter ??= _firstWithReports(reports);
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'bandeja de riesgos');
      if (mounted) setState(() => _failed = _reports == null);
    }
  }

  Future<void> _setStatus(RiskReport report, RiskStatus status) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).riskRepository!.setStatus(report.id, status);
      await _load();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'estado de riesgo');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo cambiar el estado. Intenta otra vez.')),
      );
    }
  }

  static bool _matches(_Filter filter, RiskStatus status) => switch (filter) {
        _Filter.fresh => status == RiskStatus.nuevo,
        _Filter.reviewing => status == RiskStatus.enRevision,
        _Filter.closed => status == RiskStatus.atendido || status == RiskStatus.descartado,
      };

  static _Filter _firstWithReports(List<RiskReport> reports) {
    for (final _Filter filter in _Filter.values) {
      if (reports.any((RiskReport r) => _matches(filter, r.status))) return filter;
    }
    return _Filter.fresh;
  }

  @override
  Widget build(BuildContext context) {
    final List<RiskReport> reports = _reports ?? const <RiskReport>[];
    final int fresh = reports.where((RiskReport r) => r.status == RiskStatus.nuevo).length;
    final int reviewing = reports.where((RiskReport r) => r.status == RiskStatus.enRevision).length;

    return AppPage(
      title: 'Reportes de riesgo',
      subtitle: _reports == null
          ? 'Lo que la comunidad avisa del colegio'
          : '${fresh == 1 ? '1 nuevo' : '$fresh nuevos'} · $reviewing en revisión',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: _body(fresh: fresh, reviewing: reviewing),
    );
  }

  Widget _body({required int fresh, required int reviewing}) {
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _failed = false);
            _load();
          },
          child: const Text('No pudimos cargar los reportes. Reintentar'),
        ),
      );
    }
    final List<RiskReport>? reports = _reports;
    if (reports == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (reports.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenGutter),
          child: Text('No hay reportes de riesgo.', style: AppTextStyles.caption),
        ),
      );
    }

    final _Filter filter = _filter ?? _Filter.fresh;
    final List<RiskReport> shown =
        reports.where((RiskReport r) => _matches(filter, r.status)).toList();
    // El abierto es el que se tocó; si no hay, el primero del filtro.
    final RiskReport? open = shown.isEmpty
        ? null
        : shown.firstWhere((RiskReport r) => r.id == _openId, orElse: () => shown.first);
    final List<RiskReport> rest = shown.where((RiskReport r) => r != open).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _FilterChip(
                key: const Key('riesgos-nuevos'),
                label: 'Nuevos · $fresh',
                selected: filter == _Filter.fresh,
                onTap: () => setState(() => _filter = _Filter.fresh),
              ),
              _FilterChip(
                key: const Key('riesgos-en-revision'),
                label: 'En revisión · $reviewing',
                selected: filter == _Filter.reviewing,
                onTap: () => setState(() => _filter = _Filter.reviewing),
              ),
              _FilterChip(
                key: const Key('riesgos-resueltos'),
                label: 'Resueltos',
                selected: filter == _Filter.closed,
                onTap: () => setState(() => _filter = _Filter.closed),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (open == null)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              switch (filter) {
                _Filter.fresh => 'No hay reportes nuevos.',
                _Filter.reviewing => 'Nada en revisión.',
                _Filter.closed => 'Todavía no hay reportes resueltos.',
              },
              style: AppTextStyles.caption,
            ),
          )
        else
          _OpenReport(
            report: open,
            canManage: widget.canManage,
            onStatus: (RiskStatus status) => _setStatus(open, status),
          ),
        if (rest.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < rest.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _RiskRow(
                    report: rest[i],
                    onTap: () => setState(() => _openId = rest[i].id),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (widget.canManage) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Historial completo y exportación en el panel web.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: AppColors.ink,
        backgroundColor: AppColors.surfaceAlt,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.onBrand : AppColors.ink,
        ),
      ),
    );
  }
}

String _who(RiskReport report) => <String?>[
      report.reporterName,
      report.reporterGrade,
    ].whereType<String>().join(' · ');

IconData _kindIcon(RiskKind kind) => switch (kind) {
      RiskKind.grieta => Icons.warning_amber_outlined,
      RiskKind.cable => Icons.bolt_outlined,
      RiskKind.agua => Icons.water_drop_outlined,
      RiskKind.humo => Icons.local_fire_department_outlined,
      RiskKind.arbol => Icons.park_outlined,
      RiskKind.otro => Icons.help_outline,
    };

PillTone _tone(RiskStatus status) => switch (status) {
      RiskStatus.nuevo => PillTone.brand,
      RiskStatus.enRevision => PillTone.warning,
      RiskStatus.atendido => PillTone.success,
      RiskStatus.descartado => PillTone.neutral,
    };

/// El reporte abierto: qué es, dónde, qué dijo quien lo vio y qué hacer.
class _OpenReport extends StatelessWidget {
  const _OpenReport({required this.report, required this.canManage, required this.onStatus});

  final RiskReport report;
  final bool canManage;
  final ValueChanged<RiskStatus> onStatus;

  /// El siguiente paso natural va como botón principal; los demás estados, al lado.
  static RiskStatus _next(RiskStatus status) => switch (status) {
        RiskStatus.nuevo => RiskStatus.enRevision,
        RiskStatus.enRevision => RiskStatus.atendido,
        RiskStatus.atendido || RiskStatus.descartado => RiskStatus.nuevo,
      };

  static String _action(RiskStatus status) => switch (status) {
        RiskStatus.enRevision => 'Asignar revisión',
        RiskStatus.atendido => 'Marcar atendido',
        RiskStatus.descartado => 'Descartar',
        RiskStatus.nuevo => 'Reabrir',
      };

  @override
  Widget build(BuildContext context) {
    final String who = _who(report);
    final RiskStatus next = _next(report.status);

    return AppCard(
      key: Key('riesgo-abierto-${report.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconBubble(icon: _kindIcon(report.kind), size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('${report.kind.label} · ${report.place}', style: AppTextStyles.itemTitle),
                    const SizedBox(height: 2),
                    Text(
                      <String>[
                        if (report.details != null && report.details!.isNotEmpty) '«${report.details}»',
                        if (who.isNotEmpty) who,
                        Fmt.ago(report.createdAt),
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Pill(report.status.label, tone: _tone(report.status)),
            ],
          ),
          if (canManage) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilledButton(
                  key: Key('riesgo-${report.id}-${next.wire}'),
                  onPressed: () => onStatus(next),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(_action(next), style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final RiskStatus status in RiskStatus.values)
                  if (status != report.status && status != next)
                    OutlinedButton(
                      key: Key('riesgo-${report.id}-${status.wire}'),
                      onPressed: () => onStatus(status),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(0, 44),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: Text(_action(status), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.report, required this.onTap});

  final RiskReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String who = _who(report);
    return InkWell(
      key: Key('riesgo-fila-${report.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            IconBubble.neutral(icon: _kindIcon(report.kind), size: 36),
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
            Pill(report.status.label, tone: _tone(report.status)),
          ],
        ),
      ),
    );
  }
}
