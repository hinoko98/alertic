import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/pill.dart';
import '../../../shared/format.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../domain/risk_repository.dart';

/// Pantalla 31: «Reporte enviado».
///
/// Solo se llega aquí cuando el servidor confirmó el reporte. Dice qué se envió,
/// con su número, y los tres pasos que siguen —enviado, en revisión, resuelto—
/// para que la persona sepa que alguien lo va a leer.
class ReportSentScreen extends StatelessWidget {
  const ReportSentScreen({
    required this.report,
    required this.onSeeMine,
    required this.onHome,
    super.key,
  });

  final RiskReport report;

  /// «Ver mis reportes».
  final VoidCallback onSeeMine;

  /// «Volver al inicio».
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('reporte-enviado'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xxl,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: AppColors.successSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_outlined, size: 44, color: AppColors.success),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Reporte enviado',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.screenTitle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Gracias por cuidar el colegio. El comité de gestión del riesgo ya '
                      'lo recibió.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Pill(report.kind.label, tone: PillTone.brand),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              if (report.number != null)
                                Flexible(
                                  child: Text(
                                    'Reporte n.º ${report.number}',
                                    key: const Key('numero-reporte'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(report.place, style: AppTextStyles.itemTitle),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Text('SEGUIMIENTO', style: AppTextStyles.eyebrow),
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: <Widget>[
                          _Step(
                            number: null,
                            title: 'Enviado',
                            detail: 'Hoy, ${Fmt.hour(report.createdAt)}',
                            done: true,
                            last: false,
                          ),
                          const _Step(
                            number: 2,
                            title: 'En revisión',
                            detail: 'Alguien del colegio va a mirarlo',
                            done: false,
                            last: false,
                          ),
                          const _Step(
                            number: 3,
                            title: 'Resuelto',
                            detail: 'Te avisaremos cuando esté listo',
                            done: false,
                            last: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PrimaryButton(
                    key: const Key('ver-mis-reportes'),
                    label: 'Ver mis reportes',
                    icon: null,
                    onPressed: onSeeMine,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    key: const Key('reporte-volver-inicio'),
                    label: 'Volver al inicio',
                    onPressed: onHome,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un paso del seguimiento: un círculo (con ✓ si ya pasó), su línea y el texto.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
    required this.done,
    required this.last,
  });

  final int? number;
  final String title;
  final String detail;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.success : const Color(0xFFE7EAEE),
                  shape: BoxShape.circle,
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '$number',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkMuted,
                        ),
                      ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: done ? const Color(0xFFBFDCCB) : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                  Text(detail, style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
