import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/community_admin.dart';
import '../../domain/panel_repository.dart';
import '../../domain/student_list_parser.dart';
import 'admin_fields.dart';

/// Carga y emisión de códigos en bloque.
///
/// Las dos terminan en la misma lista de códigos, que se ve **una sola vez**: el
/// servidor solo guarda su hash. Por eso la lista ofrece copiarla completa antes
/// de cerrar, y no se cierra tocando fuera.

/// Pega una lista de estudiantes y los da de alta con su código.
Future<void> showImportStudents(
  BuildContext context, {
  required VoidCallback onChanged,
}) async {
  final CodeBatch? batch = await showDialog<CodeBatch>(
    context: context,
    builder: (BuildContext context) => const _ImportDialog(),
  );
  if (batch == null) return;

  onChanged();
  if (!context.mounted) return;
  await showCodeBatch(context, title: 'ESTUDIANTES CARGADOS', batch: batch);
}

/// Escoge uno o varios grupos y emite los códigos de todos.
Future<void> showGroupCodes(
  BuildContext context, {
  required VoidCallback onChanged,
}) async {
  final CodeBatch? batch = await showDialog<CodeBatch>(
    context: context,
    builder: (BuildContext context) => const _GroupCodesDialog(),
  );
  if (batch == null) return;

  onChanged();
  if (!context.mounted) return;
  await showCodeBatch(context, title: 'CÓDIGOS GENERADOS', batch: batch);
}

/// La lista de códigos recién emitidos, para imprimir los carnés.
Future<void> showCodeBatch(
  BuildContext context, {
  required String title,
  required CodeBatch batch,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) => _BatchDialog(title: title, batch: batch),
  );
}

/* -------------------------------------------------------------------------- */

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final StudentListResult parsed = StudentListParser.parse(_text.text);
    if (parsed.error != null) {
      setState(() => _error = parsed.error);
      return;
    }

    final PanelRepository repository = AppScope.of(context).panelRepository!;
    final NavigatorState navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final CodeBatch batch = await repository.importStudents(parsed.students);
      navigator.pop(batch);
    } on PanelActionFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'cargar estudiantes');
      if (mounted) {
        setState(
          () => _error = 'No pudimos cargar la lista. Revisa la conexión e '
              'intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      title: const Text('CARGAR ESTUDIANTES'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Pega una línea por estudiante: nombre completo, grupo y, si los '
                'tienes, su documento y el nombre y documento de su acudiente. '
                'Sirve pegar desde Excel o el SIMAT.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ana María Torres Ruiz; 9° A; 1020304050; Rosa Ruiz Díaz; 63111222',
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('lista-estudiantes'),
                controller: _text,
                minLines: 8,
                maxLines: 14,
                enabled: !_busy,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'Nombre; Grupo; Documento; Acudiente; Documento del acudiente',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Todo o nada: si una línea está mal no se carga ninguna, y se '
                'te dice cuál corregir. Máximo ${StudentListParser.maxStudents} '
                'por vez.',
                style: AppTextStyles.caption,
              ),
              if (_error != null) InlineNotice(_error!),
              if (_busy) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(color: AppColors.brand),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: _busy ? null : _import,
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          child: const Text('CARGAR'),
        ),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */

class _GroupCodesDialog extends StatefulWidget {
  const _GroupCodesDialog();

  @override
  State<_GroupCodesDialog> createState() => _GroupCodesDialogState();
}

