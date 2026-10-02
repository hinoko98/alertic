import '../../alerts/domain/safety_report.dart';

/// Lo que un acudiente puede preguntar.
///
/// Solo por sus propios hijos. El servidor resuelve la consulta partiendo del
/// vínculo que registró el colegio, así que no existe forma de pedir los datos
/// de un menor ajeno ni cambiando la app.
abstract interface class GuardianRepository {
  /// Estado de los hijos durante una alerta.
  ///
  /// Con [alertId] en nulo devuelve el estado en calma: quiénes son, en qué
  /// grado están y a qué punto de encuentro les toca ir.
  Future<List<ChildStatus>> loadChildren(String? alertId);

  /// Teléfono de coordinación, tal como lo publicó el colegio.
  ///
  /// `null` si el colegio no publicó uno. La app lo dice así: un número
  /// inventado, con un acudiente preocupado, es peor que ninguno.
  Future<String?> loadSchoolPhone();
}

/// Un hijo, visto por el acudiente durante la emergencia.
class ChildStatus {
  const ChildStatus({
    required this.fullName,
    required this.grade,
    required this.shift,
    required this.homeroomTeacher,
    required this.meetingPoint,
    this.status,
    this.location,
    this.reportedAt,
    this.note,
  });

  final String fullName;
  final String grade;
  final String shift;
  final String homeroomTeacher;
  final String meetingPoint;

  /// `null` mientras no haya respondido.
  final SafetyStatus? status;
  final ReportedLocation? location;
  final DateTime? reportedAt;

  /// Explicación para el acudiente cuando el hijo no ha confirmado.
  ///
  /// Un niño de sexto puede no tener celular; decirlo evita que la familia
  /// piense lo peor y se venga al colegio en mitad de una evacuación.
  final String? note;

  bool get isSafe => status == SafetyStatus.safe;
  bool get needsHelp => status == SafetyStatus.needsHelp;
  bool get isPending => status == null;
}
