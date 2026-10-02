/// Lo que puede salir mal al validar un código contra la matrícula.
///
/// Cada caso trae el mensaje que ve la persona: son adolescentes y familias en
/// una emergencia, así que el mensaje dice qué hacer, no qué falló.
sealed class EnrollmentFailure implements Exception {
  const EnrollmentFailure(this.message);

  /// Mensaje en español, listo para mostrar en pantalla.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// El código no existe en la matrícula, o quedó mal escrito.
final class CodeNotFound extends EnrollmentFailure {
  const CodeNotFound()
      : super(
          'Ese código no aparece en la matrícula. Revisa el carné o pídelo '
          'en secretaría.',
        );
}

/// El código ya se usó: es de un solo uso, secretaría debe emitir otro.
final class CodeAlreadyUsed extends EnrollmentFailure {
  const CodeAlreadyUsed()
      : super(
          'Ese código ya se usó en otro celular. Pide uno nuevo en '
          'secretaría.',
        );
}

/// El código no se usó dentro de su hora y venció.
final class CodeExpired extends EnrollmentFailure {
  const CodeExpired()
      : super('Ese código venció. Pide uno nuevo en secretaría.');
}

/// No se pudo consultar el panel del colegio: sin datos, servidor caído o
/// respuesta que no se entiende.
final class EnrollmentUnavailable extends EnrollmentFailure {
  const EnrollmentUnavailable([this.cause])
      : super(
          // Sin mencionar «código»: este mensaje también sale al iniciar sesión
          // con correo, donde no hay ningún código que confirmar.
          'No pudimos conectarnos con el colegio. Revisa tu conexión e intenta '
          'otra vez.',
        );

  /// Error original. No se le muestra a la persona: sirve para el log.
  final Object? cause;

  @override
  String toString() => 'EnrollmentUnavailable: $message (causa: $cause)';
}

/// Esa persona no entra por código, sino con correo y contraseña.
///
/// Pasa si alguien escribe un código de docente que quedó de antes, o si el
/// colegio le entregó un carné a quien no le correspondía. El mensaje lo escribe
/// el servidor, que es quien conoce la regla.
final class WrongAuthMethod extends EnrollmentFailure {
  const WrongAuthMethod(super.message);
}

/// El correo o la contraseña no coinciden.
///
/// A propósito no distingue cuál de los dos falló: decir «ese correo no existe»
/// le confirma a quien prueba cuáles cuentas del colegio son reales.
final class InvalidCredentials extends EnrollmentFailure {
  const InvalidCredentials()
      : super('Correo o contraseña incorrectos.');
}

/// Demasiados intentos fallidos seguidos.
final class TooManyAttempts extends EnrollmentFailure {
  const TooManyAttempts()
      : super(
          'Demasiados intentos fallidos. Espera unos minutos e inténtalo de '
          'nuevo.',
        );
}

/// La contraseña actual que escribió la persona al cambiarla no coincide.
///
/// Es un caso aparte de [InvalidCredentials]: aquí la sesión está bien y no hay
/// correo que revisar. Mezclarlos le diría «correo o contraseña incorrectos» a
/// alguien que solo se equivocó en un campo.
final class WrongCurrentPassword extends EnrollmentFailure {
  const WrongCurrentPassword() : super('La contraseña actual no es correcta.');
}

/// El servidor no aceptó la contraseña nueva. Trae su motivo, que lo escribe el
/// servidor porque es quien conoce la regla («al menos 10 caracteres»).
final class PasswordRejected extends EnrollmentFailure {
  const PasswordRejected(super.message);
}
