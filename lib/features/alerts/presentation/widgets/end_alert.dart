import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/alert.dart';
import '../../domain/alert_level.dart';

/// Pregunta antes de dar una alerta por terminada, y la termina.
///
/// **Con confirmación a propósito.** Emitir una alerta exige sostener el botón
/// un segundo y medio para que un toque accidental no le suene a 1.248
/// personas. Finalizarla es igual de grave en el otro sentido: le dice a todos
/// «ya pasó, vuelvan» en mitad de una evacuación. Con un solo toque, un
/// celular en el bolsillo podía hacerlo.
///
/// Lo usan el docente y el panel de coordinación, así que vive aquí y no en
/// ninguno de los dos.
Future<void> confirmEndAlert(BuildContext context, Alert alert) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      shape: const RoundedRectangleBorder(),
      title: Text('¿Finalizar la alerta ${alert.level.label.toLowerCase()}?'),
      content: Text(
        alert.level == AlertLevel.roja
            ? 'Le vas a decir a todo el colegio que la emergencia terminó y que '
                'pueden volver. Confirma solo si ya revisaste que todos están a '
                'salvo.'
            : 'Le vas a decir a todo el colegio que la alerta terminó.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('SEGUIR EN ALERTA'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          child: const Text('SÍ, FINALIZAR'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    await AppScope.of(context).teacherRepository!.endAlert(alert.id);
  } catch (error, stack) {
    ErrorReporter.report(error, stack, context: 'finalizar alerta');
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              // Si el servidor respondió, dice por qué. Si no, se dice con
              // franqueza que no se sabe si quedó: la alerta sigue activa hasta
              // que alguien confirme lo contrario.
              error is ApiException && error.statusCode != null
                  ? error.message
                  : 'No se pudo finalizar. La alerta sigue activa: revisa tu '
                      'conexión e intenta otra vez.',
            ),
          ),
        );
    }
  }
}
