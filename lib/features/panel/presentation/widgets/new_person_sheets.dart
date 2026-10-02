import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../domain/community_admin.dart';
import '../../domain/panel_repository.dart';
import 'admin_fields.dart';
import 'children_editor.dart';
import 'issued_secret_dialog.dart';

/// Hoja para dar de alta a un estudiante.
Future<void> showNewStudentSheet(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  return _open(context, _NewStudent(onChanged: onChanged));
}

/// Hoja para dar de alta a un acudiente.
Future<void> showNewGuardianSheet(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  return _open(context, _NewGuardian(onChanged: onChanged));
}

Future<void> _open(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext context) => child,
  );
}

/// Lo común de las dos hojas: cargar lo que necesitan, mostrar un error en línea
/// y entregar el código al terminar.
mixin _CreateFlow<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? error;

  PanelRepository get repository => AppScope.of(context).panelRepository!;

  /// Corre el alta. Si sale bien, avisa para recargar el listado y muestra el
  /// código **una sola vez**; después cierra la hoja.
  Future<void> run({
    required Future<CreatedPerson> Function() create,
    required VoidCallback onChanged,
    required String instruction,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });

    final NavigatorState navigator = Navigator.of(context);
    CreatedPerson? created;
    try {
      created = await create();
      onChanged();
    } on PanelActionFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'dar de alta');
      if (mounted) {
        setState(
          () => error = 'No pudimos completar el alta. Revisa la conexión e '
              'intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }

    final CreatedPerson? done = created;
    if (done == null || !mounted) return;

    await showIssuedSecret(
      context,
      title: 'CÓDIGO NUEVO',
      person: done.person.fullName,
      secret: done.code,
      instruction: instruction,
    );
    navigator.pop();
  }
}

/* -------------------------------------------------------------------------- */

class _NewStudent extends StatefulWidget {
  const _NewStudent({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_NewStudent> createState() => _NewStudentState();
}

class _NewStudentState extends State<_NewStudent> with _CreateFlow<_NewStudent> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _classroom = TextEditingController();
  final TextEditingController _document = TextEditingController();

  List<GroupInfo> _groups = <GroupInfo>[];
  List<MeetingPoint> _points = <MeetingPoint>[];
  Set<String> _grade = <String>{};
  Set<String> _point = <String>{};
  String _shift = 'Mañana';
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadChoices();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _classroom.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _loadChoices() async {
    try {
      final List<GroupInfo> groups = await repository.loadGroups();
      final List<MeetingPoint> points = await repository.loadMeetingPoints();
      if (mounted) {
        setState(() {
          _groups = groups;
          _points = points;
        });
      }
    } catch (e, stack) {
      // Sin las listas se puede seguir: «+ OTRO» deja escribir el grupo, y sin
      // punto el servidor asigna el principal.
      ErrorReporter.report(e, stack, context: 'opciones del alta');
    }
  }

  Future<void> _create() async {
    final String name = _name.text.trim();
    if (name.split(RegExp(r'\s+')).length < 2) {
      setState(() => error = 'Escribe el nombre y al menos un apellido.');
      return;
    }
    if (_grade.isEmpty) {
      setState(() => error = 'Elige el grupo del estudiante.');
      return;
    }

    final String classroom = _classroom.text.trim();
    final String document = _document.text.trim();

    await run(
      create: () => repository.createStudent(
        NewStudent(
          fullName: name,
          grade: _grade.first,
          shift: _shift,
          classroom: classroom.isEmpty ? null : classroom,
          document: document.isEmpty ? null : document,
          meetingPoint: _point.isEmpty ? null : _point.first,
        ),
      ),
      onChanged: widget.onChanged,
      instruction: 'Imprímelo en el carné o entrégalo en secretaría. Se usa una '
          'sola vez.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHeader(title: 'Nuevo estudiante', subtitle: 'Matrícula'),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: <Widget>[
                if (error != null) InlineNotice(error!),
                AdminTextField(label: 'Nombre completo', controller: _name, maxLength: 120),
                const FormSection('Grupo'),
                GroupPicker.single(
                  groups: _groups,
                  selected: _grade,
                  onChanged: (Set<String> value) => setState(() => _grade = value),
                ),
                const FormSection('Jornada'),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final String shift in const <String>['Mañana', 'Tarde'])
                      ChoiceBox(
                        label: shift.toUpperCase(),
                        selected: _shift == shift,
                        onTap: () => setState(() => _shift = shift),
                      ),
                  ],
                ),
                AdminTextField(
                  label: 'Salón (opcional: si no, el del grupo)',
                  controller: _classroom,
                  maxLength: 60,
                ),
                AdminTextField(
                  label: 'Documento (opcional)',
                  controller: _document,
                  maxLength: 20,
                ),
                if (_points.isNotEmpty) ...<Widget>[
                  const FormSection(
                    'Punto de encuentro',
                    hint: 'Si no eliges uno, recibe el principal del colegio.',
                  ),
                  MeetingPointPicker(
                    points: _points,
                    selected: _point,
                    onChanged: (Set<String> value) => setState(() => _point = value),
                  ),
                ],
                const FormSection(
                  'Código',
                  hint: 'Se genera al darlo de alta y se muestra una sola vez.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SheetButton(
                    label: 'DAR DE ALTA',
                    filled: true,
                    busy: busy,
                    onTap: _create,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */

class _NewGuardian extends StatefulWidget {
  const _NewGuardian({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_NewGuardian> createState() => _NewGuardianState();
}

class _NewGuardianState extends State<_NewGuardian> with _CreateFlow<_NewGuardian> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _document = TextEditingController();

  List<ChildEntry> _children = <ChildEntry>[];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final String name = _name.text.trim();
    if (name.split(RegExp(r'\s+')).length < 2) {
      setState(() => error = 'Escribe el nombre y al menos un apellido.');
      return;
    }

    final String phone = _phone.text.trim();
    final String document = _document.text.trim();

    await run(
      create: () => repository.createGuardian(
        NewGuardian(
          fullName: name,
          phone: phone.isEmpty ? null : phone,
          document: document.isEmpty ? null : document,
          children: <ChildLink>[for (final ChildEntry c in _children) c.toLink()],
        ),
      ),
      onChanged: widget.onChanged,
      instruction: 'Entrégaselo a la familia. Se usa una sola vez, y con él ve el '
          'estado de sus hijos durante una alerta.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHeader(title: 'Nuevo acudiente', subtitle: 'Matrícula'),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: <Widget>[
                if (error != null) InlineNotice(error!),
                AdminTextField(label: 'Nombre completo', controller: _name, maxLength: 120),
                AdminTextField(
                  label: 'Celular (opcional)',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  maxLength: 20,
                ),
                AdminTextField(
                  label: 'Documento (opcional)',
                  controller: _document,
                  maxLength: 20,
                ),
                FormSection(
                  'Estudiantes a su cargo',
                  hint: 'Recibe el aviso cuando uno de ellos pide ayuda. Se buscan '
                      'en la matrícula.',
                ),
                ChildrenEditor(
                  children: _children,
                  onChanged: (List<ChildEntry> value) => setState(() => _children = value),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Si el estudiante todavía no está en la matrícula, dalo de alta '
                  'primero.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SheetButton(
                    label: 'DAR DE ALTA',
                    filled: true,
                    busy: busy,
                    onTap: _create,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
