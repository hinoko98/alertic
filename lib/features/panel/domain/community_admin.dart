/// Lo que coordinación puede cambiar de la comunidad desde el panel: de qué grupo
/// es cada estudiante, quién dirige cada grupo y las credenciales de cada persona.
///
/// Son modelos de pantalla, sin lógica de negocio: **todas las reglas viven en el
/// servidor** (que un grupo tenga un solo director, que un docente con acceso
/// tenga al menos un grupo, que el correo no se repita). Aquí solo se arma lo que
/// se manda y se lee lo que se responde.
library;

import '../../alerts/domain/hazard.dart';

/// Quién es una persona, sin más: para decir «dirige Carlos Jaimes».
class PersonRef {
  const PersonRef({required this.id, required this.fullName});

  final String id;
  final String fullName;
}

/// Un grupo del colegio, con quién lo dirige.
class GroupInfo {
  const GroupInfo({
    required this.grade,
    required this.enrolled,
    this.classroom,
    this.director,
  });

  /// `10° B`.
  final String grade;
  final int enrolled;
  final String? classroom;
  final PersonRef? director;
}

/// Una persona tal como se edita.
class PersonDetail {
  const PersonDetail({
    required this.id,
    required this.fullName,
    required this.role,
    required this.access,
    this.email,
    this.grade,
    this.shift,
    this.classroom,
    this.subject,
    this.homeroomGroup,
    this.groups = const <String>[],
    this.codeHint,
    this.code,
    this.phone,
    this.document,
    this.meetingPoint,
    this.children = const <LinkedPerson>[],
    this.guardians = const <LinkedPerson>[],
  });

  final String id;
  final String fullName;

  /// `estudiante`, `acudiente`, `docente` o `administrador`.
  final String role;

  /// Cómo está su acceso: `con_cuenta` / `sin_acceso` para quien entra con
  /// contraseña; `pendiente`, `entregado`, `usado`, `vencido`, `revocado` o `sin_generar`
  /// para quien entra con código.
  final String access;

  final String? email;
  final String? grade;
  final String? shift;
  final String? classroom;
  final String? subject;
  final String? homeroomGroup;

  /// Grupos que dicta, si es docente.
  final List<String> groups;

  /// Principio del código.
  final String? codeHint;

  /// El código completo, mientras está vigente (sin usar y dentro de su hora).
  final String? code;

  final String? phone;
  final String? document;

  /// Código del punto de encuentro de un estudiante: `P1`.
  final String? meetingPoint;

  /// Estudiantes a cargo de un acudiente.
  final List<LinkedPerson> children;

  /// Acudientes de un estudiante.
  final List<LinkedPerson> guardians;

  bool get usesPassword => role == 'docente' || role == 'administrador';
}

/// Una persona vinculada a otra: el hijo de un acudiente, o su acudiente.
class LinkedPerson {
  const LinkedPerson({
    required this.id,
    required this.fullName,
    required this.relationship,
    this.grade,
  });

  final String id;
  final String fullName;

  /// `Madre`, `Padre`, `Acudiente`…
  final String relationship;
  final String? grade;
}

/// A quién está a cargo un acudiente, y con qué parentesco.
class ChildLink {
  const ChildLink({required this.studentId, required this.relationship});

  final String studentId;
  final String relationship;

  Map<String, Object?> toJson() => <String, Object?>{
        'studentId': studentId,
        'relationship': relationship,
      };
}

/// Lo que se quiere cambiar de una persona. Lo que va en `null` no se toca.
///
/// Se manda solo lo que cambió: el servidor rechaza los campos que no
/// corresponden al rol, así que mandar de más es un error y no un descuido
/// inofensivo.
class PersonChanges {
  const PersonChanges({
    this.fullName,
    this.email,
    this.subject,
    this.grade,
    this.shift,
    this.classroom,
    this.homeroomGroup,
    this.removeHomeroom = false,
    this.groups,
    this.phone,
    this.document,
    this.meetingPoint,
    this.children,
  });

  final String? fullName;
  final String? email;
  final String? subject;
  final String? grade;
  final String? shift;
  final String? classroom;
  final String? homeroomGroup;

  /// Dejar de ser director de grupo. Va aparte porque `null` ya significa «no
  /// tocar».
  final bool removeHomeroom;
  final List<String>? groups;
  final String? phone;
  final String? document;
  final String? meetingPoint;

  /// Reemplaza **toda** la lista de estudiantes a cargo, no la agrega.
  final List<ChildLink>? children;

  bool get isEmpty => toJson().isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        if (fullName != null) 'fullName': fullName,
        if (email != null) 'email': email,
        if (subject != null) 'subject': subject,
        if (grade != null) 'grade': grade,
        if (shift != null) 'shift': shift,
        if (classroom != null) 'classroom': classroom,
        if (removeHomeroom) 'homeroomGroup': null,
        if (!removeHomeroom && homeroomGroup != null) 'homeroomGroup': homeroomGroup,
        if (groups != null) 'groups': groups,
        if (phone != null) 'phone': phone,
        if (document != null) 'document': document,
        if (meetingPoint != null) 'meetingPoint': meetingPoint,
        if (children != null)
          'children': <Map<String, Object?>>[
            for (final ChildLink child in children!) child.toJson(),
          ],
      };
}

