import '../../../core/network/api_client.dart';
import '../../session/domain/session.dart';
import '../domain/enrollment.dart';
import '../domain/enrollment_failure.dart';
import '../domain/personal_code.dart';
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
