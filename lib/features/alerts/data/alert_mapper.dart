import '../../../core/errors/error_reporter.dart';
import '../domain/alert.dart';
import '../domain/alert_level.dart';
import '../domain/hazard.dart';

/// Convierte una alerta del servidor en la del dominio.
///
/// Lo usan **todos** los repositorios que reciben alertas —el de alertas, el del
/// docente que acaba de emitir una, el del panel—. Si cada uno tuviera su copia,
/// el día que cambie un campo habría que acordarse de cambiarlo en tres sitios, y
/// la pantalla que se olvide mostraría la alerta distinta a las demás.
///
/// Todo pasa por `Alert.validated`: una alerta mal formada se descarta en vez de
/// mostrarse a medias en mitad de una emergencia.
abstract final class AlertMapper {
  /// Devuelve `null` si no se puede convertir. Se registra el motivo pero no se
  /// propaga: que el colegio publique una alerta con un campo malo no puede dejar
  /// la app rota.
  static Alert? parse(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    try {
      return Alert.validated(
        id: raw['id'] as String?,
        level: AlertLevel.tryParse(raw['level'] as String?),
        hazard: Hazard.tryParse(raw['hazard'] as String?),
        title: raw['title'] as String?,
        scope: raw['scope'] as String?,
        instructions: steps(raw['instructions']),
        meetingPoint: raw['meetingPoint'] as String?,
        coordinatorNote: raw['coordinatorNote'] as String?,
        issuedBy: raw['issuedBy'] as String?,
        issuedAt: DateTime.tryParse(raw['issuedAt'] as String? ?? '')?.toLocal(),
      );
    } on InvalidAlertData catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'alerta mal formada');
      return null;
    }
  }

  /// Una lista de textos, descartando lo que no sea texto o venga vacío.
  static List<String> steps(Object? raw) {
    if (raw is! List<Object?>) {
      return const <String>[];
    }
    return <String>[
      for (final Object? step in raw)
        if (step is String && step.trim().isNotEmpty) step.trim(),
    ];
  }
}
