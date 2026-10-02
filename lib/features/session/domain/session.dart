import '../../../core/session/user_role.dart';
import '../../onboarding/domain/enrollment.dart';

/// Sesión abierta en este celular.
///
/// La emite el servidor cuando la persona confirma su identidad. El token es la
/// prueba de que el colegio la reconoció: toda llamada posterior lo lleva, y
/// ninguna pantalla decide nada por su cuenta a partir de él.
class Session {
  const Session({
    required this.token,
    required this.profile,
    required this.expiresAt,
  });

  /// Token emitido por el servidor. No se muestra, no se registra y no se
  /// guarda en texto plano.
  final String token;

  /// Perfil tal como lo tiene el colegio.
  final Enrollment profile;

  final DateTime expiresAt;

  /// El rol viene del perfil, que viene del servidor.
  UserRole get role => profile.role;

  bool isExpired({DateTime? now}) =>
      (now ?? DateTime.now()).isAfter(expiresAt);

  /// Nunca imprime el token ni el nombre completo.
  @override
  String toString() => 'Session(rol: ${role.wire}, vence: $expiresAt)';
}
