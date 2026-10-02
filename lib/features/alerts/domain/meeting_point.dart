import 'hazard.dart';

/// Punto de encuentro asignado a un grupo.
///
/// Lo define el colegio en su plan de evacuación: no lo escoge el estudiante ni
/// lo calcula la app. Cada grupo tiene el suyo según el bloque donde estudia.
class MeetingPoint {
  const MeetingPoint({
    required this.code,
    required this.name,
    required this.routeHint,
    required this.distanceMeters,
    required this.walkMinutes,
    this.onlyFor,
  });

  /// Código corto que se pinta en el plano: `P1`, `P2`.
  final String code;

  /// Nombre que usa la gente: `Cancha central`.
  final String name;

  /// Cómo llegar desde el salón: `Desde Aula 7 · 60 m por el corredor sur`.
  final String routeHint;

  final int distanceMeters;
  final int walkMinutes;

  /// Algunos puntos solo aplican a una amenaza. La placa alta (P2) solo se usa
  /// en inundación; mandar ahí a todo el colegio por un sismo sería un error.
  final Hazard? onlyFor;

  /// Resumen del encabezado del mapa: `A P1 · 60 m · 1 min`.
  ///
  /// La distancia y el tiempo son opcionales en el colegio: un punto recién creado
  /// no los trae, y «0 m · 0 min» sería un dato inventado. Se muestran solo si
  /// alguien los puso.
  String get summary => <String>[
        'A $code',
        if (distanceMeters > 0) '$distanceMeters m',
        if (walkMinutes > 0) '$walkMinutes min',
      ].join(' · ');
}
