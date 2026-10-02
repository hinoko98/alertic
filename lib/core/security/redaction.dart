/// Cómo se escriben los datos personales cuando salen de la pantalla.
///
/// Todo lo que va a un log, a una traza o a un reporte de errores pasa por
/// aquí. Los registros de una app escolar terminan en consolas, capturas y
/// tickets de soporte: ahí no puede quedar el nombre completo de un menor, su
/// código de registro ni su celular.
abstract final class Redact {
  static const String _mask = '••••';

  /// Deja ver el grupo del colegio y oculta el de la persona.
  /// `IICB-7K4P` queda en `IICB-••••`.
  ///
  /// Sirve para rastrear un caso en soporte sin que el log alcance para
  /// registrarse haciéndose pasar por otra persona.
  static String code(String? value) {
    if (value == null || value.isEmpty) {
      return _mask;
    }
    final List<String> parts = value.split('-');
    if (parts.length != 2) {
      return _mask;
    }
    return '${parts[0]}-$_mask';
  }

  /// Reduce el nombre a iniciales: `Laura Camila Pérez Gómez` queda en `L. P.`.
  static String name(String? fullName) {
    if (fullName == null) {
      return _mask;
    }
    final List<String> parts = fullName
        .split(' ')
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return _mask;
    }
    if (parts.length == 1) {
      return '${parts.first[0].toUpperCase()}.';
    }
    return '${parts.first[0].toUpperCase()}. ${parts.last[0].toUpperCase()}.';
  }

  /// Deja los tres primeros dígitos y los cuatro últimos.
  static String phone(String? value) {
    if (value == null) {
      return _mask;
    }
    final String digits = value.replaceAll(RegExp('[^0-9]'), '');
    if (digits.length < 7) {
      return _mask;
    }
    return '${digits.substring(0, 3)} $_mask ${digits.substring(digits.length - 4)}';
  }

  /// Un token de sesión nunca se escribe, ni en parte.
  static String token(String? _) => _mask;

  /// La ubicación se redondea: en un log alcanza con saber que había GPS, no
  /// dónde estaba la persona.
  static String coordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'sin ubicación';
    }
    return 'ubicación presente';
  }
}