/// Un estudiante que se va a dar de alta.
class NewStudent {
  const NewStudent({
    required this.fullName,
    required this.grade,
    this.shift = 'Mañana',
    this.classroom,
    this.document,
    this.meetingPoint,
    this.guardianName,
    this.guardianDocument,
  });

  final String fullName;
  final String grade;
  final String shift;
  final String? classroom;
  final String? document;
  final String? meetingPoint;

  /// Acudiente que se da de alta (o se vincula, si su documento ya existe) junto
  /// con el estudiante. Van los dos o ninguno.
  final String? guardianName;
  final String? guardianDocument;

  Map<String, Object?> toJson() => <String, Object?>{
        'fullName': fullName,
        'grade': grade,
        'shift': shift,
        if (classroom != null) 'classroom': classroom,
        if (document != null) 'document': document,
        if (meetingPoint != null) 'meetingPoint': meetingPoint,
        if (guardianName != null) 'guardianName': guardianName,
        if (guardianDocument != null) 'guardianDocument': guardianDocument,
      };
}

/// Un acudiente que se va a dar de alta, con los estudiantes a su cargo.
class NewGuardian {
  const NewGuardian({
    required this.fullName,
    this.phone,
    this.document,
    this.children = const <ChildLink>[],
  });

  final String fullName;
  final String? phone;
  final String? document;
  final List<ChildLink> children;

  Map<String, Object?> toJson() => <String, Object?>{
        'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (document != null) 'document': document,
        'children': <Map<String, Object?>>[
          for (final ChildLink child in children) child.toJson(),
        ],
      };
}

/// Una persona recién dada de alta y su código de un solo uso.
///
/// El código se muestra **una sola vez**: en el servidor solo queda su hash.
class CreatedPerson {
  const CreatedPerson({required this.person, required this.code});

  final PersonDetail person;
  final String code;
}

/// El código recién emitido de una persona, en una tanda.
///
/// Como todo código, se ve **una sola vez**: en el servidor solo queda su hash.
class IssuedCode {
  const IssuedCode({
    required this.personId,
    required this.fullName,
    required this.role,
    required this.code,
    this.grade,
  });

  final String personId;
  final String fullName;
  final String role;
  final String code;
  final String? grade;
}

/// Lo que devuelve una emisión en bloque.
class CodeBatch {
  const CodeBatch({required this.codes, this.alreadyRegistered = 0});

  final List<IssuedCode> codes;

  /// Personas del grupo que ya se registraron: no se les emitió nada.
  final int alreadyRegistered;

  /// Una línea por persona, separada por tabuladores: se pega tal cual en una
  /// hoja de cálculo o en una combinación de correspondencia para los carnés.
  String toTable() => <String>[
        'Nombre\tGrupo\tRol\tCódigo',
        for (final IssuedCode issued in codes)
          '${issued.fullName}\t${issued.grade ?? ''}\t${issued.role}\t${issued.code}',
      ].join('\n');
}

/// Un punto de encuentro que se crea o se cambia. El código lo pone el servidor.
class MeetingPointDraft {
  const MeetingPointDraft({
    required this.name,
    required this.routeHint,
    this.distanceMeters = 0,
    this.walkMinutes = 0,
    this.onlyFor,
  });

  final String name;
  final String routeHint;
  final int distanceMeters;
  final int walkMinutes;

  /// Si solo vale para una amenaza (la zona alta, en una inundación).
  final Hazard? onlyFor;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'routeHint': routeHint,
        'distanceMeters': distanceMeters,
        'walkMinutes': walkMinutes,
        'onlyFor': onlyFor?.wire,
      };
}

/// Un docente que se va a crear.
class NewTeacher {
  const NewTeacher({
    required this.fullName,
    required this.email,
    required this.subject,
    this.homeroomGroup,
    this.groups = const <String>[],
  });

  final String fullName;
  final String email;
  final String subject;
  final String? homeroomGroup;
  final List<String> groups;

  Map<String, Object?> toJson() => <String, Object?>{
        'fullName': fullName,
        'email': email,
        'subject': subject,
        if (homeroomGroup != null) 'homeroomGroup': homeroomGroup,
        'groups': groups,
      };
}

/// Quién dejó de dirigir un grupo porque otra persona lo tomó.
class ReplacedDirector {
  const ReplacedDirector({required this.person, required this.group});

  final PersonRef person;
  final String group;
}

/// Resultado de guardar los cambios de una persona.
class PersonUpdate {
  const PersonUpdate({required this.person, this.replacedDirector});

  final PersonDetail person;
  final ReplacedDirector? replacedDirector;
}

/// Una cuenta nueva y la contraseña temporal que el servidor eligió.
///
/// La contraseña se muestra **una sola vez**: en el servidor solo queda el hash.
class CreatedTeacher {
  const CreatedTeacher({
    required this.person,
    required this.temporaryPassword,
    this.replacedDirector,
  });

  final PersonDetail person;
  final String temporaryPassword;
  final ReplacedDirector? replacedDirector;
}

/// Un cambio que el servidor no aceptó, con el mensaje que ve coordinación.
///
/// El servidor escribe el mensaje para el caso concreto («Ese correo ya lo usa
/// otra cuenta»), así que se muestra tal cual.
class PanelActionFailure implements Exception {
  const PanelActionFailure(this.message);

  final String message;

  @override
  String toString() => 'PanelActionFailure: $message';
}
