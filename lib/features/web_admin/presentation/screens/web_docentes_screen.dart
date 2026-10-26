import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';
import 'web_grupos_screen.dart';
import 'web_usuarios_screen.dart';

/// Docentes y personal: a cada uno se le asigna el grupo que dirige y los que
/// dicta. La app del docente se arma con esto.
class WebDocentesScreen extends StatefulWidget {
  const WebDocentesScreen({super.key});

  @override
  State<WebDocentesScreen> createState() => _WebDocentesScreenState();
}

class _WebDocentesScreenState extends State<WebDocentesScreen> {
  final TextEditingController _search = TextEditingController();
  late Future<(List<CommunityMember>, List<GroupInfo>)> _data;
  bool _onlyDirectors = false;
  bool _started = false;

  PanelRepository get _repo => AppScope.of(context).panelRepository!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _data = () async {
        final List<CommunityMember> teachers = await _repo.loadCommunity(role: 'docente');
        final List<GroupInfo> groups = await _repo.loadGroups();
        return (teachers, groups);
      }();
    });
  }

  Future<void> _add(List<GroupInfo> groups) async {
    final bool? created = await showDialog<bool>(context: context, builder: (_) => _NewTeacherDialog(groups: groups));
    if (created == true) _reload();
  }

  Future<void> _edit(CommunityMember m, List<GroupInfo> groups) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditTeacherDialog(member: m, groups: groups),
    );
    if (saved == true) {
      if (mounted) webToast(context, 'Cambios guardados');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebFuture<(List<CommunityMember>, List<GroupInfo>)>(
      future: _data,
      onRetry: _reload,
      builder: (BuildContext context, (List<CommunityMember>, List<GroupInfo>) data) {
        final List<CommunityMember> teachers = data.$1;
        final List<GroupInfo> groups = data.$2;
        final Map<String, GroupInfo> directing = <String, GroupInfo>{
          for (final GroupInfo g in groups)
            if (g.director != null) g.director!.id: g,
        };
        final String q = _search.text.trim().toLowerCase();
        final List<CommunityMember> shown = teachers.where((CommunityMember t) {
          if (_onlyDirectors && !directing.containsKey(t.id)) return false;
          if (q.isEmpty) return true;
          return t.fullName.toLowerCase().contains(q) || (directing[t.id]?.grade.toLowerCase().contains(q) ?? false);
        }).toList();
        final int withoutDirector = groups.where((GroupInfo g) => g.director == null).length;

        return WebPageFrame(
          title: 'Docentes y grupos',
          subtitle: 'Asigna a cada docente su grupo. La app del docente se arma con esto.',
          actions: <Widget>[
            WebButton(label: 'Ver grupos', secondary: true, onPressed: () => nav.open(const WebGruposScreen())),
            WebButton(label: 'Agregar docente', icon: Icons.add, onPressed: () => _add(groups)),
          ],
          children: <Widget>[
            WebGrid(children: <Widget>[
              WebStat(label: 'Docentes y personal', value: '${teachers.length}'),
              WebStat(label: 'Grupos con director', value: '${groups.length - withoutDirector} de ${groups.length}'),
              WebStat(label: 'Sin acceso a la app', value: '${teachers.where((CommunityMember t) => t.codeStatus == 'sin_acceso').length}'),
              WebStat(
                label: 'Grupos sin director',
                value: '$withoutDirector',
                valueColor: withoutDirector > 0 ? WebColors.brand : WebColors.ink,
              ),
            ]),
            WebPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: <Widget>[
                    WebSearchBox(controller: _search, hint: 'Buscar docente o grupo', onChanged: (_) => setState(() {})),
                    WebOption(label: 'Todos', selected: !_onlyDirectors, onTap: () => setState(() => _onlyDirectors = false)),
                    WebOption(label: 'Directores', selected: _onlyDirectors, onTap: () => setState(() => _onlyDirectors = true)),
                  ]),
                  const SizedBox(height: 8),
                  WebTable(
                    headers: const <String>['Docente', 'Grupo a cargo', 'Correo', 'App', ''],
                    empty: 'No hay docentes con ese filtro.',
                    rows: <List<Widget>>[
                      for (final CommunityMember t in shown)
                        <Widget>[
                          Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                            WebAvatar(t.fullName),
                            const SizedBox(width: 10),
                            Text(t.fullName, style: WebText.strong),
                          ]),
                          directing.containsKey(t.id)
                              ? WebChip('Director · ${directing[t.id]!.grade}', tone: WebChipTone.dark)
                              : const Text('—'),
                          Text(t.linkedTo ?? '—'),
                          WebChip(webCodeStatus(t.codeStatus).$1, tone: webCodeStatus(t.codeStatus).$2),
                          WebButton(label: 'Editar', secondary: true, small: true, onPressed: () => _edit(t, groups)),
                        ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NewTeacherDialog extends StatefulWidget {
  const _NewTeacherDialog({required this.groups});

  final List<GroupInfo> groups;

  @override
  State<_NewTeacherDialog> createState() => _NewTeacherDialogState();
}

class _NewTeacherDialogState extends State<_NewTeacherDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  String? _homeroom;
  final Set<String> _groups = <String>{};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _subject.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty || _subject.text.trim().isEmpty) {
      setState(() => _error = 'Nombre, correo y materia son obligatorios.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final CreatedTeacher created = await AppScope.of(context).panelRepository!.createTeacher(
            NewTeacher(
              fullName: _name.text.trim(),
              email: _email.text.trim().toLowerCase(),
              subject: _subject.text.trim(),
              homeroomGroup: _homeroom,
              groups: _groups.toList(),
            ),
          );
      if (!mounted) return;
      await showIssuedCode(context, name: '${created.person.fullName} · contraseña temporal', code: created.temporaryPassword);
      if (mounted) Navigator.of(context).pop(true);
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'crear docente (panel web)');
      if (mounted) setState(() => _error = 'No se pudo crear la cuenta.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar docente'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            WebField(label: 'Nombre completo', controller: _name),
            const SizedBox(height: 14),
            WebField(label: 'Correo institucional', controller: _email, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),
            WebField(label: 'Materia', controller: _subject),
            const SizedBox(height: 14),
            WebSelect<String?>(
              label: 'Director del grupo',
              value: _homeroom,
              items: <String?, String>{null: 'Ninguno', for (final GroupInfo g in widget.groups) g.grade: g.grade},
              onChanged: (String? v) => setState(() => _homeroom = v),
            ),
            const SizedBox(height: 14),
            Text('Grupos que dicta', style: WebText.label),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              for (final GroupInfo g in widget.groups)
                WebOption(
                  label: g.grade,
                  selected: _groups.contains(g.grade),
                  onTap: () => setState(() => _groups.contains(g.grade) ? _groups.remove(g.grade) : _groups.add(g.grade)),
                ),
            ]),
            if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
          ]),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        TextButton(onPressed: _busy ? null : _create, child: Text(_busy ? 'CREANDO…' : 'CREAR CUENTA')),
      ],
    );
  }
}

