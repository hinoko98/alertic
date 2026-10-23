import '../../alerts/domain/alert.dart';
import '../../alerts/domain/alert_level.dart';
import '../../alerts/domain/hazard.dart';
import '../../alerts/domain/safety_report.dart';

/// Lo que el docente le pide al colegio.
///
/// Está aparte de `AlertRepository` a propósito: emitir una alerta o ver la
/// lista de un grupo son operaciones que la app del estudiante no debería ni
/// poder nombrar. El servidor igual las rechaza por rol, pero una interfaz que
/// no las expone evita el error antes de que exista.
abstract interface class TeacherRepository {
  /// Emite una alerta para el colegio.
  Future<Alert> issueAlert(AlertDraft draft);

  /// Da por terminada la alerta.
  Future<void> endAlert(String alertId);

  /// Estado de cada estudiante de un grupo durante la alerta.
  Future<List<RosterEntry>> loadRoster(String alertId, String grade);

  /// Marca a alguien a salvo desde la lista, cuando el docente lo ve en el
  /// punto de encuentro y esa persona no tiene celular.
  Future<void> markSafe(String alertId, String personId);

  /// A cuántas personas les llega una alerta. Se muestra antes de emitirla: quien
  /// la emite tiene que saber el tamaño de lo que está haciendo.
  ///
  /// Devuelve `null` si no se pudo saber; la pantalla lo dice sin inventar un
  /// número.
  Future<int?> loadReach();

  /// El grupo en calma: cuántos tienen la app, cuántos acudientes están
  /// vinculados, quién necesita apoyo para evacuar y qué falta por activar.
  Future<GroupOverview> loadGroupOverview(String grade);
}

/// Alguien del grupo que necesita ayuda para salir, y quién lo acompaña.
class SupportedStudent {
  const SupportedStudent({
    required this.fullName,
    required this.needLabel,
    this.buddies = const <String>[],
  });

  final String fullName;

  /// `Movilidad reducida`.
  final String needLabel;
  final List<String> buddies;
}

/// Algo que falta en un estudiante: no activó la app o no tiene acudiente.
class PendingStudent {
  const PendingStudent({required this.fullName, required this.missingApp});

  final String fullName;

  /// `true`: no activó su código. `false`: su acudiente no se ha vinculado.
  final bool missingApp;

  String get reason => missingApp ? 'No ha activado su código' : 'Su acudiente no se ha vinculado';
  String get chip => missingApp ? 'Sin app' : 'Sin acudiente';
}

/// El grupo de un docente, en calma.
class GroupOverview {
  const GroupOverview({
    required this.grade,
    required this.enrolled,
    required this.appActive,
    required this.guardiansLinked,
    this.classroom,
    this.meetingPoint,
    this.needsSupport = const <SupportedStudent>[],
    this.pending = const <PendingStudent>[],
  });

  final String grade;
  final int enrolled;
  final int appActive;
  final int guardiansLinked;
  final String? classroom;
  final String? meetingPoint;
  final List<SupportedStudent> needsSupport;
  final List<PendingStudent> pending;
}

/// Los datos de una alerta antes de emitirla.
class AlertDraft {
  const AlertDraft({
    required this.level,
    required this.hazard,
    required this.title,
    required this.scope,
    required this.instructions,
    this.meetingPoint,
    this.incidentId,
    this.drill = false,
    this.drillId,
  });

  final AlertLevel level;
  final Hazard hazard;
  final String title;
  final String scope;
  final List<String> instructions;
  final String? meetingPoint;

  /// El reporte de la comunidad que originó esta alerta, si coordinación o el
  /// docente la emite a partir de uno. Queda enlazado: después se puede
  /// responder qué la motivó.
  final String? incidentId;

  /// Es un simulacro: se emite igual que una alerta, pero se marca como práctica.
  final bool drill;

  /// El simulacro programado que se está realizando, si lo era.
  final String? drillId;

  /// A cuánta gente le va a sonar. Se muestra antes de enviar, para que quien
  /// la emite sepa el tamaño de lo que está haciendo.
  bool get isValid =>
      title.trim().isNotEmpty &&
      instructions.isNotEmpty &&
      (level != AlertLevel.roja || (meetingPoint?.isNotEmpty ?? false));
}

/// Una persona en la lista del grupo durante la emergencia.
class RosterEntry {
  const RosterEntry({
    required this.personId,
    required this.fullName,
    this.status,
    this.location,
    this.reportedAt,
  });

  final String personId;
  final String fullName;

  /// `null` mientras no responda.
  final SafetyStatus? status;
  final ReportedLocation? location;
  final DateTime? reportedAt;

  bool get hasResponded => status != null;
  bool get needsHelp => status == SafetyStatus.needsHelp;
}
