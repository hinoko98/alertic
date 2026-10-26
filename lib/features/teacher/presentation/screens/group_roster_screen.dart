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

/// Pantalla 47: la lista del grupo en el punto de encuentro.
///
/// Responde una sola pregunta: quién falta. Por eso lo primero es el contador y
/// lo segundo son los que faltan, no la lista completa en orden alfabético; los
/// que ya están a salvo quedan plegados debajo.
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
  bool _showSafe = false;
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
    final List<RosterEntry> needHelp = _entries.where((RosterEntry e) => e.needsHelp).toList();
    final List<RosterEntry> pending = _entries.where((RosterEntry e) => !e.hasResponded).toList();
    final List<RosterEntry> safe = _entries
        .where((RosterEntry e) => e.hasResponded && !e.needsHelp)
        .toList();
    final List<RosterEntry> missing = <RosterEntry>[...needHelp, ...pending];
    final int byTeacher = safe.where((RosterEntry e) => e.markedByTeacher).length;
    final String? point = widget.alert.meetingPoint;

    return AppPage(
      title: 'Lista · ${widget.grade}',
      subtitle: <String>[
        if (point != null && point.isNotEmpty) point,
        '${widget.alert.title} ${widget.alert.issuedAtLabel}',
      ].join(' · '),
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      actions: const <Widget>[_LiveChip()],
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
            label: 'Enviar lista a Coordinación',
            background: AppColors.ink,
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      'Lista de ${widget.grade} enviada: '
                      '${safe.length} a salvo, ${needHelp.length} con ayuda, '
                      '${pending.length} sin respuesta.',
                    ),
                  ),
                );
            },
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
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
                _Counter(safe: safe.length, total: _entries.length, byTeacher: byTeacher),
                const SizedBox(height: AppSpacing.md),
                if (missing.isEmpty)
                  const AppCard(
                    key: Key('nadie-falta'),
                    child: Text('No falta nadie. Todo el grupo está a salvo.', style: AppTextStyles.body),
                  )
                else ...<Widget>[
                  Text('FALTAN ${missing.length}', style: AppTextStyles.eyebrow),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    key: const Key('faltan'),
                    borderColor: AppColors.brandSoft,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < missing.length; i++) ...<Widget>[
                          if (i > 0) const Divider(height: 1, color: AppColors.border),
                          _MissingRow(
                            entry: missing[i],
                            // Quien pidió ayuda no se marca a salvo desde aquí: el
                            // servidor lo rechaza y la brigada debe atenderlo.
                            onHere: missing[i].needsHelp ? null : () => _markSafe(missing[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (safe.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _SafeToggle(
                    count: safe.length,
                    expanded: _showSafe,
                    onTap: () => setState(() => _showSafe = !_showSafe),
                  ),
                  if (_showSafe) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: <Widget>[
                          for (final RosterEntry entry in safe) _SafeRow(entry: entry),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

/// «En curso»: la lista se actualiza sola mientras dura la alerta.
class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '● En curso',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brand),
      ),
    );
  }
}

/// Lo primero que se ve: cuántos están a salvo y quién los marcó.
class _Counter extends StatelessWidget {
  const _Counter({required this.safe, required this.total, required this.byTeacher});

  final int safe;
  final int total;
  final int byTeacher;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('contador-lista'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text('A salvo', style: AppTextStyles.itemTitle),
              Text(
                '$safe de $total',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: '$safe de $total a salvo',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : safe / total,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${safe - byTeacher} confirmaron en su celular · $byTeacher los marcaste tú',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

/// Una persona que falta: quién es, por qué falta y qué se puede hacer.
class _MissingRow extends StatelessWidget {
  const _MissingRow({required this.entry, required this.onHere});

  final RosterEntry entry;
  final VoidCallback? onHere;

  @override
  Widget build(BuildContext context) {
    final String detail = entry.needsHelp
        ? 'Pidió ayuda${entry.location == null ? '' : ' · ${entry.location!.label}'}'
        : 'Sin respuesta en su celular';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: entry.needsHelp ? AppColors.brandSoft : AppColors.surfaceAlt,
            child: Text(
              PersonName.initials(entry.fullName),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: entry.needsHelp ? AppColors.brand : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(PersonName.short(entry.fullName), style: AppTextStyles.itemTitle),
                Text(detail, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (onHere != null)
            // Para quien no tiene celular: el docente lo ve en el punto de
            // encuentro y lo marca a mano.
            OutlinedButton(
              key: Key('esta-aqui-${entry.personId}'),
              onPressed: onHere,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                minimumSize: const Size(0, 44),
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
              child: const Text('Está aquí', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            )
          else
            const Text(
              'Pidió ayuda',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brand),
            ),
        ],
      ),
    );
  }
}

/// «28 a salvo · Ver la lista completa»: pliega a los que ya no preocupan.
class _SafeToggle extends StatelessWidget {
  const _SafeToggle({required this.count, required this.expanded, required this.onTap});

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('ver-a-salvo'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.successSoft,
            child: Icon(Icons.check, size: 18, color: AppColors.success),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('$count a salvo', style: AppTextStyles.itemTitle),
                Text(expanded ? 'Ocultar la lista' : 'Ver la lista completa', style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(expanded ? Icons.expand_less : Icons.chevron_right, color: AppColors.inkMuted),
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
    final DateTime? at = entry.reportedAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(PersonName.short(entry.fullName), style: AppTextStyles.body)),
          Text(
            <String>[
              if (entry.markedByTeacher) 'Lo marcaste tú',
              if (at != null) '${at.hour}:${at.minute.toString().padLeft(2, '0')}',
            ].join(' · '),
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
