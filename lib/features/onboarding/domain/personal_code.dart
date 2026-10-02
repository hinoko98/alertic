import '../../../core/security/redaction.dart';

/// código personal que el colegio le entrega a cada persona.
///
/// Formato: `XXXX-XXXX`. Los cuatro primeros son del colegio (iguales para todos)
/// y los cuatro últimos de la persona. Son ocho caracteres alfanuméricos.
class PersonalCode {
  const PersonalCode._(this.digits);

  /// Caracteres de cada grupo.
  static const int groupLength = 4;

  /// Cantidad de grupos que escribe la persona.
  static const int groupCount = 2;

  /// Total de caracteres, sin contar el guion.
  static const int digitsLength = groupLength * groupCount;

  static final RegExp _allowed = RegExp('^[A-Z0-9]{$digitsLength}\$');

  /// Los ocho caracteres, en mayúsculas y sin separadores.
  final String digits;

  /// Devuelve el código si [input] tiene el formato correcto, o `null` si no.
  /// Acepta minúsculas, espacios y guiones para poder pegar el código tal como
  /// aparece impreso en el carné.
  static PersonalCode? tryParse(String input) {
    final String normalized =
        input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

    if (!_allowed.hasMatch(normalized)) {
      return null;
    }
    return PersonalCode._(normalized);
  }

  /// Código completo como se ve impreso: `IICB-7K4P`.
  String get formatted =>
      '${digits.substring(0, groupLength)}-${digits.substring(groupLength)}';

  /// Versión para logs: deja el grupo del colegio y oculta el de la persona.
  ///
  /// Es `toString` a propósito. Un código completo en un log alcanza para que
  /// alguien se registre haciéndose pasar por otra persona, y `toString` es
  /// justo lo que se cuela sin querer en una interpolación o en una traza.
  /// Para mostrarlo en pantalla está [formatted].
  @override
  String toString() => Redact.code(formatted);

  @override
  bool operator ==(Object other) =>
      other is PersonalCode && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;
}
