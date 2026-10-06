import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../alerts/domain/alert.dart';
import '../../../alerts/domain/live_updates.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/teacher_repository.dart';

/// Pantalla 15: la lista del grupo durante la emergencia.
///
/// Responde una sola pregunta: quién falta. Por eso lo primero es el contador y
/// lo segundo son los que no han respondido, no la lista completa en orden
/// alfabético.
class GroupRosterScreen extends StatefulWidget {
  const GroupRosterScreen({
    required this.alert,
    required this.grade,
    super.key,
  });

  final Alert alert;
  final String grade;

  @override
  State<GroupRosterScreen> createState() => _GroupRosterScreenState();
}

class _GroupRosterScreenState extends State<GroupRosterScreen> {
  List<RosterEntry> _entries = <RosterEntry>[];
  bool _loading = true;
  String? _error;

  StreamSubscription<LiveChange>? _live;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      unawaited(_load());
    }
    // Cuando un estudiante reporta, la lista se actualiza sola: el docente no
    // tiene que salir y volver a entrar para ver quién falta.
    _live ??= AppScope.of(context).liveUpdates.changes
        .where((LiveChange change) => change == LiveChange.reports)
        .listen((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<RosterEntry> entries = await AppScope.of(
        context,
      ).teacherRepository!.loadRoster(widget.alert.id, widget.grade);
      if (mounted) {
        setState(() {
          _entries = entries;
          _loading = false;
          _error = null;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'lista del grupo');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No pudimos cargar la lista. Intenta otra vez.';
        });
      }
    }
  }

  Future<void> _markSafe(RosterEntry entry) async {
    try {
      await AppScope.of(
        context,
      ).teacherRepository!.markSafe(widget.alert.id, entry.personId);
      await _load();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'marcar a salvo');
      if (mounted) {
        // El servidor explica por qué no: «pidió ayuda», «no es de tus
        // grupos». Ese texto dice qué hacer; el genérico no.
        final String message = error is ApiException
            ? error.message
            : 'No se pudo registrar. Intenta otra vez.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<RosterEntry> needHelp = _entries
        .where((RosterEntry e) => e.needsHelp)
        .toList();
    final List<RosterEntry> pending = _entries
        .where((RosterEntry e) => !e.hasResponded)
        .toList();
    final List<RosterEntry> safe = _entries
        .where((RosterEntry e) => e.hasResponded && !e.needsHelp)
        .toList();

    return AppPage(
      title: 'Lista del grupo',
      subtitle: '${widget.alert.title} · ${widget.alert.issuedAtLabel}',
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
            label: 'ENVIAR REPORTE A COORDINACIÓN',
            background: AppColors.ink,
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Reporte de ${widget.grade} enviado: '
                      '${safe.length} a salvo, ${needHelp.length} con ayuda, '
                      '${pending.length} sin respuesta.',
                    ),
                  ),
                );
            },
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          _Counter(
            grade: widget.grade,
            responded: safe.length + needHelp.length,
            total: _entries.length,
            safe: safe.length,
            needHelp: needHelp.length,
            pending: pending.length,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.screenGutter),
                      child: Text(_error!, style: AppTextStyles.body),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      AppSpacing.md,
                      AppSpacing.screenGutter,
                      AppSpacing.xl,
                    ),
                    children: <Widget>[
                      for (final RosterEntry entry in needHelp)
                        _NeedsHelpCard(entry: entry),
                      if (pending.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'SIN RESPUESTA',
                          style: AppTextStyles.eyebrow,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final RosterEntry entry in pending)
                          _PendingRow(
                            entry: entry,
                            onMarkSafe: () => _markSafe(entry),
                          ),
                      ],
                      if (safe.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'A SALVO · ${safe.length}',
                          style: AppTextStyles.eyebrow,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final RosterEntry entry in safe)
                          _SafeRow(entry: entry),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Lo primero que se ve: cuántos faltan.
class _Counter extends StatelessWidget {
  const _Counter({
    required this.grade,
    required this.responded,
    required this.total,
    required this.safe,
    required this.needHelp,
    required this.pending,
  });

  final String grade;
  final int responded;
  final int total;
  final int safe;
  final int needHelp;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final double progress = total == 0 ? 0 : responded / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.md,
        AppSpacing.screenGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(child: Text(grade, style: AppTextStyles.screenTitle)),
              Text(
                '$responded',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              Text(
                '/$total',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.success,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Text('$safe a salvo', style: AppTextStyles.caption),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$needHelp ayuda',
                style: AppTextStyles.caption.copyWith(
                  color: needHelp > 0 ? AppColors.brand : AppColors.inkMuted,
                  fontWeight: needHelp > 0 ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('$pending sin respuesta', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeedsHelpCard extends StatelessWidget {
  const _NeedsHelpCard({required this.entry});

  final RosterEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: AppColors.brandSoft,
        borderColor: AppColors.brand,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline, color: AppColors.brand, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    PersonName.short(entry.fullName),
                    style: AppTextStyles.itemTitle,
                  ),
                  Text('Necesita ayuda', style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.entry, required this.onMarkSafe});

  final RosterEntry entry;
  final VoidCallback onMarkSafe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              PersonName.short(entry.fullName),
              style: AppTextStyles.itemTitle,
            ),
          ),
          // Para quien no tiene celular: el docente lo ve en el punto de
          // encuentro y lo marca a mano.
          OutlinedButton(
            onPressed: onMarkSafe,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
            child: const Text(
              'MARCAR A SALVO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeRow extends StatelessWidget {
  const _SafeRow({required this.entry});

  final RosterEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              PersonName.short(entry.fullName),
              style: AppTextStyles.body,
            ),
          ),
          Text(
            entry.location == null
                ? ''
                : '${entry.reportedAt?.hour ?? 0}:'
                      '${(entry.reportedAt?.minute ?? 0).toString().padLeft(2, '0')}',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
