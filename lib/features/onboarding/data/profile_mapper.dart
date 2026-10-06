import '../../../core/session/user_role.dart';
import '../../alerts/domain/meeting_point.dart';
import '../domain/enrollment.dart';
import '../domain/enrollment_failure.dart';
import '../domain/personal_code.dart';

/// Traduce el perfil que manda el servidor al modelo de la app.
///
/// Vive aparte de los repositorios porque lo usan los **dos caminos de
/// entrada**: el código de un solo uso (estudiante y acudiente) y el correo con
/// contraseña (docente y administrador). Los dos reciben exactamente la misma
/// forma de perfil, y si el mapeo estuviera duplicado los dos podrían acabar
/// interpretándola distinto.
abstract final class ProfileMapper {
  /// Arma el perfil con lo que mandó el servidor.
  ///
  /// [code] solo llega en el camino del código, y se usa el que la persona
  /// acaba de escribir en vez de esperar que el servidor lo devuelva: una
  /// credencial no tiene por qué dar dos vueltas por la red.
  ///
  /// Lanza [EnrollmentUnavailable] si el perfil viene incompleto. Un perfil a
  /// medias es peor que ninguno: la persona tendría que confirmar que «sí es
  /// ella» sin poder comprobarlo.
  static Enrollment map(Object? raw, {PersonalCode? code}) {
    if (raw is! Map<String, dynamic>) {
      throw const EnrollmentUnavailable('el perfil vino vacío');
    }

    final UserRole? role = UserRole.tryParse(raw['role'] as String?);
    final String? fullName = raw['fullName'] as String?;
    if (role == null || fullName == null || fullName.isEmpty) {
      throw const EnrollmentUnavailable('el perfil vino incompleto');
    }

    return switch (role) {
      UserRole.estudiante => StudentEnrollment(
          code: _requireCode(code, role),
          fullName: fullName,
          grade: raw['grade'] as String? ?? '',
          shift: raw['shift'] as String? ?? '',
          classroom: raw['classroom'] as String? ?? '',
          homeroomTeacher: raw['homeroomTeacher'] as String? ?? '',
          meetingPoint: _mapMeetingPoint(raw['meetingPoint']),
          guardians: _mapList(
            raw['guardians'],
            (Map<String, dynamic> item) => GuardianLink(
              fullName: item['fullName'] as String? ?? '',
              relationship: item['relationship'] as String? ?? 'Acudiente',
            ),
          ),
        ),
      UserRole.acudiente => GuardianEnrollment(
          code: _requireCode(code, role),
          fullName: fullName,
          maskedPhone: raw['maskedPhone'] as String? ?? '',
          children: _mapList(
            raw['children'],
            (Map<String, dynamic> item) => LinkedStudent(
              fullName: item['fullName'] as String? ?? '',
              grade: item['grade'] as String? ?? '',
              shift: item['shift'] as String? ?? '',
            ),
          ),
        ),
      UserRole.docente => TeacherEnrollment(
          fullName: fullName,
          subject: raw['subject'] as String? ?? '',
          groups: <String>[
            for (final Object? group
                in raw['groups'] as List<Object?>? ?? const <Object?>[])
              if (group is String) group,
          ],
          homeroomGroup: raw['homeroomGroup'] as String?,
          email: raw['email'] as String?,
          groupSummaries: _mapList(
            raw['groupSummaries'],
            (Map<String, dynamic> item) => GroupSummary(
              grade: item['grade'] as String? ?? '',
              enrolled: (item['enrolled'] as num?)?.toInt() ?? 0,
              classroom: item['classroom'] as String?,
            ),
          ),
        ),
      UserRole.administrador => AdminEnrollment(
          fullName: fullName,
          scope: raw['scope'] as String? ?? 'Todo el instituto',
          email: raw['email'] as String?,
        ),
    };
  }

  /// Un estudiante o un acudiente sin código no puede existir.
  ///
  /// Si se llega aquí es porque el servidor devolvió por el camino del correo un
  /// perfil que solo entra por código. No se arma un código falso para salir del
  /// paso: se para, porque significa que los dos lados dejaron de coincidir.
  static PersonalCode _requireCode(PersonalCode? code, UserRole role) {
    if (code == null) {
      throw EnrollmentUnavailable(
        'el servidor devolvió un perfil de ${role.wire} sin código',
      );
    }
    return code;
  }

  static MeetingPoint _mapMeetingPoint(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      // Sin punto de encuentro la app no puede decirle a un estudiante a dónde
      // ir, que es lo único que importa en una evacuación.
      throw const EnrollmentUnavailable('el perfil no trae punto de encuentro');
    }

    return MeetingPoint(
      code: raw['code'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      routeHint: raw['routeHint'] as String? ?? '',
      distanceMeters: (raw['distanceMeters'] as num?)?.toInt() ?? 0,
      walkMinutes: (raw['walkMinutes'] as num?)?.toInt() ?? 0,
      latitude: (raw['latitude'] as num?)?.toDouble(),
      longitude: (raw['longitude'] as num?)?.toDouble(),
    );
  }

  static List<T> _mapList<T>(
    Object? raw,
    T Function(Map<String, dynamic> item) map,
  ) {
    if (raw is! List<Object?>) {
      return <T>[];
    }
    return <T>[
      for (final Object? item in raw)
        if (item is Map<String, dynamic>) map(item),
    ];
  }
}
