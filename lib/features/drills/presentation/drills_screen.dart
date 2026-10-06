import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
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
import '../../alerts/domain/hazard.dart';
import '../../teacher/presentation/screens/new_alert_screen.dart';
import '../domain/drill_repository.dart';

/// Pantalla 18: simulacros.
///
/// A todos: cuándo es el próximo y cómo les fue en el último (cuánto tardaron en
/// confirmar que estaban a salvo y qué porcentaje del colegio llegó dentro de la
/// meta). A coordinación, además, programar y cancelar.
class DrillsScreen extends StatefulWidget {
  const DrillsScreen({
    this.meetingPoint,
    this.onReviewRoute,
    this.canSchedule = false,
    super.key,
  });

  /// El punto de encuentro de quien mira, si tiene uno (un estudiante).
  final String? meetingPoint;

  /// Lleva al mapa de quien mira. Solo un estudiante lo tiene.
  final VoidCallback? onReviewRoute;

  /// Coordinación programa y cancela.
  final bool canSchedule;

  @override
  State<DrillsScreen> createState() => _DrillsScreenState();
}

class _DrillsScreenState extends State<DrillsScreen> {
  DrillOverview? _overview;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  DrillRepository get _repository => AppScope.of(context).drillRepository!;

  bool get _isAdmin => widget.canSchedule;

  Future<void> _load() async {
    try {
      final DrillOverview overview = await _repository.load();
      if (mounted) {
        setState(() {
          _overview = overview;
          _failed = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'simulacros');
      if (mounted) setState(() => _failed = _overview == null);
    }
  }

  Future<void> _schedule() async {
    final ({Hazard hazard, DateTime at, String? note})? draft =
        await showModalBottomSheet<({Hazard hazard, DateTime at, String? note})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => const _ScheduleSheet(),
    );
    if (draft == null || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await _repository.schedule(hazard: draft.hazard, at: draft.at, note: draft.note);
      await _load();
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'programar simulacro');
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo programar. Intenta otra vez.')),
      );
    }
  }

  /// Abre la pantalla de emitir con el simulacro ya escogido: al enviarla, el
  /// servidor lo da por realizado y mide los tiempos.
  Future<void> _start(Drill drill) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => NewAlertScreen(
          groups: const <String>[],
          initialHazard: drill.hazard,
          drillId: drill.id,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _cancel(Drill drill) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Cancelar el simulacro?'),
        content: Text(
          'El simulacro de ${drill.hazard.label.toLowerCase()} del '
          '${Fmt.dayMonth(drill.scheduledAt)} dejará de aparecerles a todos.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    try {
      await _repository.cancel(drill.id);
      await _load();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cancelar simulacro');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Simulacros',
      subtitle: 'Practicar es prepararse',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: _body(),
    );
  }

  Widget _body() {
    final DrillOverview? overview = _overview;
    if (_failed) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _failed = false);
            _load();
          },
          child: const Text('No pudimos cargar los simulacros. Reintentar'),
        ),
      );
    }
    if (overview == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }

    final Drill? next = overview.next;
    final DrillResult? last = overview.last;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenGutter),
      children: <Widget>[
        if (next != null)
          _NextDrill(
            drill: next,
            meetingPoint: widget.meetingPoint,
            onReviewRoute: widget.onReviewRoute,
            isAdmin: _isAdmin,
            onCancel: () => _cancel(next),
            onStart: () => _start(next),
          )
        else
          const AppCard(
            child: Text(
              'No hay simulacros programados por ahora.',
              style: AppTextStyles.caption,
            ),
          ),
        if (overview.upcoming.length > 1) ...<Widget>[
          const SectionLabel('Más adelante'),
          for (final Drill drill in overview.upcoming.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Simulacro de ${drill.hazard.label.toLowerCase()} · '
                        '${Fmt.dayMonth(drill.scheduledAt)}',
                        style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                      ),
                    ),
                    if (_isAdmin)
                      IconButton(
                        tooltip: 'Cancelar',
                        onPressed: () => _cancel(drill),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
              ),
            ),
        ],
        if (_isAdmin) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const Key('programar-simulacro'),
            label: 'Programar un simulacro',
            icon: Icons.add,
            onPressed: _schedule,
          ),
        ],
        const SectionLabel('Tu último resultado'),
        if (last == null)
          const AppCard(
            child: Text(
              'Todavía no se ha hecho ningún simulacro. Cuando se haga, aquí '
              'verás cuánto tardaste en llegar al punto de encuentro.',
              style: AppTextStyles.caption,
            ),
          )
        else
          _LastResult(result: last, goalSeconds: overview.goalSeconds),
        if (overview.history.length > 1) ...<Widget>[
          const SectionLabel('Historial'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 1; i < overview.history.length; i++) ...<Widget>[
                  if (i > 1) const Divider(height: 1),
                  _HistoryRow(result: overview.history[i]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NextDrill extends StatelessWidget {
  const _NextDrill({
    required this.drill,
    required this.meetingPoint,
    required this.onReviewRoute,
    required this.isAdmin,
    required this.onCancel,
    this.onStart,
  });

  final Drill drill;
  final String? meetingPoint;
  final VoidCallback? onReviewRoute;
  final bool isAdmin;
  final VoidCallback onCancel;

  /// Coordinación lo inicia: se emite como alerta marcada de simulacro.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Pill('Próximo', tone: PillTone.brand),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Simulacro de ${drill.hazard.label.toLowerCase()}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.onBrand,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Fact(label: 'Fecha', value: Fmt.dayMonthShort(drill.scheduledAt)),
              _Fact(label: 'Hora', value: Fmt.hour(drill.scheduledAt)),
              if (meetingPoint != null) _Fact(label: 'Tu punto', value: meetingPoint!),
            ],
          ),
          if (drill.note != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(drill.note!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
          const SizedBox(height: AppSpacing.md),
          if (onReviewRoute != null)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                onTap: () {
                  Navigator.of(context).maybePop();
                  onReviewRoute!();
                },
                child: const SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      'Repasar mi ruta',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                ),
              ),
            ),
          if (isAdmin && onStart != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: InkWell(
                key: const Key('iniciar-simulacro'),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                onTap: onStart,
                child: const SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      'Iniciar simulacro',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (isAdmin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancelar simulacro', style: TextStyle(color: Colors.white70)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white60)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.onBrand,
          ),
        ),
      ],
    );
  }
}

