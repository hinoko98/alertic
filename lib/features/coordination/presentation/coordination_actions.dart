import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../alerts/domain/alert.dart';
import '../../onboarding/domain/person_name.dart';
import '../domain/coordination_repository.dart';

/// Lo que el servidor dijo, o un mensaje que dice qué hacer si ni respondió.
String _failure(Object error, String fallback) =>
    error is ApiException && error.statusCode != null ? error.message : fallback;

/// Pide el texto y manda una actualización a todo el colegio durante la alerta.
///
/// Le llega a cada celular como la nota de coordinación, debajo de las
/// instrucciones, y como aviso. Devuelve `true` si se envió.
Future<bool> sendAlertUpdate(BuildContext context, Alert alert) async {
  final CoordinationRepository? repository = AppScope.of(context).coordinationRepository;
  if (repository == null) return false;

  final String? note = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => _UpdateDialog(current: alert.coordinatorNote),
  );
  if (note == null || !context.mounted) return false;

  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await repository.sendAlertNote(alert.id, note);
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Actualización enviada a todo el colegio.')));
    return true;
  } catch (error, stack) {
    ErrorReporter.report(error, stack, context: 'enviar actualización');
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(_failure(error, 'No se pudo enviar. Avisa por radio.'))),
      );
    return false;
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({this.current});

  final String? current;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String value = _text.text.trim();
    return AlertDialog(
      title: const Text('Enviar actualización'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Le llega a todo el colegio, debajo de las instrucciones de la alerta.',
            style: AppTextStyles.caption,
          ),
          if (widget.current != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text('Ahora dice: «${widget.current}»', style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('actualizacion-texto'),
            controller: _text,
            autofocus: true,
            maxLength: 240,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'El bloque B ya está despejado.'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCELAR')),
        TextButton(
          key: const Key('actualizacion-enviar'),
          onPressed: value.isEmpty ? null : () => Navigator.of(context).pop(value),
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          child: const Text('ENVIAR'),
        ),
      ],
    );
  }
}

/// Escoge a quién mandar por alguien que pidió ayuda, y lo manda.
///
/// Le llega un aviso a esa persona. Devuelve el nombre de quien va, o `null` si
/// no se asignó.
Future<String?> assignHelp(
  BuildContext context, {
  required String alertId,
  required String personId,
  required String personName,
}) async {
  final CoordinationRepository? repository = AppScope.of(context).coordinationRepository;
  if (repository == null) return null;

  final Responder? chosen = await showModalBottomSheet<Responder>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        _ResponderSheet(repository: repository, personName: personName),
  );
  if (chosen == null || !context.mounted) return null;

  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await repository.assignHelp(alertId, personId, chosen.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${PersonName.short(chosen.fullName)} va por ${PersonName.short(personName)}. '
            'Ya le llegó el aviso.',
          ),
        ),
      );
    return chosen.fullName;
  } catch (error, stack) {
    ErrorReporter.report(error, stack, context: 'asignar brigadista');
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(_failure(error, 'No se pudo asignar. Avisa por radio.'))),
      );
    return null;
  }
}

class _ResponderSheet extends StatefulWidget {
  const _ResponderSheet({required this.repository, required this.personName});

  final CoordinationRepository repository;
  final String personName;

  @override
  State<_ResponderSheet> createState() => _ResponderSheetState();
}

class _ResponderSheetState extends State<_ResponderSheet> {
  List<Responder>? _responders;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Responder> responders = await widget.repository.loadResponders();
      if (mounted) setState(() => _responders = responders);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'quién puede ir');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Responder>? responders = _responders;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenGutter),
              child: Text(
                '¿A quién mandas por ${PersonName.short(widget.personName)}?',
                style: AppTextStyles.itemTitle,
              ),
            ),
            if (_failed)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.screenGutter),
                child: Text('No pudimos traer la lista. Intenta otra vez.', style: AppTextStyles.body),
              )
            else if (responders == null)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final Responder responder in responders)
                      ListTile(
                        key: Key('responder-${responder.id}'),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceAlt,
                          child: Text(
                            PersonName.initials(responder.fullName),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                        title: Text(responder.fullName, style: AppTextStyles.itemTitle),
                        subtitle: Text(
                          responder.isCoordination ? 'Coordinación' : 'Docente',
                          style: AppTextStyles.caption,
                        ),
                        onTap: () => Navigator.of(context).pop(responder),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
