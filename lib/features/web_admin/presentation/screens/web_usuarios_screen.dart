import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';
import 'web_importar_screen.dart';
import 'web_usuario_detalle_screen.dart';

/// Texto de un rol del servidor.
String webRoleLabel(String role) => switch (role) {
      'estudiante' => 'Estudiante',
      'acudiente' => 'Acudiente',
      'docente' => 'Docente',
      'administrador' => 'Administrador',
      _ => role,
    };

/// Estado de un código, con el color de su insignia.
(String, WebChipTone) webCodeStatus(String status) => switch (status) {
      'usado' || 'con_cuenta' => ('Activo', WebChipTone.good),
      'pendiente' || 'entregado' => ('Sin usar', WebChipTone.neutral),
      'vencido' => ('Vencido', WebChipTone.warn),
      'revocado' => ('Revocado', WebChipTone.brand),
      'sin_acceso' => ('Sin acceso', WebChipTone.brand),
      'sin_generar' => ('Sin código', WebChipTone.warn),
      _ => (status, WebChipTone.neutral),
    };

/// Muestra un código recién emitido: es la única vez que se ve completo.
Future<void> showIssuedCode(BuildContext context, {required String name, required String code}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Código nuevo'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(name, style: WebText.strong),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(color: WebColors.page, borderRadius: BorderRadius.circular(12)),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Es de un solo uso y no se vuelve a mostrar completo. Entrégalo en persona o imprímelo ahora.',
              style: WebText.small,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) webToast(context, 'Código copiado');
          },
          child: const Text('COPIAR'),
        ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('LISTO')),
      ],
    ),
  );
}

/// Usuarios y códigos: toda la comunidad, con el estado de su acceso.
class WebUsuariosScreen extends StatefulWidget {
  const WebUsuariosScreen({super.key});

  @override
  State<WebUsuariosScreen> createState() => _WebUsuariosScreenState();
}

class _WebUsuariosScreenState extends State<WebUsuariosScreen> {
  static const int _pageSize = 25;

  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String? _role;
  String? _grade;
  int _page = 0;

