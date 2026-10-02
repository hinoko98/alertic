/// Rol con el que una persona usa ALERTIC.
///
/// Lo decide el colegio al cargar la matrícula y lo devuelve el servidor junto
/// con el perfil. La app **nunca** lo deduce del código que se escribió ni del
/// correo con el que se entró: si el rol se decidiera en el celular, bastaría
/// con modificar la app para entrar como docente y emitir alertas a todo el
/// instituto.
enum UserRole {
  estudiante(wire: 'estudiante', label: 'ESTUDIANTE'),
  docente(wire: 'docente', label: 'DOCENTE'),
  acudiente(wire: 'acudiente', label: 'ACUDIENTE'),
  administrador(wire: 'administrador', label: 'ADMINISTRADOR');

  const UserRole({required this.wire, required this.label});

  final String wire;
  final String label;

  /// ¿Entra con el código de un solo uso que entrega secretaría?
  ///
  /// Solo estudiantes y acudientes. Son mil doscientas personas que hay que
  /// registrar en pocos días, y pedirles crear una cuenta sería pedirle un
  /// correo a un niño de sexto y a una madre que quizá no tiene uno.
  ///
  /// La regla vive aquí y en el servidor, en `domain/constants.ts`. La del
  /// servidor es la que manda: esta solo sirve para no mostrar una pantalla que
  /// de todos modos iba a ser rechazada.
  bool get usesCode => this == estudiante || this == acudiente;

  /// ¿Entra con correo y contraseña?
  ///
  /// Los que pueden **emitir una alerta para todo el colegio**. Un código
  /// impreso se queda sobre un escritorio, se fotografía y no se puede cambiar;
  /// una contraseña se cambia y no viaja en papel. Quien tiene el poder de
  /// evacuar el instituto no entra con un papelito.
  bool get usesPassword => this == docente || this == administrador;

  /// ¿La alerta le toma la pantalla completa hasta que responda?
  ///
  /// Solo a quien tiene que evacuar del edificio. El acudiente está afuera y el
  /// administrador está dirigiendo la evacuación: a los dos, taparles la
  /// pantalla les esconde justo lo que necesitan mirar.
  bool get mustRespondOnScreen => this == estudiante || this == docente;

  static UserRole? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.trim().toLowerCase();
    for (final UserRole role in values) {
      if (role.wire == normalized) {
        return role;
      }
    }
    return null;
  }
}
