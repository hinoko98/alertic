import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';
import 'web_usuarios_screen.dart';

/// La ficha de una persona: sus datos, cómo entra a la app y las acciones que
/// coordinación puede hacer sobre ella.
class WebUsuarioDetalleScreen extends StatefulWidget {
  const WebUsuarioDetalleScreen({required this.personId, super.key});

  final String personId;

  @override
  State<WebUsuarioDetalleScreen> createState() => _WebUsuarioDetalleScreenState();
}

class _WebUsuarioDetalleScreenState extends State<WebUsuarioDetalleScreen> {
  late Future<PersonDetail> _person;
  bool _started = false;

  PanelRepository get _repo => AppScope.of(context).panelRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() => setState(() => _person = _repo.loadPerson(widget.personId));

  /// Hace una acción del panel y le cuenta a la persona cómo salió.
  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) webToast(context, done);
      _reload();
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'acción sobre persona (panel web)');
      if (mounted) webToast(context, 'No se pudo completar la acción.', error: true);
    }
  }

  Future<void> _renew(PersonDetail p) async {
    final bool ok = await webConfirm(
      context,
      title: 'Reemitir el código',
      message: 'El código actual de ${p.fullName} deja de servir y se genera uno nuevo.',
      confirm: 'Reemitir',
    );
    if (!ok || !mounted) return;
    try {
      final String code = await _repo.renewCode(p.id);
      if (!mounted) return;
      await showIssuedCode(context, name: p.fullName, code: code);
      _reload();
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reemitir código (detalle web)');
      if (mounted) webToast(context, 'No se pudo reemitir el código.', error: true);
    }
  }

  Future<void> _resetPassword(PersonDetail p) async {
    final bool ok = await webConfirm(
      context,
      title: 'Restablecer la contraseña',
      message: 'Se genera una contraseña temporal para ${p.fullName} y se cierran sus sesiones.',
      confirm: 'Restablecer',
    );
    if (!ok || !mounted) return;
    try {
      final String password = await _repo.resetTeacherPassword(p.id);
      if (!mounted) return;
      await showIssuedCode(context, name: '${p.fullName} · contraseña temporal', code: password);
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    }
  }

  Future<void> _edit(PersonDetail p) async {
    final bool? saved = await showDialog<bool>(context: context, builder: (_) => _EditDialog(person: p));
    if (saved == true) {
      if (mounted) webToast(context, 'Cambios guardados');
      _reload();
    }
  }

  Future<void> _delete(PersonDetail p) async {
    final bool ok = await webConfirm(
      context,
      title: 'Eliminar a ${p.fullName}',
      message: 'Se borra de la comunidad. Si tiene historial que debe conservarse, el sistema lo impide.',
      confirm: 'Eliminar',
      danger: true,
    );
    if (!ok || !mounted) return;
    final WebNav nav = WebNav.of(context);
    try {
      await _repo.deletePerson(p.id);
      nav.back();
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'eliminar persona (panel web)');
      if (mounted) webToast(context, 'No se pudo eliminar.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebFuture<PersonDetail>(
      future: _person,
      onRetry: _reload,
      errorText: 'No pudimos cargar a esta persona.',
      builder: (BuildContext context, PersonDetail p) {
        final (String statusLabel, WebChipTone statusTone) = webCodeStatus(p.access);
        final bool isStudent = p.role == 'estudiante';
        return WebPageFrame(
          title: p.fullName,
          subtitle: <String>[
            webRoleLabel(p.role),
            if (p.grade != null) p.grade!,
            if (p.shift != null) 'Jornada ${p.shift!.toLowerCase()}',
          ].join(' · '),
          actions: <Widget>[
            const WebBackButton(),
            WebButton(label: 'Editar', onPressed: () => _edit(p)),
          ],
          children: <Widget>[
            WebGrid(minWidth: 300, children: <Widget>[
              WebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const WebPanelHeader(title: 'Datos'),
                    const SizedBox(height: 8),
                    if (p.document != null) WebKeyValue('Documento', p.document!),
                    if (p.email != null) WebKeyValue('Correo', p.email!),
                    if (p.phone != null) WebKeyValue('Celular', p.phone!),
                    if (p.grade != null) WebKeyValue('Curso', p.grade!),
                    if (p.classroom != null) WebKeyValue('Salón', p.classroom!),
                    if (p.subject != null) WebKeyValue('Materia', p.subject!),
                    if (p.homeroomGroup != null) WebKeyValue('Director de grupo', p.homeroomGroup!),
                    if (p.groups.isNotEmpty) WebKeyValue('Grupos que dicta', p.groups.join(', ')),
                    if (p.meetingPoint != null) WebKeyValue('Punto de encuentro', p.meetingPoint!),
                  ],
                ),
              ),
              WebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const WebPanelHeader(title: 'Acceso a la app'),
                    const SizedBox(height: 12),
                    if (!p.usesPassword)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: WebColors.page, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          p.code ?? (p.codeHint == null ? 'Sin código' : '${p.codeHint}••'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2),
                        ),
                      ),
                    const SizedBox(height: 12),
                    WebChip(statusLabel, tone: statusTone),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                      if (!p.usesPassword) WebButton(label: 'Reemitir código', secondary: true, small: true, onPressed: () => _renew(p)),
                      if (p.role == 'docente') WebButton(label: 'Restablecer contraseña', secondary: true, small: true, onPressed: () => _resetPassword(p)),
                      WebButton(
                        label: 'Cerrar sesiones',
                        secondary: true,
                        small: true,
                        onPressed: () => _run(() => _repo.closeSessions(p.id), 'Se cerraron sus sesiones y se borraron sus celulares'),
                      ),
                      if (p.role == 'docente' && p.access == 'con_cuenta')
                        WebButton(
                          label: 'Dar de baja',
                          secondary: true,
                          small: true,
                          onPressed: () => _run(() async => _repo.deactivateTeacher(p.id), 'Se le quitó el acceso'),
                        ),
                    ]),
                  ],
                ),
              ),
              WebPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    WebPanelHeader(title: isStudent ? 'Acudientes' : 'Estudiantes a cargo'),
                    const SizedBox(height: 12),
                    if ((isStudent ? p.guardians : p.children).isEmpty)
                      Text(isStudent ? 'Sin acudientes vinculados.' : 'Sin estudiantes vinculados.', style: WebText.small)
                    else
                      for (final LinkedPerson l in isStudent ? p.guardians : p.children)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: <Widget>[
                            WebAvatar(l.fullName),
                            const SizedBox(width: 10),
                            Expanded(child: WebTitleSub(l.fullName, sub: <String>[l.relationship, if (l.grade != null) l.grade!].join(' · '))),
                            WebChip('Vinculado', tone: WebChipTone.good),
                          ]),
                        ),
                  ],
                ),
              ),
            ]),
            WebPanel(
              borderColor: WebColors.brandSoft,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Eliminar de la comunidad', style: WebText.strong),
                        Text('Úsalo para errores de matrícula. Quien tiene historial se da de baja en vez de borrarse.', style: WebText.small),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  WebButton(label: 'Eliminar', secondary: true, onPressed: () => _delete(p)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Edita lo que se puede corregir de una persona sin cambiar quién es.
class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.person});

  final PersonDetail person;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.person.fullName);
  late final TextEditingController _phone = TextEditingController(text: widget.person.phone ?? '');
  late final TextEditingController _document = TextEditingController(text: widget.person.document ?? '');
  late String? _grade = widget.person.grade;
  List<GroupInfo> _groups = const <GroupInfo>[];
  bool _busy = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.person.role == 'estudiante') {
      AppScope.of(context).panelRepository!.loadGroups().then((List<GroupInfo> g) {
        if (mounted) setState(() => _groups = g);
      }).catchError((Object e, StackTrace s) {
        ErrorReporter.report(e, s, context: 'grupos (editar persona web)');
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _document.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final PersonDetail p = widget.person;
    String? changed(String value, String? old) => value.trim() == (old ?? '') ? null : value.trim();

    final PersonChanges changes = PersonChanges(
      fullName: changed(_name.text, p.fullName),
      phone: changed(_phone.text, p.phone),
      document: changed(_document.text, p.document),
      grade: _grade != p.grade ? _grade : null,
    );
    if (changes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).panelRepository!.updatePerson(p.id, changes);
      if (mounted) Navigator.of(context).pop(true);
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'editar persona (panel web)');
      if (mounted) setState(() => _error = 'No se pudieron guardar los cambios.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar persona'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              WebField(label: 'Nombre completo', controller: _name),
              const SizedBox(height: 14),
              WebField(label: 'Documento', controller: _document),
              const SizedBox(height: 14),
              WebField(label: 'Celular', controller: _phone, keyboardType: TextInputType.phone),
              if (widget.person.role == 'estudiante' && _groups.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                WebSelect<String?>(
                  label: 'Curso',
                  value: _grade,
                  items: <String?, String>{for (final GroupInfo g in _groups) g.grade: g.grade},
                  onChanged: (String? v) => setState(() => _grade = v),
                ),
              ],
              if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        TextButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'GUARDANDO…' : 'GUARDAR')),
      ],
    );
  }
}
