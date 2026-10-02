import '../../../core/network/api_client.dart';
import '../../session/domain/session.dart';
import '../domain/credentials.dart';
import '../domain/enrollment_failure.dart';
import 'credentials_repository.dart';
import 'profile_mapper.dart';

/// Inicio de sesión real, contra la API del colegio.
class ApiCredentialsRepository implements CredentialsRepository {
  const ApiCredentialsRepository(this._api);

  final ApiClient _api;

  @override
  Future<Session> signIn(Credentials credentials) async {
    final Map<String, dynamic> response;
    try {
      response = await _api.post(
        '/auth/login',
        body: <String, dynamic>{
          'email': credentials.email,
          'password': credentials.password,
        },
      );
    } on ApiException catch (error) {
      throw switch (error.code) {
        'credenciales_invalidas' => const InvalidCredentials(),
        // Dos códigos distintos del servidor para lo mismo: el límite de fallos
        // por cuenta, y el límite general de peticiones por dirección.
        'demasiados_intentos' || 'demasiadas_solicitudes' => const TooManyAttempts(),
        _ => EnrollmentUnavailable(error),
      };
    }

    final String? token = response['token'] as String?;
    if (token == null) {
      throw const EnrollmentUnavailable('el servidor no devolvió sesión');
    }

    _api.useToken(token);

    // Sin código: quien entra por aquí no tiene uno. `ProfileMapper` lo exige
    // para estudiante y acudiente, así que si el servidor devolviera uno de
    // esos perfiles por esta ruta, fallaría en vez de inventarse un código.
    return Session(
      token: token,
      profile: ProfileMapper.map(response['profile']),
      // TODO(sesión): que el servidor mande el vencimiento en la respuesta, en
      // vez de suponerlo aquí a partir de lo que dura el token.
      expiresAt: DateTime.now().add(const Duration(hours: 12)),
    );
  }

  @override
  Future<void> signOut() async => _api.useToken(null);

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final Map<String, dynamic> response;
    try {
      response = await _api.post(
        '/auth/password',
        body: <String, dynamic>{
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on ApiException catch (error) {
      throw switch (error.code) {
        'contrasena_actual_incorrecta' => const WrongCurrentPassword(),
        'demasiados_intentos' || 'demasiadas_solicitudes' => const TooManyAttempts(),
        'entrada_invalida' => PasswordRejected(error.message),
        _ => EnrollmentUnavailable(error),
      };
    }

    // El servidor cerró las demás sesiones y mandó un token nuevo para esta. Si
    // no se guarda, la siguiente petición saldría con el token viejo y esta misma
    // sesión se caería.
    final String? token = response['token'] as String?;
    if (token == null) {
      throw const EnrollmentUnavailable('el servidor no devolvió el token nuevo');
    }
    _api.useToken(token);
  }
}
