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
import '../../alerts/domain/alert_level.dart';
import '../../alerts/domain/hazard.dart';
import '../../alerts/domain/live_updates.dart';
import '../../alerts/domain/protocol.dart';
import '../../panel/domain/community_admin.dart';
import '../../panel/domain/hazard_watch.dart';
import '../../panel/domain/panel_repository.dart';
import '../../teacher/domain/teacher_repository.dart';
import '../domain/hazard_alert_defaults.dart';

String _hazardName(Hazard h) => switch (h) {
      Hazard.sismo => 'Sismo',
      Hazard.inundacion => 'Creciente o inundación',
      Hazard.lluvia => 'Lluvia fuerte',
      Hazard.incendio => 'Incendio',
    };

String _levelName(AlertLevel l) => switch (l) {
      AlertLevel.roja => 'Evacuar',
      AlertLevel.naranja => 'Precaución',
      AlertLevel.amarilla => 'Informar',
    };

/// Avisos de amenazas por revisar, en el celular de un docente o de
/// coordinación.
///
/// Ninguna fuente emite una alerta sola: aquí una persona la confirma o la
/// descarta. Los avisos que escribe una persona (un incendio) piden además la
/// aprobación de **otra** antes de poder emitirse, para que un error o una broma
/// de un solo teclado no evacúe el colegio.
class HazardReviewScreen extends StatefulWidget {
  const HazardReviewScreen({super.key});

  @override
  State<HazardReviewScreen> createState() => _HazardReviewScreenState();
}

class _HazardReviewScreenState extends State<HazardReviewScreen> {
  List<HazardSignal>? _signals;
  bool _failed = false;
  StreamSubscription<LiveChange>? _live;

  PanelRepository get _repo => AppScope.of(context).panelRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange c) => c == LiveChange.hazardSignals)
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
      final List<HazardSignal> signals = await _repo.loadSignals();
      if (mounted) {
        setState(() {
          _signals = signals;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'avisos por revisar');
      if (mounted) setState(() => _failed = _signals == null);
    }
  }

  void _say(String message) {
    // Cada mensaje reemplaza al anterior: el último es el que importa.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _act(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) _say(done);
      await _load();
    } on PanelActionFailure catch (f) {
      if (mounted) _say(f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'revisar aviso');
      if (mounted) _say('No se pudo completar. Intenta otra vez.');
    }
  }

  Future<void> _emit(HazardSignal s) async {
    final AlertLevel level = s.suggestedLevel ?? AlertLevel.naranja;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Emitir la alerta?'),
        content: Text(
          '${HazardAlertDefaults.title(s.hazard, level)} · ${_levelName(level)}\n\n'
          'Le llega a todo el colegio en segundos y no se puede deshacer.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: const Text('EMITIR'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final AppScope scope = AppScope.of(context);
    await _act(() async {
      List<Protocol> protocols = const <Protocol>[];
      try {
        protocols = await scope.alertRepository.loadProtocols();
      } catch (error, stack) {
        ErrorReporter.report(error, stack, context: 'protocolos (revisar aviso)');
      }
      await _repo.issueAlertFromSignal(
        s.id,
        AlertDraft(
          level: level,
          hazard: s.hazard,
          title: HazardAlertDefaults.title(s.hazard, level),
          scope: 'Todo el instituto',
          instructions: HazardAlertDefaults.instructions(s.hazard, level, protocols),
        ),
      );
    }, 'Alerta emitida');
  }

  Future<void> _report() async {
    final bool? sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReportSheet(),
    );
    if (sent == true && mounted) {
      _say('Aviso enviado. Otra persona tiene que aprobarlo.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Avisos por revisar',
      subtitle: 'Las fuentes sugieren; una persona decide',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: _body(),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screenGutter, 0, AppSpacing.screenGutter, AppSpacing.lg),
        child: SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
            onPressed: _report,
            icon: const Icon(Icons.local_fire_department_outlined),
            label: const Text('Reportar incendio u otra emergencia'),
          ),
        ),
      ),
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
          child: const Text('No pudimos cargar los avisos. Reintentar'),
        ),
      );
    }
    final List<HazardSignal>? signals = _signals;
    if (signals == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (signals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenGutter),
          child: Text(
            'No hay avisos por revisar. Si una fuente detecta un sismo, lluvia fuerte o riesgo de creciente, aparecerá aquí.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: <Widget>[
        for (final HazardSignal s in signals)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _SignalCard(
              signal: s,
              onApprove: () => _act(() async => _repo.approveSignal(s.id), 'Aviso aprobado'),
              onDismiss: () => _act(() => _repo.dismissSignal(s.id), 'Aviso descartado'),
              onEmit: () => _emit(s),
            ),
          ),
      ],
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.signal,
    required this.onApprove,
    required this.onDismiss,
    required this.onEmit,
  });

  final HazardSignal signal;
  final VoidCallback onApprove;
  final VoidCallback onDismiss;
  final VoidCallback onEmit;

  @override
  Widget build(BuildContext context) {
    final HazardSignal s = signal;
    final AlertLevel? level = s.suggestedLevel;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: <Widget>[
            Pill(_hazardName(s.hazard), tone: PillTone.dark),
            if (level != null)
              Pill(
                'Sugiere ${_levelName(level).toLowerCase()}',
                tone: level == AlertLevel.roja ? PillTone.brand : (level == AlertLevel.naranja ? PillTone.warning : PillTone.neutral),
              ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(s.headline, style: AppTextStyles.itemTitle),
          const SizedBox(height: 2),
          Text('${s.detail}\n${s.source} · ${Fmt.hour(s.occurredAt)}', style: AppTextStyles.caption),
          if (s.isManual) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.awaitingApproval
                  ? 'Lo reportó ${s.reportedBy ?? 'una persona'}. Necesita que otra persona lo apruebe.'
                  : 'Aprobado por ${s.approvedBy ?? 'otra persona'}.',
              style: AppTextStyles.caption.copyWith(
                color: s.awaitingApproval ? AppColors.warning : AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: <Widget>[
            if (s.awaitingApproval)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                onPressed: onApprove,
                child: const Text('Aprobar'),
              ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: s.canEmit ? onEmit : null,
              child: const Text('Emitir alerta'),
            ),
            OutlinedButton(onPressed: onDismiss, child: const Text('Descartar')),
          ]),
        ],
      ),
    );
  }
}

