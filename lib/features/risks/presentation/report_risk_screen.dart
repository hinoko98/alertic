import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/shell_scope.dart';
import '../../../core/session/user_role.dart';
import '../../incidents/presentation/report_emergency.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/design/pill.dart';
import '../../../shared/design/section_label.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../alerts/domain/live_updates.dart';
import '../domain/risk_repository.dart';

/// Pantalla 15: reportar un riesgo.
///
/// Cualquiera puede avisar de una grieta, un cable o una gotera antes de que sea
/// una emergencia. Llega al comité de gestión del riesgo, que es coordinación, y
/// quien reportó ve debajo cómo van **sus** reportes.
///
/// No es para emergencias: esas se avisan con «Necesito ayuda».
class ReportRiskScreen extends StatefulWidget {
  const ReportRiskScreen({this.placeHint, super.key});

  /// Una pista de dónde puede estar quien reporta: su salón.
  final String? placeHint;

  @override
  State<ReportRiskScreen> createState() => _ReportRiskScreenState();
}

class _ReportRiskScreenState extends State<ReportRiskScreen> {
  RiskKind? _kind;
  final TextEditingController _place = TextEditingController();
  final TextEditingController _details = TextEditingController();

  List<RiskReport> _mine = <RiskReport>[];
  StreamSubscription<LiveChange>? _live;
  bool _sending = false;
  bool _justSent = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange c) => c == LiveChange.myRiskReport)
          .listen((_) => _loadMine());
      _loadMine();
    }
  }

  @override
  void dispose() {
    _live?.cancel();
    _place.dispose();
    _details.dispose();
    super.dispose();
  }

  RiskRepository get _repository => AppScope.of(context).riskRepository!;

  Future<void> _loadMine() async {
    try {
      final List<RiskReport> reports = await _repository.loadMine();
      if (mounted) setState(() => _mine = reports);
    } catch (error, stack) {
      // La lista de «mis reportes» es un extra: reportar sigue sirviendo sin ella.
      ErrorReporter.report(error, stack, context: 'mis reportes');
    }
  }

  /// Avisar de una emergencia es de estudiantes y docentes: son quienes están en
  /// el edificio. Un acudiente reporta riesgos, no emergencias.
  bool get _canReportEmergency {
    final UserRole? role = ShellScope.maybeOf(context)?.role;
    return role == UserRole.estudiante || role == UserRole.docente;
  }

  bool get _canSend => _kind != null && _place.text.trim().length >= 3 && !_sending;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
      _justSent = false;
    });

    try {
      await _repository.report(
        kind: _kind!,
        place: _place.text,
        details: _details.text,
      );
      // Solo se dice «enviado» cuando el servidor lo confirmó.
      if (!mounted) return;
      setState(() {
        _kind = null;
        _place.clear();
        _details.clear();
        _justSent = true;
      });
      await _loadMine();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reportar riesgo');
      if (mounted) {
        setState(() => _error = 'No se pudo enviar. Revisa tu conexión e intenta otra vez.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double chipWidth =
        (MediaQuery.sizeOf(context).width - AppSpacing.screenGutter * 2 - AppSpacing.sm) / 2;

    return AppPage(
      title: 'Reportar un riesgo',
      subtitle: 'Llega al comité de gestión del riesgo',
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
            key: const Key('enviar-reporte'),
            label: 'Enviar reporte',
            icon: null,
            isLoading: _sending,
            onPressed: _canSend ? _send : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          if (_canReportEmergency)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                key: const Key('reportar-emergencia'),
                onTap: () => reportEmergency(context),
                color: AppColors.brandSoft,
                borderColor: AppColors.brand.withValues(alpha: 0.4),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.campaign_outlined, color: AppColors.brand),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Reportar emergencia',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                            ),
                          ),
                          Text(
                            'Si está pasando ahora: humo, temblor, inundación.',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.brand),
                  ],
                ),
              ),
            ),
          if (_justSent)
            Container(
              key: const Key('reporte-enviado'),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Reporte enviado. Te avisaremos cuando lo revisen.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SectionLabel('¿Qué viste?', padding: EdgeInsets.only(bottom: AppSpacing.sm)),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final RiskKind kind in RiskKind.values)
                SizedBox(
                  width: chipWidth,
                  child: AppCard(
                    key: Key('riesgo-${kind.wire}'),
                    onTap: () => setState(() => _kind = kind),
                    color: _kind == kind ? AppColors.brandSoft : AppColors.surface,
                    borderColor: _kind == kind ? AppColors.brand : AppColors.border,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Text(
                      kind.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _kind == kind ? AppColors.brand : AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SectionLabel('¿Dónde?'),
          TextField(
            key: const Key('riesgo-lugar'),
            controller: _place,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.placeHint ?? 'Bloque A · 2.° piso · pasillo',
              counterText: '',
            ),
          ),
          const SectionLabel('Cuéntanos más'),
          TextField(
            key: const Key('riesgo-detalles'),
            controller: _details,
            maxLength: 240,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Ej. grieta nueva en la pared junto a la escalera sur',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                key: const Key('error-reporte'),
                style: AppTextStyles.caption.copyWith(color: AppColors.brand),
              ),
            ),
          if (_mine.isNotEmpty) ...<Widget>[
            const SectionLabel('Mis reportes'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _mine.length; i++) ...<Widget>[
                    if (i > 0) const Divider(height: 1),
                    _MineRow(report: _mine[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MineRow extends StatelessWidget {
  const _MineRow({required this.report});

  final RiskReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(report.kind.label, style: AppTextStyles.itemTitle.copyWith(fontSize: 13)),
                Text(
                  '${report.place} · ${Fmt.ago(report.createdAt)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Pill(
            report.status.label,
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
