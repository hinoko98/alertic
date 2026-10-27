import '../../alerts/domain/alert.dart';
import '../../onboarding/domain/enrollment.dart';

/// Lo que coordinación hace durante una alerta y lo que deja preparado antes.
///
/// Va aparte de `PanelRepository` porque responde otra pregunta: el panel
/// pregunta «¿cómo va el colegio?»; esto es «¿qué hago yo, coordinación, con
/// eso?»: mandar una actualización, mandar a alguien por quien pidió ayuda,
/// decirle a cada docente su tarea y a cada estudiante quién va por él.
abstract interface class CoordinationRepository {
  /// Manda una actualización a todo el colegio durante la alerta en curso. Le
  /// llega a cada celular como la nota de coordinación de la alerta.
  Future<Alert?> sendAlertNote(String alertId, String note);

  /// Quién puede ir por alguien: docentes y coordinación.
  Future<List<Responder>> loadResponders();

  /// Manda a [assigneeId] por [personId], que pidió ayuda. Le llega un aviso.
  Future<void> assignHelp(String alertId, String personId, String assigneeId);

  /// A quién se mandó por cada pedido de ayuda de la alerta.
  Future<List<HelpAssignment>> loadHelpAssignments(String alertId);

  /// Las listas que entregaron los docentes en la alerta.
  Future<List<DeliveredRoster>> loadDeliveredRosters(String alertId);

  /// La tarea de un docente en una emergencia, o `null` si no tiene.
  Future<EmergencyTask?> loadEmergencyTask(String teacherId);

  Future<void> saveEmergencyTask(String teacherId, EmergencyTask task);

  Future<void> clearEmergencyTask(String teacherId);

  /// Qué necesita un estudiante para evacuar y quién va por él.
  Future<SupportPlan> loadSupportPlan(String studentId);

  Future<void> addSupportBuddy(String studentId, String buddyId);

  Future<void> removeSupportBuddy(String studentId, String buddyId);
}

/// Alguien a quien coordinación puede mandar.
class Responder {
  const Responder({required this.id, required this.fullName, required this.isCoordination});

  final String id;
  final String fullName;
  final bool isCoordination;
}

/// A quién se mandó por alguien que pidió ayuda.
class HelpAssignment {
  const HelpAssignment({
    required this.personId,
    required this.assigneeId,
    required this.assignee,
    required this.assignedAt,
  });

  final String personId;
  final String assigneeId;
  final String assignee;
  final DateTime assignedAt;
}

/// Una lista de grupo que un docente le entregó a coordinación.
class DeliveredRoster {
  const DeliveredRoster({
    required this.grade,
    required this.teacher,
    required this.safe,
    required this.needHelp,
    required this.pending,
    required this.submittedAt,
  });

  final String grade;
  final String teacher;
  final int safe;
  final int needHelp;
  final int pending;
  final DateTime submittedAt;
}

/// Un compañero que va por un estudiante en una alerta.
class SupportBuddy {
  const SupportBuddy({required this.id, required this.fullName, this.grade});

  final String id;
  final String fullName;
  final String? grade;
}

/// Lo que un estudiante necesita para evacuar y quién lo acompaña.
class SupportPlan {
  const SupportPlan({this.need, this.buddies = const <SupportBuddy>[]});

  /// `movilidad`, `vision`, `audicion`, `temporal`; `null` si no pidió apoyo.
  final String? need;
  final List<SupportBuddy> buddies;

  String? get needLabel => switch (need) {
        'movilidad' => 'Movilidad reducida',
        'vision' => 'Baja visión',
        'audicion' => 'Discapacidad auditiva',
        'temporal' => 'Apoyo temporal',
        _ => null,
      };
}