/// Reportar lo que ninguna fuente detecta, desde el celular.
class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  Hazard _hazard = Hazard.incendio;
  final TextEditingController _detail = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_detail.text.trim().length < 3) {
      setState(() => _error = 'Cuenta qué pasa y dónde.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).panelRepository!.reportHazard(
            ManualHazardReport(hazard: _hazard, detail: _detail.text),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reportar amenaza (celular)');
      if (mounted) setState(() => _error = 'No se pudo enviar el aviso.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Reportar una emergencia', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: <Widget>[
            for (final Hazard h in Hazard.values)
              ChoiceChip(
                label: Text(_hazardName(h)),
                selected: _hazard == h,
                onSelected: (_) => setState(() => _hazard = h),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _detail,
            minLines: 2,
            maxLines: 4,
            maxLength: 240,
            decoration: const InputDecoration(hintText: 'Qué se ve y dónde: humo en el laboratorio 2'),
          ),
          const Text(
            'Otra persona (coordinación o un docente) tiene que aprobarlo antes de emitir la alerta. '
            'Si hay peligro inmediato, activa también la alarma del colegio.',
            style: AppTextStyles.caption,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.brand)),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Enviando…' : 'Enviar para aprobación'),
            ),
          ),
        ],
      ),
    );
  }
}

/// La franja que avisa, en cualquier pestaña, que hay avisos por decidir. Solo
/// la ven docentes y coordinación.
class HazardReviewBanner extends StatefulWidget {
  const HazardReviewBanner({super.key});

  @override
  State<HazardReviewBanner> createState() => _HazardReviewBannerState();
}

class _HazardReviewBannerState extends State<HazardReviewBanner> {
  int _pending = 0;
  int _awaiting = 0;
  StreamSubscription<LiveChange>? _live;
  Timer? _poll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_live == null) {
      _live = AppScope.of(context)
          .liveUpdates
          .changes
          .where((LiveChange c) => c == LiveChange.hazardSignals)
          .listen((_) => _load());
      // Por si el canal en vivo se cae: no se puede perder un aviso.
      _poll = Timer.periodic(const Duration(minutes: 2), (_) => _load());
      _load();
    }
  }

  @override
  void dispose() {
    unawaited(_live?.cancel());
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final PanelRepository? repo = AppScope.of(context).panelRepository;
    if (repo == null) return;
    try {
      final List<HazardSignal> signals = await repo.loadSignals();
      if (mounted) {
        setState(() {
          _pending = signals.length;
          _awaiting = signals.where((HazardSignal s) => s.awaitingApproval).length;
        });
      }
    } catch (error, stack) {
      // La franja es un aviso extra: si no se puede consultar, no se muestra.
      ErrorReporter.report(error, stack, context: 'franja de avisos');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending == 0) return const SizedBox.shrink();
    return Material(
      color: AppColors.warningSoft,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const HazardReviewScreen()),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter, vertical: AppSpacing.sm),
            child: Row(
              children: <Widget>[
                const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _awaiting > 0
                        ? '$_pending ${_pending == 1 ? 'aviso' : 'avisos'} por revisar · $_awaiting esperan tu aprobación'
                        : '$_pending ${_pending == 1 ? 'aviso' : 'avisos'} de amenaza por revisar',
                    style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.warning),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
