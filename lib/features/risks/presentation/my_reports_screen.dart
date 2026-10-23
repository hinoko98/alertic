import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/design/pill.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../alerts/domain/live_updates.dart';
import '../domain/risk_repository.dart';

/// Pantalla 32: «Mis reportes».
///
/// Lo que la persona ha avisado al colegio y cómo va cada cosa: cuántos envió,
/// cuántos están en revisión y cuántos se resolvieron. Se actualiza solo cuando
/// coordinación cambia el estado de uno.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({required this.onNewReport, super.key});

  /// «Nuevo reporte».
  final VoidCallback onNewReport;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<RiskReport> _reports = <RiskReport>[];
  StreamSubscription<LiveChange>? _live;
  bool _loading = true;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange c) => c == LiveChange.myRiskReport)
          .listen((_) => _load());
      _load();
    }
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final RiskRepository? repository = AppScope.of(context).riskRepository;
    if (repository == null) return;
    try {
      final List<RiskReport> reports = await repository.loadMine();
      if (mounted) {
        setState(() {
          _reports = reports;
          _loading = false;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'mis reportes');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  int get _inReview =>
      _reports.where((RiskReport r) => r.status == RiskStatus.enRevision).length;

  int get _resolved =>
      _reports.where((RiskReport r) => r.status == RiskStatus.atendido).length;

  /// Los que se corrigieron este año: el mensaje de abajo dice «este año».
  int get _fixedThisYear => _reports
      .where((RiskReport r) =>
          r.status == RiskStatus.atendido && r.createdAt.year == DateTime.now().year)
      .length;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Mis reportes',
      subtitle: 'Lo que has avisado al colegio',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.screenGutter,
            AppSpacing.md,
          ),
          child: PrimaryButton(
            key: const Key('nuevo-reporte'),
            label: 'Nuevo reporte',
            icon: null,
            onPressed: widget.onNewReport,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : _failed
              ? Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _load();
                    },
                    child: const Text('No pudimos cargar tus reportes. Reintentar'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenGutter),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _Count(
                            key: const Key('cuenta-enviados'),
                            value: _reports.length,
                            label: 'Enviados',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _Count(
                            key: const Key('cuenta-revision'),
                            value: _inReview,
                            label: 'En revisión',
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _Count(
                            key: const Key('cuenta-resueltos'),
                            value: _resolved,
                            label: 'Resueltos',
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_reports.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Todavía no has enviado reportes. Si ves una grieta, un cable '
                          'suelto o una gotera, avísanos.',
                          key: Key('sin-reportes'),
                          style: AppTextStyles.caption,
                        ),
                      )
                    else
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < _reports.length; i++) ...<Widget>[
                              if (i > 0) const Divider(height: 1),
                              _ReportRow(report: _reports[i]),
                            ],
                          ],
                        ),
                      ),
                    if (_fixedThisYear > 0) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        key: const Key('riesgos-corregidos'),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(AppSpacing.radius),
                          border: Border.all(color: const Color(0xFFBFDCCB)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.verified_user_outlined,
                                size: 20, color: AppColors.success),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                _fixedThisYear == 1
                                    ? 'Tus reportes ayudaron a corregir 1 riesgo este año.'
                                    : 'Tus reportes ayudaron a corregir $_fixedThisYear '
                                        'riesgos este año.',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: Color(0xFF1F5C3D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.color, super.key});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color ?? AppColors.ink),
          ),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    final String number = report.number == null ? '' : ' · n.º ${report.number}';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${report.kind.label} · ${report.place}',
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                ),
                Text('${Fmt.ago(report.createdAt)}$number', style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Pill(
            report.status == RiskStatus.nuevo ? 'Enviado' : report.status.label,
            tone: switch (report.status) {
              RiskStatus.nuevo => PillTone.neutral,
              RiskStatus.enRevision => PillTone.warning,
              RiskStatus.atendido => PillTone.success,
              RiskStatus.descartado => PillTone.neutral,
            },
          ),
        ],
      ),
    );
  }
}
