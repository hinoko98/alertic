/// Fechas y horas como se dicen en Colombia: «jueves · 10:00 a. m.», «15 de octubre».
abstract final class Fmt {
  static const List<String> _months = <String>[
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static const List<String> _monthsShort = <String>[
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static const List<String> _weekdays = <String>[
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  /// `10:42 a. m.`
  static String hour(DateTime at) {
    final int h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'a. m.' : 'p. m.'}';
  }

  /// `15 de octubre`
  static String dayMonth(DateTime at) => '${at.day} de ${_months[at.month - 1]}';

  /// `15 oct`
  static String dayMonthShort(DateTime at) => '${at.day} ${_monthsShort[at.month - 1]}';

  /// `Octubre`
  static String monthName(DateTime at) {
    final String name = _months[at.month - 1];
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  /// `OCT`
  static String monthTag(DateTime at) => _monthsShort[at.month - 1].toUpperCase();

  /// `jueves`
  static String weekday(DateTime at) => _weekdays[at.weekday - 1];

  /// `hace 2 min`, `hace 3 h`, `hace 4 d`.
  static String ago(DateTime at, {DateTime? now}) {
    final Duration diff = (now ?? DateTime.now()).difference(at);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  /// `3:10` a partir de segundos.
  static String minutesSeconds(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
