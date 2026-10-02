import 'hazard.dart';

/// Qué hacer ante una amenaza, según el plan del colegio.
///
/// Se guarda en el celular: en una emergencia no hay internet, y este es el
/// contenido que la persona necesita leer sin señal.
class Protocol {
  const Protocol({
    required this.hazard,
    required this.beforeSteps,
    required this.duringSteps,
    required this.afterSteps,
  });

  final Hazard hazard;
  final List<String> beforeSteps;
  final List<String> duringSteps;
  final List<String> afterSteps;
}
