import '../../../core/network/api_client.dart';
import '../../session/domain/session.dart';
import '../domain/enrollment.dart';
import '../domain/enrollment_failure.dart';
import '../domain/guardian_link.dart';
import '../domain/personal_code.dart';
import '../domain/school.dart';
import 'enrollment_repository.dart';
import 'profile_mapper.dart';

/// Matrícula real, contra la API del colegio.
///
/// Reemplaza a `FakeEnrollmentRepository` sin que ninguna pantalla cambie: es la
/// razón por la que el acceso a datos se separó del dominio desde el principio.
class ApiEnrollmentRepository implements EnrollmentRepository {
  const ApiEnrollmentRepository(this._api);

  final ApiClient _api;

  @override
  Future<School> findSchool(String schoolCode) async {
    final Map<String, dynamic> response = await _call(
      () => _api.post('/school/check', body: <String, dynamic>{'code': schoolCode}),
    );
    final Object? school = response['school'];
    if (school is! Map<String, dynamic>) {
      throw const EnrollmentUnavailable('el servidor no devolvió el colegio');
    }
    return School(
      name: school['name'] as String? ?? '',
      city: school['city'] as String? ?? '',
    );
  }

  @override
  Future<Enrollment> findByCode(PersonalCode code) async {
    final Map<String, dynamic> response = await _call(
      () => _api.post('/auth/code/validate', body: <String, dynamic>{
        'code': code.formatted,
      }),
    );
    return ProfileMapper.map(response['profile'], code: code);
  }

  @override
  Future<Session> confirmIdentity(PersonalCode code) async {
    final Map<String, dynamic> response = await _call(
      () => _api.post('/auth/code/redeem', body: <String, dynamic>{
        'code': code.formatted,
      }),
    );

    final String? token = response['token'] as String?;
    if (token == null) {
      throw const EnrollmentUnavailable('el servidor no devolvió sesión');
    }

    _api.useToken(token);

    return Session(
      token: token,
      profile: ProfileMapper.map(response['profile'], code: code),
      // TODO(sesión): que el servidor mande el vencimiento en la respuesta, en
      // vez de suponerlo aquí a partir de lo que dura el token.
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
  }

  @override
  Future<StudentMatch> findStudentByDocument({
    required String schoolCode,
    required String document,
  }) async {
    final Map<String, dynamic> response = await _call(
      () => _api.post('/auth/guardian/lookup', body: <String, dynamic>{
        'schoolCode': schoolCode,
        'document': document,
      }),
    );
    final Object? student = response['student'];
    if (student is! Map<String, dynamic>) {
      throw const EnrollmentUnavailable('el servidor no devolvió el estudiante');
    }
    return StudentMatch(
      maskedName: student['maskedName'] as String? ?? '',
      grade: student['grade'] as String? ?? '',
      shift: student['shift'] as String? ?? '',
      maskedDocument: student['maskedDocument'] as String? ?? '',
      document: document,
    );
  }

  @override
  Future<LinkRequest> requestGuardianLink({
    required GuardianDraft draft,
    required StudentMatch student,
    required GuardianContact contact,
  }) async {
    final Map<String, dynamic> response = await _call(
      () => _api.post('/auth/guardian/request', body: <String, dynamic>{
        'schoolCode': draft.schoolCode,
        'studentDocument': student.document,
        'relationship': draft.relationship.label,
        'fullName': contact.fullName,
        'documentType': contact.documentType.wire,
        'document': contact.document,
        'phone': contact.phone,
        if (contact.email.isNotEmpty) 'email': contact.email,
        'claimSecret': draft.claimSecret,
      }),
    );
    final String? id = response['requestId'] as String?;
    if (id == null) {
      throw const EnrollmentUnavailable('el servidor no devolvió la solicitud');
    }
    return LinkRequest(
      id: id,
      approved: response['status'] == 'aprobada',
      student: student,
    );
  }

  @override
  Future<ClaimOutcome> claimGuardianLink({
    required String requestId,
    required String claimSecret,
  }) async {
    final Map<String, dynamic> response = await _call(
      () => _api.post('/auth/guardian/claim', body: <String, dynamic>{
        'requestId': requestId,
        'claimSecret': claimSecret,
      }),
    );
    switch (response['status']) {
      case 'pendiente':
        return const ClaimPending();
      case 'rechazada':
        return const ClaimRejected();
      case 'aprobada':
        final String? token = response['token'] as String?;
        if (token == null) {
          throw const EnrollmentUnavailable('el servidor no devolvió sesión');
        }
        _api.useToken(token);
        return ClaimApproved(
          Session(
            token: token,
            profile: ProfileMapper.map(response['profile']),
            expiresAt: DateTime.now().add(const Duration(hours: 12)),
          ),
        );
      default:
        throw EnrollmentUnavailable('estado desconocido: ${response['status']}');
    }
  }

  /// Traduce los errores de la API a los del dominio.
  ///
  /// Las pantallas solo conocen `EnrollmentFailure`: no saben qué es un 409 ni
  /// tienen por qué enterarse.
  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on ApiException catch (error) {
      throw switch (error.code) {
        'codigo_usado' => const CodeAlreadyUsed(),
        'codigo_invalido' => const CodeNotFound(),
        'codigo_vencido' => const CodeExpired(),
        'colegio_no_encontrado' => const SchoolNotFound(),
        'estudiante_no_encontrado' => const StudentNotFound(),
        'solicitud_invalida' || 'solicitud_usada' => const LinkRequestInvalid(),
        // Mismo caso que en el inicio de sesión: demasiados intentos desde esta
        // dirección. En el colegio todos salen por la misma, así que un salón
        // registrándose junto puede toparse con esto.
        'demasiados_intentos' || 'demasiadas_solicitudes' => const TooManyAttempts(),
        // El servidor dice que esa persona entra con correo y contraseña. Se
        // pasa su mensaje tal cual: está escrito para que quien lo lea sepa a
        // dónde ir, y la app no tiene nada mejor que decir.
        'metodo_incorrecto' => WrongAuthMethod(error.message),
        _ => EnrollmentUnavailable(error),
      };
    }
  }

}
