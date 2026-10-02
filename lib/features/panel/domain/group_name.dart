/// Cómo se escribe el nombre de un grupo: `10° B`.
///
/// El servidor acepta **un solo formato** y rechaza lo demás. Aquí se arregla lo
/// que alguien escribe a mano antes de mandarlo, para que «10b», «10 B» y «10° b»
/// no acaben siendo tres grupos distintos —o un error— cuando coordinación crea
/// un grupo que todavía no existe.
abstract final class GroupName {
  static final RegExp _loose = RegExp(r'^\s*(1[01]|[1-9])\s*°?\s*([A-Za-z])\s*$');

  /// El nombre en su forma canónica, o `null` si no es un grupo (de 1° a 11°,
  /// con una letra).
  static String? normalize(String raw) {
    final RegExpMatch? match = _loose.firstMatch(raw);
    if (match == null) {
      return null;
    }
    return '${match.group(1)}° ${match.group(2)!.toUpperCase()}';
  }

  /// Orden natural: `6° A` antes que `10° A`. Ordenar el texto pondría `10°`
  /// antes que `6°`.
  static int compare(String a, String b) {
    final int byNumber = _number(a).compareTo(_number(b));
    return byNumber != 0 ? byNumber : a.compareTo(b);
  }

  static int _number(String group) => int.tryParse(group.split('°').first) ?? 99;
}
