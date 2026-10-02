import '../../../core/session/user_role.dart';
import '../../alerts/domain/meeting_point.dart';
import 'person_name.dart';
import 'personal_code.dart';

/// Perfil que el colegio cargó en la matrícula.
///
/// Es sellada a propósito: cada rol muestra datos distintos, y el compilador
/// obliga a cubrirlos todos cuando se agrega uno nuevo.
///
/// **El código no está aquí.** Vive solo en los perfiles que entran por código
/// —estudiante y acudiente—, porque un docente o un administrador no tiene uno:
/// entran con correo y contraseña. Tenerlo en la base obligaría a inventarle un
/// código falso a quien no lo usa, y un dato inventado en un modelo termina
/// mostrándose en alguna pantalla.
sealed class Enrollment {
  const Enrollment({required this.fullName});

  final String fullName;

  /// Rol con el que esta persona usa la app. Lo define el colegio en la
  /// matrícula; la app solo lo lee.
  UserRole get role;

  /// Etiqueta del rol tal como se muestra en el carné.
  String get roleLabel => role.label;
}

/// Los perfiles que entran con el código de un solo uso de secretaría.
///
/// Es una categoría real del dominio, no una comodidad: estudiantes y
/// acudientes son las mil doscientas personas que hay que registrar en unos
/// pocos días, y a las que no se les puede pedir crear una cuenta con correo.
///
/// Sellarla aquí hace que una pantalla como «¿eres tú?» pueda pedir el código
/// sin preguntar de qué rol se trata, y que el compilador impida pedírselo a un
/// docente, que no tiene.
sealed class CodeEnrollment extends Enrollment {
  const CodeEnrollment({required this.code, required super.fullName});

  /// El código con el que llegó, para quemarlo al confirmar.
  final PersonalCode code;
}

/// Estudiante: pertenece a un grupo y tiene acudientes que reciben sus avisos.
final class StudentEnrollment extends CodeEnrollment {
  const StudentEnrollment({
    required super.code,
    required super.fullName,
    required this.grade,
    required this.shift,
    required this.homeroomTeacher,
    required this.classroom,
    required this.meetingPoint,
    required this.guardians,
  });

  /// Grado y grupo, por ejemplo `10° B`.
  final String grade;

  /// Jornada: `Mañana` o `Tarde`.
  final String shift;

  /// Director de grupo.
  final String homeroomTeacher;

  /// Salón y bloque donde recibe clase: `Aula 7 · Bloque A`. Es de donde sale
  /// la ruta de evacuación.
  final String classroom;

  /// Punto de encuentro que le asignó el colegio.
  final MeetingPoint meetingPoint;

  final List<GuardianLink> guardians;

  @override
  UserRole get role => UserRole.estudiante;
}

/// Acudiente: no tiene grado, pero recibe las alertas de uno o más estudiantes.
final class GuardianEnrollment extends CodeEnrollment {
  const GuardianEnrollment({
    required super.code,
    required super.fullName,
    required this.maskedPhone,
    required this.children,
  });

  /// Celular con los dígitos del medio ocultos: el colegio ya lo tiene, aquí
  /// solo sirve para que la persona reconozca que es el suyo.
  final String maskedPhone;

  final List<LinkedStudent> children;

  @override
  UserRole get role => UserRole.acudiente;
}

/// Docente: tiene una carga de grupos y, a veces, dirección de grupo.
/// Docente: tiene carga de grupos y entra con correo y contraseña.
final class TeacherEnrollment extends Enrollment {
  const TeacherEnrollment({
    required super.fullName,
    required this.subject,
    required this.groups,
    this.email,
    this.homeroomGroup,
    this.groupSummaries = const <GroupSummary>[],
  });

  /// Correo con el que entra. Se muestra en su perfil para que sepa con cuál
  /// cuenta está dentro.
  final String? email;

  /// Cuántos estudiantes tiene cada uno de sus grupos y en qué salón. Lo manda el
  /// servidor: la app no escribe esas cifras.
  final List<GroupSummary> groupSummaries;

  /// El resumen de un grupo, o `null` si el servidor no lo mandó.
  GroupSummary? summaryFor(String grade) {
    for (final GroupSummary summary in groupSummaries) {
      if (summary.grade == grade) return summary;
    }
    return null;
  }

  /// Área que dicta: `Contabilidad`, `Matemáticas`.
  final String subject;

  /// Grupos a su cargo: `10° A`, `10° B`, `11° A`.
  final List<String> groups;

  /// Grupo del que es director, si lo es.
  final String? homeroomGroup;

  /// El grupo con el que se le muestra la lista: el que dirige o, si no dirige
  /// ninguno, el primero que dicta. `null` si no tiene ninguno.
  ///
  /// Coordinación puede quitarle todos los grupos a un docente desde el panel, y
  /// pedir `groups.first` en una lista vacía rompía la pantalla de inicio justo al
  /// abrir la app.
  String? get primaryGroup =>
      homeroomGroup ?? (groups.isEmpty ? null : groups.first);

  @override
  UserRole get role => UserRole.docente;
}

/// Cuántos estudiantes tiene un grupo, según la matrícula.
class GroupSummary {
  const GroupSummary({required this.grade, required this.enrolled, this.classroom});

  final String grade;
  final int enrolled;

  /// Salón y bloque: `Aula 7 · Bloque A`.
  final String? classroom;
}

/// Administrador: coordinación de gestión del riesgo.
///
/// No tiene grupos ni asignatura; su alcance es el colegio entero. Es quien
/// carga la matrícula, publica los protocolos, decide si un aviso externo se
/// convierte en alerta y finaliza la emergencia.
final class AdminEnrollment extends Enrollment {
  const AdminEnrollment({
    required super.fullName,
    required this.scope,
    this.email,
  });

  /// Hasta dónde llega: `Todo el instituto`. Lo dice el servidor con palabras,
  /// en vez de dejar el campo vacío, porque es lo que se muestra en su perfil.
  final String scope;

  final String? email;

  @override
  UserRole get role => UserRole.administrador;
}

/// Acudiente vinculado a un estudiante, visto desde el estudiante.
class GuardianLink {
  const GuardianLink({required this.fullName, required this.relationship});

  final String fullName;

  /// Parentesco: `Madre`, `Padre`, `Acudiente`.
  final String relationship;
}

/// Estudiante vinculado a un acudiente, visto desde el acudiente.
class LinkedStudent {
  const LinkedStudent({
    required this.fullName,
    required this.grade,
    required this.shift,
  });

  final String fullName;
  final String grade;
  final String shift;

  /// Iniciales para el avatar de la lista.
  String get initials => PersonName.initials(fullName);
}
