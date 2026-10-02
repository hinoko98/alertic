/// Correo y contraseña de un docente o un administrador.
///
/// Solo se construye con [Credentials.validated], que revisa la forma antes de
/// mandar nada. No es seguridad —quien valida de verdad es el servidor— sino
/// cortesía: le dice a la persona que le falta el arroba sin hacerla esperar un
/// viaje a la red, y le ahorra al servidor peticiones que iban a fallar.
class Credentials {
  const Credentials._({required this.email, required this.password});

  /// Tope de lo que se acepta escribir. Sin tope, un pegado accidental de medio
  /// documento se convierte en una petición de 60 KB.
  static const int maxEmailLength = 160;
  static const int maxPasswordLength = 200;

  /// Mínimo que exige el colegio al crear la contraseña. Aquí solo se usa para
  /// no mandar intentos obviamente cortos; la regla de verdad está en el
  /// servidor, que es quien la aplica al crearla.
  static const int minPasswordLength = 10;

  /// Ya en minúsculas y sin espacios.
  final String email;

  /// La contraseña tal cual la escribió la persona.
  ///
  /// No se recorta ni se cambia de mayúsculas: un espacio al final puede ser
  /// parte de la contraseña, y «arreglarlo» dejaría a alguien fuera de su propia
  /// cuenta sin explicación.
  final String password;

  /// Revisa la forma. Devuelve `null` si algo no cuadra, junto con el motivo.
  static (Credentials?, String?) tryBuild({
    required String email,
    required String password,
  }) {
    // El teclado del celular pone mayúscula al inicio: sin normalizar, quien
    // escriba `Carlos@iic.edu.co` no entraría nunca y no sabría por qué.
    final String cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty) {
      return (null, 'Escribe tu correo.');
    }
    if (cleanEmail.length > maxEmailLength) {
      return (null, 'Ese correo es demasiado largo.');
    }
    if (!_looksLikeEmail(cleanEmail)) {
      return (null, 'Ese correo está incompleto. Revisa que tenga @ y punto.');
    }
    if (password.isEmpty) {
      return (null, 'Escribe tu contraseña.');
    }
    if (password.length > maxPasswordLength) {
      return (null, 'Esa contraseña es demasiado larga.');
    }

    return (Credentials._(email: cleanEmail, password: password), null);
  }

  /// Comprobación deliberadamente simple.
  ///
  /// No intenta validar el estándar de correos, que es mucho más raro de lo que
  /// parece y rechazaría direcciones legítimas. Solo descarta lo que
  /// evidentemente no es un correo: algo, arroba, algo, punto, algo.
  static bool _looksLikeEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  /// Nunca imprime la contraseña, ni siquiera su longitud.
  @override
  String toString() => 'Credentials($email)';
}