class _EditTeacherDialog extends StatefulWidget {
  const _EditTeacherDialog({required this.member, required this.groups});

  final CommunityMember member;
  final List<GroupInfo> groups;

  @override
  State<_EditTeacherDialog> createState() => _EditTeacherDialogState();
}

class _EditTeacherDialogState extends State<_EditTeacherDialog> {
  PersonDetail? _person;
  final TextEditingController _subject = TextEditingController();
  String? _homeroom;
  Set<String> _groups = <String>{};
  bool _busy = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AppScope.of(context).panelRepository!.loadPerson(widget.member.id).then((PersonDetail p) {
      if (!mounted) return;
      setState(() {
        _person = p;
        _subject.text = p.subject ?? '';
        _homeroom = p.homeroomGroup;
        _groups = p.groups.toSet();
      });
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report(e, s, context: 'cargar docente (panel web)');
      if (mounted) setState(() => _error = 'No pudimos cargar al docente.');
    });
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final PersonDetail p = _person!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PersonUpdate update = await AppScope.of(context).panelRepository!.updatePerson(
            p.id,
            PersonChanges(
              subject: _subject.text.trim() == (p.subject ?? '') ? null : _subject.text.trim(),
              homeroomGroup: _homeroom != p.homeroomGroup ? _homeroom : null,
              removeHomeroom: _homeroom == null && p.homeroomGroup != null,
              groups: _groups.toList(),
            ),
          );
      if (update.replacedDirector != null && mounted) {
        webToast(context, '${update.replacedDirector!.person.fullName} dejó de dirigir ${update.replacedDirector!.group}');
      }
      if (mounted) Navigator.of(context).pop(true);
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'editar docente (panel web)');
      if (mounted) setState(() => _error = 'No se pudieron guardar los cambios.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.member.fullName),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _person == null
            ? WebLoadState(error: _error)
            : SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  WebField(label: 'Materia', controller: _subject),
                  const SizedBox(height: 14),
                  WebSelect<String?>(
                    label: 'Director del grupo',
                    value: _homeroom,
                    items: <String?, String>{null: 'Ninguno', for (final GroupInfo g in widget.groups) g.grade: g.grade},
                    onChanged: (String? v) => setState(() => _homeroom = v),
                  ),
                  const SizedBox(height: 14),
                  Text('Grupos que dicta', style: WebText.label),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                    for (final GroupInfo g in widget.groups)
                      WebOption(
                        label: g.grade,
                        selected: _groups.contains(g.grade),
                        onTap: () => setState(() => _groups.contains(g.grade) ? _groups.remove(g.grade) : _groups.add(g.grade)),
                      ),
                  ]),
                  if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
                ]),
              ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
        TextButton(onPressed: _busy || _person == null ? null : _save, child: Text(_busy ? 'GUARDANDO…' : 'GUARDAR')),
      ],
    );
  }
}
