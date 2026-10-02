import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../onboarding/domain/person_name.dart';
import '../../../alerts/domain/meeting_point.dart';
import '../../domain/community_admin.dart';
import '../../domain/panel_repository.dart';
import 'admin_fields.dart';
import 'children_editor.dart';
import 'issued_secret_dialog.dart';

/// Abre la hoja para administrar a una persona de la comunidad.
///
/// Es una hoja y no una pantalla aparte: coordinación llega desde un listado de
/// cientos de personas y necesita volver exactamente donde estaba, con el filtro y
/// la búsqueda intactos.
Future<void> showPersonEditor(
  BuildContext context, {
  required CommunityMember member,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext context) =>
        _PersonEditor(member: member, onChanged: onChanged),
  );
}

/// Abre la hoja para crear la cuenta de un docente.
Future<void> showNewTeacherSheet(
  BuildContext context, {
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext context) => _NewTeacher(onChanged: onChanged),
  );
}

/* -------------------------------------------------------------------------- */

class _PersonEditor extends StatefulWidget {
  const _PersonEditor({required this.member, required this.onChanged});

  final CommunityMember member;
  final VoidCallback onChanged;

  @override
  State<_PersonEditor> createState() => _PersonEditorState();
}

class _PersonEditorState extends State<_PersonEditor> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _classroom = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _document = TextEditingController();

  PersonDetail? _person;
  List<GroupInfo> _groups = <GroupInfo>[];
  List<MeetingPoint> _points = <MeetingPoint>[];
  Set<String> _point = <String>{};
  List<ChildEntry> _children = <ChildEntry>[];

  String? _shift;
  Set<String> _grade = <String>{};
  Set<String> _homeroom = <String>{};
  Set<String> _teaches = <String>{};

  bool _started = false;
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  String? _notice;
  bool _noticeIsError = false;

  PanelRepository get _repository => AppScope.of(context).panelRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Una sola vez: esta hoja depende de `MediaQuery` (el teclado) y este método
    // se vuelve a llamar cada vez que el teclado sube o baja.
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    _classroom.dispose();
    _phone.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final PanelRepository repository = _repository;
      final List<Object> loaded = await Future.wait<Object>(<Future<Object>>[
        repository.loadPerson(widget.member.id),
        repository.loadGroups(),
        repository.loadMeetingPoints(),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = loaded[1] as List<GroupInfo>;
        _points = loaded[2] as List<MeetingPoint>;
        _fill(loaded[0] as PersonDetail);
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cargar persona');
      if (mounted) {
        setState(() {
          _loadError = error is PanelActionFailure
              ? error.message
              : 'No pudimos cargar a esta persona. Revisa la conexión.';
          _loading = false;
        });
      }
    }
  }

  /// Vuelve a pedir los grupos: quién dirige cada uno cambia al guardar. Sin
  /// esto, la hoja seguía avisando «hoy lo dirige Nubia» justo después de haberle
  /// quitado el grupo. Si falla, se queda con la lista que tenía: es un aviso, no
  /// un dato que se guarde.
  Future<void> _refreshGroups() async {
    try {
      final List<GroupInfo> fresh = await _repository.loadGroups();
      if (mounted) setState(() => _groups = fresh);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'refrescar grupos');
    }
  }

  /// Pone el formulario como lo dice el servidor. Se llama al cargar y después de
  /// cada cambio guardado: lo que se ve es siempre lo que quedó, no lo que se
  /// escribió.
  void _fill(PersonDetail person) {
    _person = person;
    _name.text = person.fullName;
    _email.text = person.email ?? '';
    _subject.text = person.subject ?? '';
    _classroom.text = person.classroom ?? '';
    _shift = person.shift;
    _phone.text = person.phone ?? '';
    _document.text = person.document ?? '';
    _point = <String>{if (person.meetingPoint != null) person.meetingPoint!};
    _children = <ChildEntry>[for (final LinkedPerson c in person.children) ChildEntry.fromLinked(c)];
    _grade = <String>{if (person.grade != null) person.grade!};
    _homeroom = <String>{if (person.homeroomGroup != null) person.homeroomGroup!};
    _teaches = person.groups.toSet();
  }

  void _say(String message, {bool error = false}) {
    setState(() {
      _notice = message;
      _noticeIsError = error;
    });
  }

  /// Corre una acción que cambia algo, con el indicador de ocupado y el mensaje
  /// del servidor si no se acepta.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } on PanelActionFailure catch (error) {
      if (mounted) _say(error.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'administrar persona');
      if (mounted) {
        _say(
          'No pudimos completar el cambio. Revisa la conexión e intenta otra vez.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PersonChanges? _collectChanges() {
    final PersonDetail person = _person!;

    String? changed(String current, String? original) =>
        current.trim() != (original ?? '') ? current.trim() : null;

    final String? name = changed(_name.text, person.fullName);

    if (person.role == 'estudiante') {
      final String? grade = _grade.isEmpty ? null : _grade.first;
      return PersonChanges(
        fullName: name,
        grade: grade != person.grade ? grade : null,
        shift: _shift != person.shift ? _shift : null,
        // El salón solo se manda si coordinación lo escribió. Si cambió el
        // grupo y no lo tocó, el servidor le pone el del grupo nuevo.
        classroom: changed(_classroom.text, person.classroom),
        document: changed(_document.text, person.document),
        meetingPoint: _point.isNotEmpty && _point.first != person.meetingPoint
            ? _point.first
            : null,
      );
    }

    if (person.role == 'docente') {
      final String? homeroom = _homeroom.isEmpty ? null : _homeroom.first;
      final bool groupsChanged =
          _teaches.length != person.groups.length || !_teaches.containsAll(person.groups);

      return PersonChanges(
        fullName: name,
        email: changed(_email.text, person.email),
        subject: changed(_subject.text, person.subject),
        homeroomGroup: homeroom != person.homeroomGroup ? homeroom : null,
        removeHomeroom: homeroom == null && person.homeroomGroup != null,
        groups: groupsChanged ? (_teaches.toList()..sort()) : null,
      );
    }

    // Acudiente.
    final bool childrenChanged = _children.length != person.children.length ||
        <String>{for (final ChildEntry c in _children) '${c.studentId}|${c.relationship}'}
            .difference(<String>{
          for (final LinkedPerson c in person.children) '${c.id}|${c.relationship}',
        }).isNotEmpty;

    return PersonChanges(
      fullName: name,
      phone: changed(_phone.text, person.phone),
      document: changed(_document.text, person.document),
      children: childrenChanged
          ? <ChildLink>[for (final ChildEntry c in _children) c.toLink()]
          : null,
    );
  }

  Future<void> _save() async {
    final PersonChanges changes = _collectChanges()!;
    if (changes.isEmpty) {
      _say('No hay cambios que guardar.');
      return;
    }

    await _run(() async {
      final PersonUpdate update =
          await _repository.updatePerson(_person!.id, changes);
      if (!mounted) return;

      setState(() => _fill(update.person));
      widget.onChanged();
      await _refreshGroups();

      final ReplacedDirector? replaced = update.replacedDirector;
      _say(
        replaced == null
            ? 'Cambios guardados.'
            : 'Cambios guardados. ${PersonName.short(replaced.person.fullName)} '
                'dejó de dirigir ${replaced.group}.',
      );
    });
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(),
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
            child: Text(action),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  Future<void> _renewCode() async {
    final PersonDetail person = _person!;
    final String who = PersonName.short(person.fullName);
    if (!await _confirm(
      '¿Emitir un código nuevo?',
      'Se revoca el código actual y se cierra la sesión de $who en sus '
          'celulares. Solo entra quien tenga el código nuevo.',
      'EMITIR',
    )) {
      return;
    }

    String? code;
    await _run(() async {
      code = await _repository.renewCode(person.id);
      final PersonDetail fresh = await _repository.loadPerson(person.id);
      if (!mounted) return;
      setState(() => _fill(fresh));
      widget.onChanged();
    });

    // Fuera de `_run`: mientras el diálogo está abierto, la hoja no debe seguir
    // mostrándose «ocupada» detrás.
    final String? issued = code;
    if (issued != null && mounted) {
      await showIssuedSecret(
        context,
        title: 'CÓDIGO NUEVO',
        person: person.fullName,
        secret: issued,
        instruction: 'Imprímelo en el carné o entrégalo en secretaría. Se usa '
            'una sola vez.',
      );
    }
  }

  Future<void> _resetPassword() async {
    final PersonDetail person = _person!;
    final String who = PersonName.short(person.fullName);
    if (!await _confirm(
      '¿Restablecer la contraseña?',
      'La contraseña actual de $who deja de servir y se cierran sus sesiones '
          'abiertas. Se genera una temporal que debes entregarle.',
      'RESTABLECER',
    )) {
      return;
    }

    String? password;
    await _run(() async {
      password = await _repository.resetTeacherPassword(person.id);
      final PersonDetail fresh = await _repository.loadPerson(person.id);
      if (!mounted) return;
      setState(() => _fill(fresh));
      widget.onChanged();
    });

    final String? issued = password;
    if (issued != null && mounted) {
      await showIssuedSecret(
        context,
        title: 'CONTRASEÑA TEMPORAL',
        person: person.fullName,
        secret: issued,
        instruction: 'Entrégasela por un medio privado. Al entrar debe cambiarla '
            'desde Cuenta → Cambiar contraseña.',
      );
    }
  }

  Future<void> _closeSessions() async {
    final PersonDetail person = _person!;
    final String who = PersonName.short(person.fullName);
    if (!await _confirm(
      '¿Cerrar sus sesiones?',
      '$who tendrá que volver a entrar en todos sus celulares, y los celulares '
          'registrados dejan de recibir avisos. Úsalo si perdió el teléfono.',
      'CERRAR SESIONES',
    )) {
      return;
    }

    await _run(() async {
      await _repository.closeSessions(person.id);
      if (mounted) _say('Sesiones cerradas.');
    });
  }

  Future<void> _delete() async {
    final PersonDetail person = _person!;
    final String who = PersonName.short(person.fullName);
    final String history = person.role == 'estudiante'
        ? ' También se borran sus respuestas a alertas pasadas.'
        : '';
    if (!await _confirm(
      '¿Eliminar a $who?',
      'Se borra su cuenta, su código, sus celulares y sus vínculos.$history '
          'No se puede deshacer.${person.role == 'docente' ? ' Si emitió alertas, '
              'el servidor no lo permite: en ese caso se le da de baja.' : ''}',
      'ELIMINAR',
    )) {
      return;
    }

    bool deleted = false;
    await _run(() async {
      await _repository.deletePerson(person.id);
      deleted = true;
      widget.onChanged();
    });

    if (deleted && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deactivate() async {
    final PersonDetail person = _person!;
    final String who = PersonName.short(person.fullName);
    if (!await _confirm(
      '¿Dar de baja a $who?',
      'Ya no podrá entrar y deja de figurar en los grupos que dicta o dirige. Su '
          'historial se conserva. Para que vuelva: asígnale grupos y restablece '
          'su contraseña.',
      'DAR DE BAJA',
    )) {
      return;
    }

    await _run(() async {
      final PersonDetail off = await _repository.deactivateTeacher(person.id);
      if (!mounted) return;
      setState(() => _fill(off));
      widget.onChanged();
      await _refreshGroups();
      _say('$who ya no tiene acceso.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final PersonDetail? person = _person;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetHeader(
            title: person?.fullName ?? widget.member.fullName,
            subtitle: person == null
                ? _roleLabel(widget.member.role)
                : '${_roleLabel(person.role)} · ${_accessLabel(person)}',
          ),
          const Divider(height: 1),
          // Una línea que avanza mientras el servidor trabaja: los botones de
          // credenciales no giran, y sin esto no se vería que algo está pasando.
          if (_busy) const LinearProgressIndicator(minHeight: 2, color: AppColors.brand),
          Flexible(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    ),
                  )
                : _loadError != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(_loadError!, style: AppTextStyles.body),
                            const SizedBox(height: AppSpacing.md),
                            SheetButton(label: 'REINTENTAR', onTap: _load),
                          ],
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.sm,
                          AppSpacing.xl,
                          AppSpacing.xl,
                        ),
                        children: <Widget>[
                          if (_notice != null)
                            InlineNotice(_notice!, isError: _noticeIsError),
                          ..._form(person!),
                          ..._credentials(person),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _form(PersonDetail person) {
    if (person.role == 'administrador') {
      return <Widget>[
        const FormSection('Cuenta de coordinación'),
        Text(
          'Las cuentas de coordinación no se administran desde el panel: se '
          'crean y cambian directamente en el servidor.',
          style: AppTextStyles.body,
        ),
      ];
    }

    return <Widget>[
      const FormSection('Datos'),
      AdminTextField(label: 'Nombre completo', controller: _name, maxLength: 120),
      if (person.role == 'estudiante') ...<Widget>[
        const FormSection(
          'Grupo',
          hint: 'Al cambiarlo, el estudiante hereda el salón y el director del '
              'grupo nuevo.',
        ),
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
        AdminTextField(label: 'Salón', controller: _classroom, maxLength: 60),
        AdminTextField(label: 'Documento', controller: _document, maxLength: 20),
        if (_points.isNotEmpty) ...<Widget>[
          const FormSection('Punto de encuentro'),
          MeetingPointPicker(
            points: _points,
            selected: _point,
            onChanged: (Set<String> value) => setState(() => _point = value),
          ),
        ],
        const FormSection(
          'Acudientes',
          hint: 'Los vincula coordinación desde la hoja de cada acudiente.',
        ),
        if (person.guardians.isEmpty)
          Text('Sin acudientes vinculados.', style: AppTextStyles.caption)
        else
          for (final LinkedPerson guardian in person.guardians)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${guardian.fullName} · ${guardian.relationship}',
                style: AppTextStyles.body,
              ),
            ),
      ],
      if (person.role == 'acudiente') ...<Widget>[
        AdminTextField(
          label: 'Celular',
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 20,
        ),
        AdminTextField(label: 'Documento', controller: _document, maxLength: 20),
        const FormSection(
          'Estudiantes a su cargo',
          hint: 'Recibe el aviso cuando uno de ellos pide ayuda.',
        ),
        ChildrenEditor(
          children: _children,
          onChanged: (List<ChildEntry> value) => setState(() => _children = value),
        ),
      ],
      if (person.role == 'docente') ...<Widget>[
        AdminTextField(
          label: 'Correo con el que entra',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          maxLength: 160,
        ),
        AdminTextField(label: 'Materia', controller: _subject, maxLength: 60),
        const FormSection(
          'Director de grupo',
          hint: 'Un grupo tiene un solo director. Quien lo recibe, reemplaza al '
              'anterior.',
        ),
        GroupPicker.single(
          groups: _groups,
          selected: _homeroom,
          allowNone: true,
          onChanged: (Set<String> value) => setState(() {
            _homeroom = value;
            // El director siempre dicta en su grupo: se marca solo.
            _teaches = <String>{..._teaches, ...value};
          }),
        ),
        if (_takenBy(person) case final PersonRef other)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'Hoy lo dirige ${other.fullName}. Al guardar, dejará de dirigirlo.',
              style: AppTextStyles.caption.copyWith(color: AppColors.brand),
            ),
          ),
        const FormSection('Grupos que dicta'),
        GroupPicker.multiple(
          groups: _groups,
          selected: _teaches,
          onChanged: (Set<String> value) => setState(() => _teaches = value),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      Align(
        alignment: Alignment.centerLeft,
        child: SheetButton(
          label: 'GUARDAR CAMBIOS',
          filled: true,
          busy: _busy,
          onTap: _save,
        ),
      ),
    ];
  }

  /// Quién dirige hoy el grupo elegido, si no es esta misma persona.
  PersonRef? _takenBy(PersonDetail person) {
    if (_homeroom.isEmpty) return null;
    for (final GroupInfo group in _groups) {
      if (group.grade == _homeroom.first &&
          group.director != null &&
          group.director!.id != person.id) {
        return group.director;
      }
    }
    return null;
  }

  List<Widget> _credentials(PersonDetail person) {
    if (person.role == 'administrador') {
      return const <Widget>[];
    }

    final bool teacher = person.role == 'docente';

    return <Widget>[
      FormSection(
        'Credenciales',
        hint: teacher
            ? 'Los docentes entran con correo y contraseña. La contraseña la '
                'elige el servidor y se muestra una sola vez.'
            : 'Entra con el código del carné, de un solo uso. '
                '${person.codeHint == null ? 'Todavía no tiene código.' : person.access == 'vencido' ? 'Su código venció: emite uno nuevo.' : 'Código actual: ${person.code ?? '${person.codeHint}••'}'}',
      ),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          if (teacher)
            SheetButton(
              label: person.access == 'sin_acceso'
                  ? 'DAR ACCESO (CONTRASEÑA NUEVA)'
                  : 'RESTABLECER CONTRASEÑA',
              onTap: _busy ? null : _resetPassword,
            )
          else
            SheetButton(
              label: 'EMITIR CÓDIGO NUEVO',
              onTap: _busy ? null : _renewCode,
            ),
          SheetButton(
            label: 'CERRAR SESIONES',
            onTap: _busy ? null : _closeSessions,
          ),
          if (teacher && person.access != 'sin_acceso')
            SheetButton(
              label: 'DAR DE BAJA',
              destructive: true,
              onTap: _busy ? null : _deactivate,
            ),
          SheetButton(
            label: 'ELIMINAR',
            destructive: true,
            onTap: _busy ? null : _delete,
          ),
        ],
      ),
      if (teacher && person.access == 'sin_acceso')
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            'Sin acceso. Para que vuelva, asígnale al menos un grupo y dale '
            'acceso con una contraseña nueva.',
            style: AppTextStyles.caption,
          ),
        ),
    ];
  }

  static String _roleLabel(String role) => switch (role) {
        'estudiante' => 'Estudiante',
        'docente' => 'Docente',
        'acudiente' => 'Acudiente',
        'administrador' => 'Coordinación',
        _ => role,
      };

  static String _accessLabel(PersonDetail person) => switch (person.access) {
        'con_cuenta' => 'con cuenta',
        'sin_acceso' => 'sin acceso',
        'usado' => 'activo en la app',
        'pendiente' => 'código pendiente',
        'entregado' => 'código sin usar',
        'vencido' => 'código vencido',
        'revocado' => 'código revocado',
        _ => 'sin código',
      };
}

