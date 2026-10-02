import '../../session/domain/session.dart';
import '../domain/credentials.dart';

/// La otra puerta de entrada: correo y contraseña.
///
/// Es una interfaz aparte de [EnrollmentRepository] y no un método más suyo, a
/// propósito. Son dos caminos con dos públicos y dos reglas distintas:
///
/// - La matrícula responde «¿a quién apunta este código?», y la usan un
///   estudiante de sexto y una madre de familia registrándose una sola vez.
/// - Esta responde «¿es quien dice ser?», y la usa quien puede evacuar el
///   colegio, cada vez que abre la app.
///
/// Juntarlas en una sola interfaz obligaría a la pantalla de código a conocer
/// las contraseñas y a la de contraseñas a conocer los códigos.
abstract interface class CredentialsRepository {
  /// Abre sesión con correo y contraseña.
  ///
  /// El servidor decide si esas credenciales valen **y** si ese rol entra por
  /// aquí. La app no comprueba nada de eso: un docente con la app modificada
  /// seguiría sin poder entrar como administrador.
  ///
  /// Lanza un [EnrollmentFailure] si no se pudo.
  Future<Session> signIn(Credentials credentials);

  /// Suelta la sesión de este cliente: a partir de aquí no se manda ningún token.
  ///
  /// Borrar la sesión guardada no alcanza: el cliente de red conserva el último
  /// token en memoria y, sin esto, el canal en vivo y las peticiones siguientes
  /// seguirían saliendo como la persona que ya cerró sesión.
  Future<void> signOut();

  /// Cambia la contraseña de quien está dentro.
  ///
  /// Pide la actual aunque haya sesión: un celular prestado y desbloqueado no
  /// basta para quedarse con la cuenta de quien puede evacuar el colegio. Al
  /// cambiarla, el servidor cierra las demás sesiones de esta persona y esta
  /// sigue abierta con un token nuevo.
  ///
  /// Lanza un [EnrollmentFailure] si no se pudo.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
