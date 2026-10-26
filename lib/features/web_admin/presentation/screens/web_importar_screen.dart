import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../panel/domain/community_admin.dart';
import '../../../panel/domain/student_list_parser.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';
import 'web_usuarios_screen.dart';

/// Importar estudiantes: se pega la lista desde Excel o el SIMAT, se revisa y se
/// crean los códigos. Todo o nada: si una fila está mal, no se crea ninguna.
class WebImportarScreen extends StatefulWidget {
  const WebImportarScreen({super.key});

  @override
  State<WebImportarScreen> createState() => _WebImportarScreenState();
}

class _WebImportarScreenState extends State<WebImportarScreen> {
  final TextEditingController _text = TextEditingController();
  bool _busy = false;
  String? _error;
  CodeBatch? _result;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  StudentListResult? get _parsed => _text.text.trim().isEmpty ? null : StudentListParser.parse(_text.text);

  Future<void> _import(List<NewStudent> students) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final CodeBatch batch = await AppScope.of(context).panelRepository!.importStudents(students);
      if (mounted) setState(() => _result = batch);
    } on PanelActionFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'importar estudiantes (panel web)');
      if (mounted) setState(() => _error = 'No se pudo importar la lista. No se creó ninguna persona.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CodeBatch? result = _result;
    if (result != null) return _Done(result: result);

    final StudentListResult? parsed = _parsed;
    final bool ok = parsed != null && parsed.error == null && parsed.students.isNotEmpty;

    return WebPageFrame(
      title: 'Importar estudiantes',
      subtitle: 'Pega la lista, revisa y crea los códigos',
      actions: const <Widget>[WebBackButton(label: 'Cancelar')],
      children: <Widget>[
        WebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              WebPanelHeader(
                title: 'Columnas de la lista',
                subtitle: 'Nombre · Grupo · Documento · Acudiente · Documento del acudiente (de la tercera en adelante son opcionales). Hasta ${StudentListParser.maxStudents} por carga.',
              ),
              const SizedBox(height: 14),
              WebTextArea(
                controller: _text,
                minLines: 10,
                hint: 'Valentina Rojas\t9° B\t1004321\tSandra Rojas\t52123456',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: WebButton(
                  label: 'Pegar del portapapeles',
                  secondary: true,
                  small: true,
                  icon: Icons.content_paste,
                  onPressed: () async {
                    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) setState(() => _text.text = data!.text!);
                  },
                ),
              ),
            ],
          ),
        ),
        if (parsed != null)
          WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (parsed.error != null)
                  WebNotice(parsed.error!, icon: Icons.error_outline, tone: WebChipTone.brand)
                else ...<Widget>[
                  WebGrid(minWidth: 240, children: <Widget>[
                    WebStat(label: 'Estudiantes a crear', value: '${parsed.students.length}', valueColor: WebColors.good),
                    WebStat(
                      label: 'Con acudiente',
                      value: '${parsed.students.where((NewStudent s) => s.guardianName != null).length}',
                    ),
                  ]),
                  const SizedBox(height: 14),
                  WebTable(
                    headers: const <String>['Nombre', 'Curso', 'Documento', 'Acudiente'],
                    rows: <List<Widget>>[
                      for (final NewStudent s in parsed.students.take(8))
                        <Widget>[Text(s.fullName), Text(s.grade), Text(s.document ?? '—'), Text(s.guardianName ?? '—')],
                    ],
                  ),
                  if (parsed.students.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('… y ${parsed.students.length - 8} más.', style: WebText.small),
                    ),
                ],
                if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: WebButton(
                    label: ok ? 'Importar ${parsed.students.length} y crear códigos' : 'Importar',
                    busy: _busy,
                    onPressed: ok ? () => _import(parsed.students) : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.result});

  final CodeBatch result;

  String _tsv() => <String>[
        'Nombre\tRol\tCurso\tCódigo',
        for (final IssuedCode c in result.codes) '${c.fullName}\t${webRoleLabel(c.role)}\t${c.grade ?? ''}\t${c.code}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    return WebPageFrame(
      title: 'Importación lista',
      subtitle: '${result.codes.length} códigos creados',
      actions: <Widget>[
        WebButton(
          label: 'Copiar la lista de códigos',
          secondary: true,
          icon: Icons.copy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _tsv()));
            if (context.mounted) webToast(context, 'Copiada: pégala en una hoja de cálculo');
          },
        ),
        WebButton(label: 'Ir a usuarios', onPressed: () => WebNav.of(context).go(WebPage.usuarios)),
      ],
      children: <Widget>[
        const WebNotice('Los códigos completos solo se ven ahora. Cópialos o imprímelos antes de salir.', tone: WebChipTone.warn),
        WebPanel(
          child: WebTable(
            headers: const <String>['Nombre', 'Rol', 'Curso', 'Código'],
            rows: <List<Widget>>[
              for (final IssuedCode c in result.codes)
                <Widget>[
                  Text(c.fullName),
                  Text(webRoleLabel(c.role)),
                  Text(c.grade ?? '—'),
                  Text(c.code, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                ],
            ],
          ),
        ),
      ],
    );
  }
}
