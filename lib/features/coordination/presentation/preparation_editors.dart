import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../onboarding/domain/enrollment.dart';
import '../../onboarding/domain/person_name.dart';
import '../../panel/domain/panel_repository.dart';
import '../../panel/presentation/widgets/admin_fields.dart';
import '../domain/coordination_repository.dart';

/// Lo que coordinación deja preparado en la ficha de cada persona, para que en
/// la emergencia nadie tenga que improvisarlo.
///
/// Cada editor carga y guarda por su cuenta, aparte del «Guardar cambios» de la
/// ficha: es otra cosa, con su propia ruta en el servidor, y un error en una no
/// debe impedir la otra.
class EmergencyPreparation extends StatelessWidget {
  const EmergencyPreparation({required this.personId, required this.role, this.grade, super.key});

  final String personId;
  final String role;
  final String? grade;

  @override
  Widget build(BuildContext context) {
    if (AppScope.of(context).coordinationRepository == null) return const SizedBox.shrink();
    return switch (role) {
      'docente' => _TeacherTaskEditor(teacherId: personId),
      'estudiante' => _SupportBuddiesEditor(studentId: personId, grade: grade),
      _ => const SizedBox.shrink(),
    };
  }
}

String _failure(Object error) => error is ApiException && error.statusCode != null
    ? error.message
    : 'No se pudo guardar. Intenta otra vez.';

/* -------------------------------------------------------------------------- */

/// «Tu tarea en una emergencia»: lo que ve el docente en su inicio y en la alerta.
class _TeacherTaskEditor extends StatefulWidget {
  const _TeacherTaskEditor({required this.teacherId});

  final String teacherId;

  @override
  State<_TeacherTaskEditor> createState() => _TeacherTaskEditorState();
}