class _GroupCodesDialogState extends State<_GroupCodesDialog> {
  List<GroupInfo>? _groups;
  Set<String> _selected = <String>{};
  bool _includeGuardians = false;
  bool _reissue = false;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_groups == null) {
      _loadGroups();
    }
  }

  Future<void> _loadGroups() async {
    try {
      final List<GroupInfo> groups =
          await AppScope.of(context).panelRepository!.loadGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'grupos para códigos');
      if (mounted) {
        setState(() {
          _groups = const <GroupInfo>[];
          _error = 'No pudimos traer los grupos. Cierra e intenta otra vez.';
        });
      }
    }
  }

  Future<void> _generate() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Elige al menos un grupo.');
      return;
    }

    final PanelRepository repository = AppScope.of(context).panelRepository!;
    final NavigatorState navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final CodeBatch batch = await repository.generateCodes(
        grades: _selected.toList(),
        includeGuardians: _includeGuardians,
        reissue: _reissue,
      );
      navigator.pop(batch);
    } on PanelActionFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (e, stack) {
      ErrorReporter.report(e, stack, context: 'generar códigos');
      if (mounted) {
        setState(
          () => _error = 'No pudimos generar los códigos. Revisa la conexión e '
              'intenta otra vez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<GroupInfo>? groups = _groups;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      title: const Text('CÓDIGOS POR GRUPO'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Elige los grupos. Se genera el código de cada estudiante que '
                'todavía no tiene uno o cuyo código venció (pasó una hora sin '
                'usarlo).',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              if (groups == null)
                const LinearProgressIndicator(color: AppColors.brand)
              else if (groups.isEmpty && _error == null)
                Text(
                  'Todavía no hay grupos. Carga estudiantes primero.',
                  style: AppTextStyles.caption,
                )
              else
                GroupPicker.multiple(
                  groups: groups,
                  selected: _selected,
                  onChanged: (Set<String> next) => setState(() => _selected = next),
                ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                key: const Key('incluir-acudientes'),
                value: _includeGuardians,
                onChanged: _busy
                    ? null
                    : (bool? value) => setState(() => _includeGuardians = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Incluir a los acudientes de esos estudiantes'),
              ),
              CheckboxListTile(
                key: const Key('reemplazar-sin-usar'),
                value: _reissue,
                onChanged: _busy
                    ? null
                    : (bool? value) => setState(() => _reissue = value ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Reemplazar también los códigos vigentes sin usar'),
                subtitle: Text(
                  'Los anteriores dejan de servir. A quien ya se registró no se '
                  'le toca. A quien tiene el código vencido siempre se le genera '
                  'otro.',
                  style: AppTextStyles.caption,
                ),
              ),
              if (_error != null) InlineNotice(_error!),
              if (_busy) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const LinearProgressIndicator(color: AppColors.brand),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: _busy ? null : _generate,
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          child: const Text('GENERAR'),
        ),
      ],
    );
  }
}

/* -------------------------------------------------------------------------- */

class _BatchDialog extends StatefulWidget {
  const _BatchDialog({required this.title, required this.batch});

  final String title;
  final CodeBatch batch;

  @override
  State<_BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<_BatchDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.batch.toTable()));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final CodeBatch batch = widget.batch;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              batch.codes.isEmpty
                  ? 'No había a quién emitirle un código.'
                  : batch.codes.length == 1
                      ? '1 código nuevo.'
                      : '${batch.codes.length} códigos nuevos.',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
            ),
            if (batch.alreadyRegistered > 0)
              Text(
                '${batch.alreadyRegistered} ya se registraron y no se tocaron.',
                style: AppTextStyles.caption,
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.visibility_off_outlined, size: 14, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Cada código vale una hora. Copia la lista antes de cerrar.',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  border: Border.all(color: AppColors.border),
                ),
                // Columna y no ListView: el diálogo mide su contenido por dentro
                // y un ListView no sabe decir cuánto mide. Son unas decenas de
                // filas, un grupo; no hace falta que sean perezosas.
                child: SingleChildScrollView(
                  key: const Key('codigos-emitidos'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int i = 0; i < batch.codes.length; i++) ...<Widget>[
                        if (i > 0) const Divider(height: 1),
                        _CodeRow(issued: batch.codes[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (batch.codes.isNotEmpty)
          TextButton(
            key: const Key('copiar-todo'),
            onPressed: _copy,
            child: Text(_copied ? 'COPIADA' : 'COPIAR TODO'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          child: const Text('LISTO'),
        ),
      ],
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.issued});

  final IssuedCode issued;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              issued.grade == null
                  ? issued.fullName
                  : '${issued.fullName} · ${issued.grade}',
              style: AppTextStyles.body,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SelectableText(
            issued.code,
            style: AppTextStyles.code.copyWith(fontSize: 15, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}