class _LastResult extends StatelessWidget {
  const _LastResult({required this.result, required this.goalSeconds});

  final DrillResult result;
  final int goalSeconds;

  @override
  Widget build(BuildContext context) {
    final int? seconds = result.mySeconds;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_cap(result.hazard.label.toLowerCase())} · ${Fmt.dayMonth(result.at)}',
                      style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      seconds == null ? 'No confirmaste que estabas a salvo' : 'Llegaste al punto en',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (seconds != null)
                Text(
                  Fmt.minutesSeconds(seconds),
                  key: const Key('mi-tiempo'),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: result.onTime == true ? AppColors.success : AppColors.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: result.schoolPercent / 100,
              minHeight: 6,
              color: AppColors.success,
              backgroundColor: AppColors.surfaceAlt,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'El ${result.schoolPercent} % del colegio confirmó a salvo en menos de '
            '${goalSeconds ~/ 60} min. Meta: 100 %.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  static String _cap(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.result});

  final DrillResult result;

  @override
  Widget build(BuildContext context) {
    final int? seconds = result.mySeconds;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${result.hazard.label[0]}${result.hazard.label.substring(1).toLowerCase()} · '
                  '${Fmt.dayMonth(result.at)}',
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 13),
                ),
                Text(
                  seconds == null ? 'Sin confirmar' : 'Tu tiempo: ${Fmt.minutesSeconds(seconds)}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (result.onTime != null)
            Pill(
              result.onTime! ? 'A tiempo' : 'Mejorable',
              tone: result.onTime! ? PillTone.success : PillTone.warning,
            ),
        ],
      ),
    );
  }
}

/// Programar un simulacro: amenaza, fecha, hora y una nota opcional.
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet();

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  Hazard _hazard = Hazard.sismo;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime at = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Programar un simulacro', style: AppTextStyles.screenTitle),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final Hazard hazard in Hazard.values)
                  ChoiceChip(
                    label: Text(hazard.label),
                    selected: _hazard == hazard,
                    onSelected: (_) => setState(() => _hazard = hazard),
                    selectedColor: AppColors.brandSoft,
                    side: BorderSide(
                      color: _hazard == hazard ? AppColors.brand : AppColors.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(Fmt.dayMonth(_date)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(Fmt.hour(at)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: const Key('guardar-simulacro'),
              label: 'Programar',
              icon: null,
              onPressed: () => Navigator.of(context).pop(
                (hazard: _hazard, at: at, note: _note.text.trim().isEmpty ? null : _note.text.trim()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