/* -------------------------------------------------------------------------- */

class _NewTeacher extends StatefulWidget {
  const _NewTeacher({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_NewTeacher> createState() => _NewTeacherState();
}

class _NewTeacherState extends State<_NewTeacher> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _subject = TextEditingController();

  List<GroupInfo> _groups = <GroupInfo>[];
  Set<String> _homeroom = <String>{};
  Set<String> _teaches = <String>{};

  bool _loadedGroups = false;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedGroups) {
      _loadedGroups = true;
      _loadGroups();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final List<GroupInfo> groups =
          await AppScope.of(context).panelRepository!.loadGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (error, stack) {
      // Sin la lista se puede seguir: «+ OTRO» deja escribir los grupos.
      ErrorReporter.report(error, stack, context: 'grupos del colegio');
    }
  }

  Future<void> _create() async {
    if (_busy) return;

    final String name = _name.text.trim();
    final String email = _email.text.trim();
    final String subject = _subject.text.trim();

    // Solo lo que se puede decir sin preguntarle al servidor. Lo demás (correo
    // repetido, grupo inválido) lo dice el servidor, que es quien lo sabe.
    if (name.split(RegExp(r'\s+')).length < 2) {
      setState(() => _error = 'Escribe el nombre y al menos un apellido.');
      return;
    }
    if (!email.contains('@') || email.length < 5) {
      setState(() => _error = 'Escribe el correo con el que va a entrar.');
      return;
    }
    if (subject.isEmpty) {
      setState(() => _error = 'Escribe la materia que dicta.');
      return;
    }
    if (_homeroom.isEmpty && _teaches.isEmpty) {
      setState(() => _error = 'Elige al menos un grupo.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final NavigatorState navigator = Navigator.of(context);
    CreatedTeacher? created;
    try {
      created = await AppScope.of(context).panelRepository!.createTeacher(
            NewTeacher(
              fullName: name,
              email: email,
              subject: subject,
              homeroomGroup: _homeroom.isEmpty ? null : _homeroom.first,
              groups: _teaches.toList()..sort(),
            ),
          );
      widget.onChanged();
    } on PanelActionFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'crear docente');
      if (mounted) {
        setState(
          () => _error = 'No pudimos crear la cuenta. Revisa la conexión e '
              'intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    final CreatedTeacher? done = created;
    if (done == null || !mounted) return;

    // Con el indicador ya apagado: el diálogo es lo único que debe llamar la
    // atención ahora.
    final ReplacedDirector? replaced = done.replacedDirector;
    final String replacedNote = replaced == null
        ? ''
        : ' ${PersonName.short(replaced.person.fullName)} dejó de dirigir '
            '${replaced.group}.';
    await showIssuedSecret(
      context,
      title: 'CONTRASEÑA TEMPORAL',
      person: done.person.fullName,
      secret: done.temporaryPassword,
      instruction: 'Entra con ${done.person.email}. Entrégasela por un medio '
          'privado y que la cambie al entrar, desde Cuenta → Cambiar '
          'contraseña.$replacedNote',
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SheetHeader(title: 'Nuevo docente', subtitle: 'Cuenta de acceso'),
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
                if (_error != null) InlineNotice(_error!),
                AdminTextField(label: 'Nombre completo', controller: _name, maxLength: 120),
                AdminTextField(
                  label: 'Correo con el que entra',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 160,
                ),
                AdminTextField(label: 'Materia', controller: _subject, maxLength: 60),
                const FormSection(
                  'Director de grupo',
                  hint: 'Opcional. Si el grupo ya tiene director, lo reemplaza.',
                ),
                GroupPicker.single(
                  groups: _groups,
                  selected: _homeroom,
                  allowNone: true,
                  onChanged: (Set<String> value) => setState(() {
                    _homeroom = value;
                    _teaches = <String>{..._teaches, ...value};
                  }),
                ),
                const FormSection('Grupos que dicta'),
                GroupPicker.multiple(
                  groups: _groups,
                  selected: _teaches,
                  onChanged: (Set<String> value) => setState(() => _teaches = value),
                ),
                const FormSection(
                  'Contraseña',
                  hint: 'La elige el servidor y se muestra una sola vez al crear '
                      'la cuenta.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SheetButton(
                    label: 'CREAR CUENTA',
                    filled: true,
                    busy: _busy,
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
