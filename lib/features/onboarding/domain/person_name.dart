/// Cómo se abrevia un nombre en las pantallas.
///
/// En Colombia la matrícula trae nombre completo con dos apellidos, y a la
/// persona se la llama por el primer nombre y el **primer** apellido: Laura
/// Camila Pérez Gómez es «Laura Pérez», no «Laura Gómez». Tomar la última
/// palabra da el apellido materno y suena a otra persona.
///
/// Con cuatro palabras el primer apellido es la tercera (dos nombres y dos
/// apellidos). Con **tres**, la segunda: en Colombia casi todos tienen dos
/// apellidos, así que tres palabras son un nombre y dos apellidos —Carlos
/// Jaimes Duarte es «Carlos Jaimes», no «Carlos Duarte»—. Suponer lo contrario
/// (dos nombres y un apellido) le ponía a cada persona su apellido materno. Con
/// dos, la segunda.
///
/// Es una heurística: sin saber cuál palabra es cuál, un nombre de tres palabras
/// con dos nombres de pila («Laura Camila Pérez») queda como «Laura Camila». Es
/// el error menos frecuente, y el que menos confunde: sigue siendo el nombre de
/// pila y no el apellido de otra persona.
abstract final class PersonName {
  /// Primer nombre y primer apellido: `Laura Pérez`.
  static String short(String fullName) {
    final List<String> parts = _parts(fullName);
    if (parts.length < 2) {
      return fullName.trim();
    }
    return '${parts.first} ${_firstSurname(parts)}';
  }

  /// Iniciales para un avatar: `LP`.
  static String initials(String fullName) {
    final List<String> parts = _parts(fullName);
    if (parts.isEmpty) {
      return '';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final String surname = _firstSurname(parts);
    return '${parts.first.substring(0, 1)}${surname.substring(0, 1)}'
        .toUpperCase();
  }

  static String _firstSurname(List<String> parts) =>
      parts.length >= 4 ? parts[2] : parts[1];

  static List<String> _parts(String fullName) => fullName
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
}
