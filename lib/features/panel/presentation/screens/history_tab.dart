import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/presentation/widgets/alert_level_style.dart';
import '../panel_layout.dart';

/// Historial de alertas del colegio.
///
/// No estaba en el diseño, pero el colegio lo necesita para dos cosas muy
/// concretas: sustentar los simulacros ante la Secretaría de Educación y
/// revisar qué pasó después de una emergencia real.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<Alert> _alerts = <Alert>[];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final List<Alert> alerts =
          await AppScope.of(context).panelRepository!.loadHistory();
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'historial');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: PanelLayout.headerPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'HISTORIAL',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Cada alerta emitida, con quién la emitió y a quién cobijó.',
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
              : _alerts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text(
                        'Todavía no se ha emitido ninguna alerta.',
                        style: AppTextStyles.body,
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: PanelLayout.gutter(context),
                      ),
                      itemCount: _alerts.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) =>
                          _HistoryRow(alert: _alerts[index]),
                    ),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final AlertLevelStyle style = AlertLevelStyle.of(alert.level);

    final bool compact = PanelLayout.isCompact(context);

    final Widget title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(alert.title, style: AppTextStyles.itemTitle),
        const SizedBox(height: 2),
        Text(
          alert.instructions.join(' · '),
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(fontSize: 11),
        ),
      ],
    );

    // En el celular las cuatro columnas de la tabla se vuelven dos renglones:
    // el qué arriba, y debajo el a quién, el quién y el cuándo en una línea.
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(width: 6, height: 44, color: style.headerColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  title,
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${alert.scope} · ${alert.issuedBy ?? 'Coordinación'} · '
                    '${_dateLabel(alert.issuedAt)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(width: 6, height: 44, color: style.headerColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: 3, child: title),
          Expanded(
            flex: 2,
            child: Text(alert.scope, style: AppTextStyles.caption),
          ),
          Expanded(
            flex: 2,
            child: Text(
              alert.issuedBy ?? 'Coordinación',
              style: AppTextStyles.caption,
            ),
          ),
          Expanded(
            child: Text(
              _dateLabel(alert.issuedAt),
              textAlign: TextAlign.right,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    const List<String> months = <String>[
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} · '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
