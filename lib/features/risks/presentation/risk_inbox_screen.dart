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
import '../../alerts/domain/live_updates.dart';
import '../domain/risk_repository.dart';

/// La bandeja de reportes de riesgo: lo que la comunidad ve (una grieta, un
/// cable suelto) y el colegio debe revisar.
///
/// Coordinación cambia el estado; un docente solo ve los de sus grupos.
class RiskInboxScreen extends StatefulWidget {
  const RiskInboxScreen({this.canManage = false, super.key});

  /// Quién puede cambiar el estado (coordinación).
  final bool canManage;

  @override
  State<RiskInboxScreen> createState() => _RiskInboxScreenState();
}

class _RiskInboxScreenState extends State<RiskInboxScreen> {
  List<RiskReport>? _reports;
  bool _failed = false;
  StreamSubscription<LiveChange>? _live;

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

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Reportes de riesgo',
      subtitle: 'Lo que la comunidad avisa del colegio',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: _body(),
    );
  }

  Widget _body() {
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: <Widget>[
        for (final RiskReport report in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _RiskCard(
              report: report,
              canManage: widget.canManage,
              onStatus: (RiskStatus status) => _setStatus(report, status),
            ),
          ),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.report,
    required this.canManage,
    required this.onStatus,
  });

  final RiskReport report;
  final bool canManage;
  final ValueChanged<RiskStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final String who = <String?>[
      report.reporterName,
      report.reporterGrade,
    ].whereType<String>().join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  report.kind.label,
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                ),
              ),
              Pill(
                report.status.label,
                tone: switch (report.status) {
                  RiskStatus.nuevo => PillTone.brand,
                  RiskStatus.enRevision => PillTone.warning,
                  RiskStatus.atendido => PillTone.success,
                  RiskStatus.descartado => PillTone.neutral,
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${report.place} · ${Fmt.ago(report.createdAt)}',
            style: AppTextStyles.caption,
          ),
          if (report.details != null && report.details!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(report.details!, style: AppTextStyles.body),
          ],
          if (who.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text('Lo reportó $who', style: AppTextStyles.caption),
          ],
          if (canManage) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final RiskStatus status in RiskStatus.values)
                  if (status != report.status)
                    OutlinedButton(
                      key: Key('riesgo-${report.id}-${status.wire}'),
                      onPressed: () => onStatus(status),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        status.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
