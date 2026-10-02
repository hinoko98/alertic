import '../../alerts/domain/alert.dart';
import '../../alerts/domain/hazard.dart';
import '../../alerts/domain/meeting_point.dart';
import '../../alerts/domain/protocol.dart';
import 'community_admin.dart';

/// Lo que el panel del colegio necesita saber.
///
/// Es una interfaz aparte de las de la app móvil porque responde otra pregunta:
/// la app pregunta «¿qué hago yo?», el panel pregunta «¿cómo va el colegio?».
abstract interface class PanelRepository {
  /// Conteos en vivo de la alerta activa.
  Future<EmergencyBoard> loadBoard(String alertId);

  /// Gente de la comunidad, con el estado de su código.
  Future<List<CommunityMember>> loadCommunity({String? role, String query = ''});

  /// Resumen para el encabezado de la pestaña de comunidad.
  Future<CommunityStats> loadStats();

  /// Avisos de fuentes externas pendientes de revisar.
  Future<List<HazardSignal>> loadSignals();

  /// Coordinación descarta un aviso que no amerita alerta.
  Future<void> dismissSignal(String signalId);

  /// Alertas anteriores.
  Future<List<Alert>> loadHistory();

  /// Protocolos publicados.
  Future<List<Protocol>> loadProtocols();

  /// Los grupos del colegio y quién los dirige.
  Future<List<GroupInfo>> loadGroups();

  /// Una persona, con lo que se puede editar de ella.
  Future<PersonDetail> loadPerson(String id);

  /// Guarda cambios de una persona: grupo, jornada, salón, materia, grupos que
  /// dicta, dirección de grupo, correo.
  ///
  /// Lanza [PanelActionFailure] con el mensaje del servidor si no se acepta.
  Future<PersonUpdate> updatePerson(String id, PersonChanges changes);

  /// Crea una cuenta de docente. Devuelve la contraseña temporal, una sola vez.
  Future<CreatedTeacher> createTeacher(NewTeacher teacher);

  /// Restablece la contraseña de un docente y cierra sus sesiones. Devuelve la
  /// temporal, una sola vez.
  Future<String> resetTeacherPassword(String id);

  /// Le quita el acceso y los grupos a un docente, sin borrar su historial.
  Future<PersonDetail> deactivateTeacher(String id);

  /// Revoca el código de un estudiante o acudiente y emite otro. Lo devuelve una
  /// sola vez, para imprimirlo.
  Future<String> renewCode(String id);

  /// Cierra todas las sesiones de una persona y borra sus celulares: para un
  /// teléfono perdido.
  Future<void> closeSessions(String id);

  /// Da de alta a un estudiante. Devuelve su código, una sola vez.
  Future<CreatedPerson> createStudent(NewStudent student);

  /// Da de alta a un acudiente, con los estudiantes a su cargo. Devuelve su
  /// código, una sola vez.
  Future<CreatedPerson> createGuardian(NewGuardian guardian);

  /// Carga una lista de estudiantes de una vez y devuelve el código de cada uno.
  /// Todo o nada: si una fila está mal, no se crea ninguna.
  Future<CodeBatch> importStudents(List<NewStudent> students);

  /// Emite códigos en bloque: a los estudiantes de [grades] (y, con
  /// [includeGuardians], a sus acudientes). Sin [reissue] solo a quien no tiene
  /// código; con él, también a quien tiene uno sin usar, revocando el anterior.
  /// Nunca a quien ya se registró.
  Future<CodeBatch> generateCodes({
    required List<String> grades,
    bool includeGuardians = false,
    bool reissue = false,
  });

  /// Elimina a una persona. El servidor se niega si tiene historial que debe
  /// conservarse (un docente que emitió alertas): entonces se le da de baja.
  Future<void> deletePerson(String id);

  /// Los puntos de encuentro, como los definió coordinación.
  Future<List<MeetingPoint>> loadMeetingPoints();

  /// Crea un punto de encuentro. Devuelve el código que le puso el servidor.
  Future<String> createMeetingPoint(MeetingPointDraft point);

  Future<void> updateMeetingPoint(String code, MeetingPointDraft point);

  /// Quita un punto. El servidor se niega si tiene estudiantes asignados o si es
  /// el último punto general.
  Future<void> deleteMeetingPoint(String code);

  /// Guarda el protocolo de una amenaza. Es lo que cada celular guarda y lee sin
  /// conexión.
  Future<void> saveProtocol(Protocol protocol);
}

/// El tablero de emergencia.
class EmergencyBoard {
  const EmergencyBoard({
    required this.safe,
    required this.needHelp,
    required this.noResponse,
    required this.total,
    required this.byGrade,
    required this.needHelpList,
    required this.byMeetingPoint,
  });

  final int safe;
  final int needHelp;
  final int noResponse;
  final int total;
  final List<GradeProgress> byGrade;
  final List<HelpRequest> needHelpList;
  final List<MeetingPointCount> byMeetingPoint;

  /// Porcentaje a salvo, para el número grande del tablero.
  int get safePercent => total == 0 ? 0 : ((safe / total) * 100).round();
}

class GradeProgress {
  const GradeProgress({
    required this.grade,
    required this.safe,
    required this.needHelp,
    required this.noResponse,
    required this.total,
  });

  final String grade;
  final int safe;
  final int needHelp;
  final int noResponse;
  final int total;

  double get progress => total == 0 ? 0 : safe / total;
}

class HelpRequest {
  const HelpRequest({
    required this.personId,
    required this.fullName,
    required this.grade,
    required this.location,
    required this.reportedAt,
  });

  final String personId;
  final String fullName;
  final String grade;
  final String location;
  final DateTime reportedAt;
}

class MeetingPointCount {
  const MeetingPointCount({required this.code, required this.count});

  final String code;
  final int count;
}

/// Una persona en la pestaña de comunidad.
class CommunityMember {
  const CommunityMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.codeStatus,
    this.grade,
    this.codeHint,
    this.code,
    this.linkedTo,
  });

  final String id;
  final String fullName;
  final String role;
  final String? grade;

  /// Solo el principio del código. El completo no existe en ningún lado
  /// después de generarlo: en la base de datos vive hasheado.
  final String? codeHint;

  /// El código completo, mientras está vigente (sin usar y dentro de su hora).
  final String? code;

  /// Lo que se muestra en la lista: el código si se puede ver, y si no, su
  /// principio.
  String? get codeLabel => code ?? (codeHint == null ? null : '$codeHint••');

  /// `pendiente`, `entregado`, `usado`, `vencido`, `revocado`, `sin_generar`.
  final String codeStatus;

  final String? linkedTo;
}

class CommunityStats {
  const CommunityStats({
    required this.total,
    required this.byRole,
    required this.activeCodes,
    required this.pendingCodes,
  });

  final int total;
  final Map<String, int> byRole;
  final int activeCodes;
  final int pendingCodes;
}

/// Aviso de una fuente externa: USGS, Open-Meteo.
class HazardSignal {
  const HazardSignal({
    required this.id,
    required this.source,
    required this.hazard,
    required this.headline,
    required this.detail,
    required this.occurredAt,
    this.magnitude,
    this.distanceKm,
  });

  final String id;
  final String source;
  final Hazard hazard;
  final String headline;
  final String detail;
  final DateTime occurredAt;
  final double? magnitude;
  final int? distanceKm;
}