class _TeacherTaskEditorState extends State<_TeacherTaskEditor> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _detail = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  bool _hasTask = false;
  String? _notice;
  bool _noticeIsError = false;
  bool _started = false;

  CoordinationRepository get _repository => AppScope.of(context).coordinationRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final EmergencyTask? task = await _repository.loadEmergencyTask(widget.teacherId);
      if (!mounted) return;
      setState(() {
        _hasTask = task != null;
        _title.text = task?.title ?? '';
        _detail.text = task?.detail ?? '';
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'tarea del docente');
      if (mounted) setState(() => _notice = 'No pudimos traer su tarea.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _notice = done;
          _noticeIsError = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'tarea del docente');
      if (mounted) {
        setState(() {
          _notice = _failure(error);
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final String title = _title.text.trim();
    // Lo mismo que exige el servidor, dicho antes de mandarlo.
    if (title.length < 3) {
      setState(() {
        _notice = 'Escribe qué le toca hacer (al menos 3 letras).';
        _noticeIsError = true;
      });
      return;
    }
    final String detail = _detail.text.trim();
    await _run(() async {
      await _repository.saveEmergencyTask(
        widget.teacherId,
        EmergencyTask(title: title, detail: detail.isEmpty ? null : detail),
      );
      _hasTask = true;
    }, 'Tarea guardada. La verá en su inicio y en la alerta.');
  }

  Future<void> _clear() async {
    await _run(() async {
      await _repository.clearEmergencyTask(widget.teacherId);
      _title.clear();
      _detail.clear();
      _hasTask = false;
    }, 'Tarea quitada. En la alerta verá el punto de encuentro.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('preparacion-docente'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const FormSection(
          'Su tarea en una emergencia',
          hint: 'La ve en su inicio y en la alerta roja. Sin tarea, ve el punto de '
              'encuentro de la alerta.',
        ),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2, color: AppColors.brand)
        else ...<Widget>[
          if (_notice != null) InlineNotice(_notice!, isError: _noticeIsError),
          AdminTextField(label: 'Qué le toca', controller: _title, maxLength: 80, enabled: !_busy),
          AdminTextField(label: 'Cómo (opcional)', controller: _detail, maxLength: 120, enabled: !_busy),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              SheetButton(label: 'GUARDAR TAREA', filled: true, busy: _busy, onTap: _busy ? null : _save),
              if (_hasTask) SheetButton(label: 'QUITAR', destructive: true, onTap: _busy ? null : _clear),
            ],
          ),
        ],
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */

/// Quién va por un estudiante que necesita apoyo para evacuar.
class _SupportBuddiesEditor extends StatefulWidget {
  const _SupportBuddiesEditor({required this.studentId, this.grade});

  final String studentId;
  final String? grade;

  @override
  State<_SupportBuddiesEditor> createState() => _SupportBuddiesEditorState();
}

class _SupportBuddiesEditorState extends State<_SupportBuddiesEditor> {
  SupportPlan? _plan;
  bool _busy = false;
  String? _notice;
  bool _started = false;

  CoordinationRepository get _repository => AppScope.of(context).coordinationRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    try {
      final SupportPlan plan = await _repository.loadSupportPlan(widget.studentId);
      if (mounted) setState(() => _plan = plan);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'compañeros de apoyo');
      if (mounted) setState(() => _notice = 'No pudimos traer sus compañeros de apoyo.');
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
      await _load();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'compañeros de apoyo');
      if (mounted) setState(() => _notice = _failure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final PanelRepository? panel = AppScope.of(context).panelRepository;
    if (panel == null) return;
    final CommunityMember? buddy = await showDialog<CommunityMember>(
      context: context,
      builder: (BuildContext context) => _BuddyPicker(
        panel: panel,
        studentId: widget.studentId,
        grade: widget.grade,
        taken: <String>{for (final SupportBuddy b in _plan?.buddies ?? const <SupportBuddy>[]) b.id},
      ),
    );
    if (buddy == null || !mounted) return;
    await _change(() => _repository.addSupportBuddy(widget.studentId, buddy.id));
  }

  @override
  Widget build(BuildContext context) {
    final SupportPlan? plan = _plan;
    return Column(
      key: const Key('preparacion-estudiante'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FormSection(
          'Apoyo para evacuar',
          hint: plan?.needLabel == null
              ? 'No ha pedido apoyo. Igual puedes asignarle compañeros que vayan por él.'
              : 'Pidió apoyo: ${plan!.needLabel}. Sus compañeros lo ven en la alerta.',
        ),
        if (_notice != null) InlineNotice(_notice!),
        if (plan == null && _notice == null)
          const LinearProgressIndicator(minHeight: 2, color: AppColors.brand)
        else if (plan != null) ...<Widget>[
          if (plan.buddies.isEmpty)
            const Text('Sin compañeros de apoyo.', style: AppTextStyles.caption)
          else
            for (final SupportBuddy buddy in plan.buddies)
              Row(
                key: Key('companero-${buddy.id}'),
                children: <Widget>[
                  Expanded(
                    child: Text(
                      buddy.grade == null ? buddy.fullName : '${buddy.fullName} · ${buddy.grade}',
                      style: AppTextStyles.body,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar',
                    onPressed: _busy
                        ? null
                        : () => _change(() => _repository.removeSupportBuddy(widget.studentId, buddy.id)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
          const SizedBox(height: AppSpacing.sm),
          SheetButton(label: 'AGREGAR COMPAÑERO', busy: _busy, onTap: _busy ? null : _add),
        ],
      ],
    );
  }
}

/// Busca a un estudiante para ir por otro. Primero los de su mismo grupo, que son
/// los que están en el salón con él.
class _BuddyPicker extends StatefulWidget {
  const _BuddyPicker({required this.panel, required this.studentId, required this.taken, this.grade});

  final PanelRepository panel;
  final String studentId;
  final String? grade;
  final Set<String> taken;

  @override
  State<_BuddyPicker> createState() => _BuddyPickerState();
}

class _BuddyPickerState extends State<_BuddyPicker> {
  final TextEditingController _query = TextEditingController();
  List<CommunityMember> _results = const <CommunityMember>[];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(_search(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    try {
      final List<CommunityMember> people =
          await widget.panel.loadCommunity(role: 'estudiante', query: query.trim());
      final List<CommunityMember> usable = people
          .where((CommunityMember p) => p.id != widget.studentId && !widget.taken.contains(p.id))
          .toList()
        ..sort((CommunityMember a, CommunityMember b) {
          final bool aSame = a.grade == widget.grade;
          final bool bSame = b.grade == widget.grade;
          if (aSame != bSame) return aSame ? -1 : 1;
          return a.fullName.compareTo(b.fullName);
        });
      if (mounted) setState(() => _results = usable.take(20).toList());
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'buscar compañero');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar compañero de apoyo'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: <Widget>[
            TextField(
              key: const Key('buscar-companero'),
              controller: _query,
              decoration: const InputDecoration(hintText: 'Nombre o documento', prefixIcon: Icon(Icons.search)),
              onChanged: (String value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                children: <Widget>[
                  for (final CommunityMember person in _results)
                    ListTile(
                      key: Key('elegir-companero-${person.id}'),
                      dense: true,
                      title: Text(PersonName.short(person.fullName), style: AppTextStyles.itemTitle),
                      subtitle: Text(person.grade ?? 'Sin grupo', style: AppTextStyles.caption),
                      onTap: () => Navigator.of(context).pop(person),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR')),
      ],
    );
  }
}
