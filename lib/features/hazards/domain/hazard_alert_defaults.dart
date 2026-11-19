import '../../alerts/domain/alert.dart';
import '../../alerts/domain/alert_level.dart';
import '../../alerts/domain/hazard.dart';
import '../../alerts/domain/protocol.dart';

/// Lo que dice una alerta cuando quien la emite no la redacta.
///
/// En una emergencia no hay tiempo de escribir, y un texto libre que le llega a
/// mil personas es un riesgo que no hace falta correr: el título lo fija el
/// sistema según la amenaza y las instrucciones salen del protocolo publicado.
/// Lo usan el panel web y la revisión de avisos del celular, para que una misma
/// amenaza diga lo mismo venga de donde venga.
abstract final class HazardAlertDefaults {
  static String title(Hazard hazard, AlertLevel level, {bool drill = false}) {
    if (drill) {
      return switch (hazard) {
        Hazard.sismo => 'SIMULACRO DE SISMO',
        Hazard.incendio => 'SIMULACRO DE INCENDIO',
        Hazard.inundacion => 'SIMULACRO DE INUNDACIÓN',
        Hazard.lluvia => 'SIMULACRO DE LLUVIAS',
      };
    }
    return switch (hazard) {
      Hazard.sismo => level == AlertLevel.roja ? 'SISMO' : 'SISMO REPORTADO',
      Hazard.incendio => 'INCENDIO',
      Hazard.inundacion => 'CRECIENTE DE LA QUEBRADA',
      Hazard.lluvia => 'LLUVIA FUERTE',
    };
  }

  /// En una roja, los pasos de «durante» del protocolo; si no hay, unos
  /// genéricos que sirven para cualquier evacuación.
  static List<String> instructions(Hazard hazard, AlertLevel level, List<Protocol> protocols) {
    if (level == AlertLevel.roja) {
      for (final Protocol p in protocols) {
        if (p.hazard == hazard && p.duringSteps.isNotEmpty) {
          return <String>[
            for (final String step in p.duringSteps.take(Alert.maxInstructions))
              step.length > Alert.maxInstructionLength ? step.substring(0, Alert.maxInstructionLength) : step,
          ];
        }
      }
      return const <String>[
        'Sal con tu grupo, en fila y sin correr',
        'No vuelvas por nada',
        'Ve a tu punto de encuentro',
      ];
    }
    if (level == AlertLevel.naranja) {
      return const <String>[
        'Guarda tus cosas',
        'Ubícate cerca de la puerta con tu grupo',
        'Espera la indicación de salir',
      ];
    }
    return const <String>[
      'Mantente atento a las indicaciones de tu docente',
      'No hace falta salir del salón',
    ];
  }
}