  late Future<List<CommunityMember>> _members;
  late Future<CommunityStats> _stats;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final PanelRepository repo = AppScope.of(context).panelRepository!;
    setState(() {
      _page = 0;
      _members = repo.loadCommunity(role: _role, query: _search.text);
      _stats = repo.loadStats();
    });
  }

  Future<void> _renew(CommunityMember m) async {
    final bool ok = await webConfirm(
      context,
      title: 'Reemitir el código',
      message: 'El código actual de ${m.fullName} deja de servir y se genera uno nuevo.',
      confirm: 'Reemitir',
    );
    if (!ok || !mounted) return;
    try {
      final String code = await AppScope.of(context).panelRepository!.renewCode(m.id);
      if (!mounted) return;
      await showIssuedCode(context, name: m.fullName, code: code);
      _reload();
    } on PanelActionFailure catch (f) {
      if (mounted) webToast(context, f.message, error: true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reemitir código (panel web)');
      if (mounted) webToast(context, 'No se pudo reemitir el código.', error: true);
    }
  }

  Future<void> _generate() async {
    final bool? done = await showDialog<bool>(context: context, builder: (_) => const _GenerateCodesDialog());
    if (done == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Usuarios y códigos',
      subtitle: 'Cada persona recibe un código personal de un solo uso',
      actions: <Widget>[
        WebButton(
          label: 'Importar lista',
          secondary: true,
          icon: Icons.upload_outlined,
          onPressed: () => nav.open(const WebImportarScreen()),
        ),
        WebButton(label: 'Generar códigos', icon: Icons.add, onPressed: _generate),
      ],
      children: <Widget>[
        WebFuture<CommunityStats>(
          future: _stats,
          onRetry: _reload,
          builder: (BuildContext context, CommunityStats s) => WebGrid(children: <Widget>[
            WebStat(label: 'Personas', value: '${s.total}'),
            WebStat(label: 'Accesos activos', value: '${s.activeCodes}', valueColor: WebColors.good),
            WebStat(label: 'Códigos sin usar', value: '${s.pendingCodes}', valueColor: WebColors.warnText),
            WebStat(label: 'Estudiantes', value: '${s.byRole['estudiante'] ?? 0}'),
          ]),
        ),
        WebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  WebSearchBox(
                    controller: _search,
                    hint: 'Buscar por nombre o documento',
                    onChanged: (_) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 350), _reload);
                    },
                  ),
                  for (final (String?, String) f in <(String?, String)>[
                    (null, 'Todos'),
                    ('estudiante', 'Estudiantes'),
                    ('acudiente', 'Acudientes'),
                    ('docente', 'Docentes'),
                    ('administrador', 'Administradores'),
                  ])
                    WebOption(
                      label: f.$2,
                      selected: _role == f.$1,
                      onTap: () {
                        _role = f.$1;
                        _grade = null;
                        _reload();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              WebFuture<List<CommunityMember>>(
                future: _members,
                onRetry: _reload,
                builder: (BuildContext context, List<CommunityMember> all) {
                  final List<String> grades = <String>{
                    for (final CommunityMember m in all)
                      if (m.grade != null && m.grade!.isNotEmpty) m.grade!,
                  }.toList()
                    ..sort();
                  final List<CommunityMember> list =
                      _grade == null ? all : all.where((CommunityMember m) => m.grade == _grade).toList();
                  final int pages = (list.length / _pageSize).ceil().clamp(1, 1 << 20);
                  final int page = _page.clamp(0, pages - 1);
                  final List<CommunityMember> shown = list.skip(page * _pageSize).take(_pageSize).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (grades.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: WebSelect<String?>(
                            width: 200,
                            value: _grade,
                            items: <String?, String>{null: 'Todos los cursos', for (final String g in grades) g: g},
                            onChanged: (String? v) => setState(() {
                              _grade = v;
                              _page = 0;
                            }),
                          ),
                        ),
                      WebTable(
                        headers: const <String>['Nombre', 'Rol', 'Curso', 'Código', 'Estado', ''],
                        empty: 'No hay personas con ese filtro.',
                        rows: <List<Widget>>[
                          for (final CommunityMember m in shown)
                            <Widget>[
                              Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                                WebAvatar(m.fullName),
                                const SizedBox(width: 10),
                                WebTitleSub(
                                  m.fullName,
                                  onTap: () => nav.open(WebUsuarioDetalleScreen(personId: m.id)),
                                ),
                              ]),
                              Text(webRoleLabel(m.role)),
                              Text(m.grade ?? m.linkedTo ?? '—'),
                              Text(m.codeLabel ?? '—', style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
                              WebChip(webCodeStatus(m.codeStatus).$1, tone: webCodeStatus(m.codeStatus).$2),
                              if (m.role == 'estudiante' || m.role == 'acudiente')
                                WebButton(label: 'Reemitir', secondary: true, small: true, onPressed: () => _renew(m))
                              else
                                const SizedBox.shrink(),
                            ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            list.isEmpty ? '' : 'Mostrando ${page * _pageSize + 1}–${page * _pageSize + shown.length} de ${list.length}',
                            style: WebText.small,
                          ),
                          Row(children: <Widget>[
                            WebButton(label: 'Anterior', secondary: true, small: true, onPressed: page == 0 ? null : () => setState(() => _page = page - 1)),
                            const SizedBox(width: 8),
                            WebButton(label: 'Siguiente', secondary: true, small: true, onPressed: page >= pages - 1 ? null : () => setState(() => _page = page + 1)),
                          ]),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Emitir códigos a varios cursos de una vez.
class _GenerateCodesDialog extends StatefulWidget {
  const _GenerateCodesDialog();

  @override
  State<_GenerateCodesDialog> createState() => _GenerateCodesDialogState();
}

class _GenerateCodesDialogState extends State<_GenerateCodesDialog> {
  final Set<String> _grades = <String>{};
  bool _guardians = true;
  bool _reissue = false;
  bool _busy = false;
  String? _error;
  CodeBatch? _result;
  List<GroupInfo>? _groups;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AppScope.of(context).panelRepository!.loadGroups().then((List<GroupInfo> g) {
      if (mounted) setState(() => _groups = g);
    }).catchError((Object e, StackTrace s) {
      ErrorReporter.report(e, s, context: 'grupos (generar códigos web)');
      if (mounted) setState(() => _error = 'No pudimos cargar los cursos.');
    });
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final CodeBatch batch = await AppScope.of(context).panelRepository!.generateCodes(
            grades: _grades.toList(),
            includeGuardians: _guardians,
            reissue: _reissue,
          );
      if (mounted) setState(() => _result = batch);
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'generar códigos (panel web)');
      if (mounted) setState(() => _error = 'No se pudieron generar los códigos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _tsv(CodeBatch b) => <String>[
        'Nombre\tRol\tCurso\tCódigo',
        for (final IssuedCode c in b.codes) '${c.fullName}\t${webRoleLabel(c.role)}\t${c.grade ?? ''}\t${c.code}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final CodeBatch? result = _result;
    return AlertDialog(
      title: Text(result == null ? 'Generar códigos' : '${result.codes.length} códigos generados'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: result != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const WebNotice('Es la única vez que se ven completos. Cópialos o imprímelos ahora.', tone: WebChipTone.warn),
                  if (result.alreadyRegistered > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${result.alreadyRegistered} personas ya se habían registrado y se omitieron.', style: WebText.small),
                    ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: WebTable(
                        headers: const <String>['Nombre', 'Curso', 'Código'],
                        rows: <List<Widget>>[
                          for (final IssuedCode c in result.codes)
                            <Widget>[
                              Text(c.fullName),
                              Text(c.grade ?? '—'),
                              Text(c.code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Cursos', style: WebText.label),
                    const SizedBox(height: 8),
                    if (_groups == null && _error == null)
                      const WebLoadState()
                    else
                      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                        for (final GroupInfo g in _groups ?? const <GroupInfo>[])
                          WebOption(
                            label: g.grade,
                            selected: _grades.contains(g.grade),
                            onTap: () => setState(() => _grades.contains(g.grade) ? _grades.remove(g.grade) : _grades.add(g.grade)),
                          ),
                      ]),
                    const SizedBox(height: 16),
                    WebToggleRow(title: 'Incluir a los acudientes', subtitle: 'Un código para cada acudiente de esos cursos', value: _guardians, onChanged: (bool v) => setState(() => _guardians = v)),
                    const SizedBox(height: 12),
                    WebToggleRow(title: 'Reemitir los que no se han usado', subtitle: 'Revoca el código anterior y genera otro', value: _reissue, onChanged: (bool v) => setState(() => _reissue = v)),
                    if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        if (result != null) ...<Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _tsv(result)));
              if (context.mounted) webToast(context, 'Lista copiada: pégala en una hoja de cálculo');
            },
            child: const Text('COPIAR LISTA'),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('LISTO')),
        ] else ...<Widget>[
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: _busy || _grades.isEmpty ? null : _run,
            child: Text(_busy ? 'GENERANDO…' : 'GENERAR'),
          ),
        ],
      ],
    );
  }
}
