import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../onboarding/domain/enrollment.dart';
import '../../../session/domain/session.dart';
import '../../domain/alert.dart';
import '../../domain/safety_report.dart';
import '../screens/alert_screen.dart';

/// Deja pasar la alerta por encima de la app.
///
/// Envuelve el shell y lo reemplaza mientras hay una alerta sin responder. Es
/// un decorador del árbol de widgets: ni el shell ni las pestañas saben que
/// existe, y por eso una alerta entra igual sin importar en qué pantalla esté
/// la persona.
///
/// Una alerta no se cierra con el botón de atrás ni cambiando de pestaña: se
/// responde. Ese es el punto de toda la app.
class AlertGate extends StatefulWidget {
  const AlertGate({
    required this.session,
    required this.child,
    super.key,
  });

  final Session session;
  final Widget child;

  @override
  State<AlertGate> createState() => _AlertGateState();
}

class _AlertGateState extends State<AlertGate> {
  StreamSubscription<Alert?>? _subscription;

  Alert? _active;

  /// Alerta que esta persona ya atendió. Se guarda el id, no un booleano: si
  /// llega una alerta nueva mientras la anterior seguía en pantalla, la nueva
  /// tiene que verse.
  String? _handledId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription ??=
        AppScope.of(context).alertRepository.watchActiveAlert().listen(
      (Alert? alert) {
        if (mounted) {
          setState(() => _active = alert);
        }
      },
      onError: (Object error, StackTrace stack) {
        // Si el flujo de alertas falla, la app sigue funcionando: es preferible
        // el inicio sin alerta que una pantalla rota.
        ErrorReporter.report(error, stack, context: 'flujo de alertas');
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _acknowledge(Alert alert) async {
    setState(() => _handledId = alert.id);
    try {
      await AppScope.of(context).alertRepository.acknowledge(alert.id);
    } catch (error, stack) {
      // No se le devuelve el error a la persona: ya leyó la alerta y eso es lo
      // que importaba. El reintento es cosa del repositorio.
      ErrorReporter.report(error, stack, context: 'confirmar lectura');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Alert? alert = _active;
    if (alert == null || alert.id == _handledId) {
      return widget.child;
    }

    /*
     * Hay dos roles a los que **no** se les tapa la pantalla.
     *
     * Al **acudiente**, porque las instrucciones de una alerta son para quien
     * está dentro del colegio: «cúbrete», «sal en fila», «ve a la cancha». A una
     * madre que va manejando no le sirven, y taparle el celular con ellas le
     * quita justo lo que sí necesita, que es el estado de sus hijos.
     *
     * Al **administrador**, porque su teléfono es el que está dirigiendo la
     * evacuación. Bloquearlo con «estoy a salvo / necesito ayuda» le esconde el
     * tablero a la única persona que puede ver quién pidió ayuda y finalizar la
     * alerta. Además el servidor ni siquiera lo cuenta en el tablero: los
     * conteos son de estudiantes y docentes, así que tampoco falta su respuesta.
     *
     * Los dos ven la alerta como aviso, arriba, sin que les bloquee nada.
     */
    if (!widget.session.role.mustRespondOnScreen) {
      return widget.child;
    }

    final Enrollment profile = widget.session.profile;

    // El estudiante responde con sus propias pantallas (ruta, «a salvo», «ayuda»)
    // y, cuando una queda registrada, la alerta deja de pedirle que responda. Los
    // demás roles solo dan por leída la alerta.
    return AlertScreen(
      alert: alert,
      student: profile is StudentEnrollment ? profile : null,
      onResponded: () => setState(() => _handledId = alert.id),
      onAcknowledge: () => _acknowledge(alert),
      onRespond: (SafetyStatus _) => _acknowledge(alert),
    );
  }
}
