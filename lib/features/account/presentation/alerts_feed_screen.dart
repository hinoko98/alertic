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
import '../../../shared/design/section_label.dart';
import '../../../shared/format.dart';
import '../../alerts/domain/hazard.dart';
import '../../alerts/domain/live_updates.dart';
import '../../alerts/presentation/widgets/hazard_icon.dart';
import '../../risks/domain/risk_repository.dart';
import '../domain/account_repository.dart';

/// Pantalla 16: alertas y avisos.
///
/// El historial de lo que pasó en el colegio —alertas y simulacros— junto con los
/// reportes que hizo la persona y cómo van. Se filtra por tipo.
class AlertsFeedScreen extends StatefulWidget {
  const AlertsFeedScreen({super.key});

  @override
  State<AlertsFeedScreen> createState() => _AlertsFeedScreenState();
}

enum _Filter { all, alerts, mine }

class _AlertsFeedScreenState extends State<AlertsFeedScreen> {
  List<FeedItem>? _items;
  StreamSubscription<LiveChange>? _live;
  _Filter _filter = _Filter.all;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      // Cuando coordinación cambia el estado de un reporte, aparece sin recargar.
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
    try {
      final List<FeedItem> items = await AppScope.of(context).accountRepository!.loadFeed();
      if (mounted) {
        setState(() {
          _items = items;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'alertas y avisos');
      if (mounted) setState(() => _failed = _items == null);
    }
  }

  List<FeedItem> get _visible => (_items ?? const <FeedItem>[]).where((FeedItem item) {
        return switch (_filter) {
          _Filter.all => true,
          _Filter.alerts => item.kind != 'reporte_riesgo',
          _Filter.mine => item.kind == 'reporte_riesgo',
        };
      }).toList();

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Alertas y avisos',
      subtitle: 'Historial de tu colegio',
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
          child: const Text('No pudimos cargar el historial. Reintentar'),
        ),
      );
    }
    if (_items == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }

    final List<FeedItem> items = _visible;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            _FilterChip(
              label: 'Todas',
              selected: _filter == _Filter.all,
              onTap: () => setState(() => _filter = _Filter.all),
            ),
            _FilterChip(
              label: 'Alertas',
              selected: _filter == _Filter.alerts,
              onTap: () => setState(() => _filter = _Filter.alerts),
            ),
            _FilterChip(
              label: 'Mis reportes',
              selected: _filter == _Filter.mine,
              onTap: () => setState(() => _filter = _Filter.mine),
            ),
          ],
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xl),
            child: Text(
              'Todavía no hay nada que mostrar.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          )
        else
          ..._grouped(items),
      ],
    );
  }

  /// Agrupa por mes, como el diseño: «Esta semana», «Septiembre»…
  List<Widget> _grouped(List<FeedItem> items) {
    final DateTime now = DateTime.now();
    final List<Widget> out = <Widget>[];
    String? current;
    List<Widget> rows = <Widget>[];

    void flush() {
      if (current != null && rows.isNotEmpty) {
        out
          ..add(SectionLabel(current))
          ..add(AppCard(padding: EdgeInsets.zero, child: Column(children: rows)));
      }
    }

    for (final FeedItem item in items) {
      final String label =
          now.difference(item.at).inDays < 7 ? 'Esta semana' : Fmt.monthName(item.at);
      if (label != current) {
        flush();
        current = label;
        rows = <Widget>[];
      }
      if (rows.isNotEmpty) rows.add(const Divider(height: 1));
      rows.add(_FeedRow(item: item));
    }
    flush();
    return out;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppColors.ink,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? AppColors.onBrand : AppColors.ink,
      ),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      shape: const StadiumBorder(),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    final Hazard? hazard = Hazard.tryParse(item.hazard);

    final (IconData icon, Color bg, Color fg) = switch (item.kind) {
      'reporte_riesgo' => (Icons.warning_amber_outlined, AppColors.surfaceAlt, AppColors.ink),
      'simulacro' => (Icons.event_outlined, AppColors.surfaceAlt, AppColors.ink),
      _ => (hazard == null ? Icons.notifications_none : hazardIcon(hazard), AppColors.brandSoft, AppColors.brand),
    };

    final String title = switch (item.kind) {
      'reporte_riesgo' => item.riskStatus == 'atendido' ? 'Tu reporte fue atendido' : 'Reporte enviado',
      'simulacro' => 'Simulacro · ${item.title}',
      _ => item.active ? '${item.title} · activa' : '${item.title} · finalizada',
    };

    final String detail = switch (item.kind) {
      'reporte_riesgo' => '${item.title} · ${Fmt.dayMonthShort(item.at)}',
      _ => item.myStatus == 'a_salvo'
          ? 'Confirmaste a salvo${item.mySeconds == null ? '' : ' en ${Fmt.minutesSeconds(item.mySeconds!)} min'} · ${Fmt.dayMonthShort(item.at)}'
          : '${Fmt.dayMonthShort(item.at)} · ${Fmt.hour(item.at)}',
    };

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          IconBubble(icon: icon, size: 36, background: bg, foreground: fg),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(detail, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (item.kind == 'reporte_riesgo' && item.riskStatus != null)
            _riskPill(item.riskStatus!),
        ],
      ),
    );
  }

  static Widget _riskPill(String status) {
    final RiskStatus? parsed = RiskStatus.tryParse(status);
    if (parsed == null) return const SizedBox.shrink();
    return Pill(
      parsed.label,
      tone: switch (parsed) {
        RiskStatus.nuevo => PillTone.neutral,
        RiskStatus.enRevision => PillTone.warning,
        RiskStatus.atendido => PillTone.success,
        RiskStatus.descartado => PillTone.neutral,
      },
    );
  }
}
