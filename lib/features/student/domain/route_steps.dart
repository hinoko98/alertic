import '../../alerts/domain/meeting_point.dart';

/// Los pasos de la ruta guiada hacia el punto de encuentro.
///
/// **Salen de lo que el colegio escribió**, no de un recorrido inventado: salir
/// del salón del estudiante, lo que dice la indicación del punto (partida en
/// frases) y llegar al punto. Si coordinación no escribió indicación, la ruta
/// tiene solo los dos pasos que sí se saben, en vez de rellenarla con direcciones
/// que nadie verificó.
List<String> routeSteps({
  required String classroom,
  required MeetingPoint point,
  String? homeroomTeacher,
}) {
  final List<String> hint = point.routeHint
      .split(RegExp(r'(?<=[.;])\s+|\s+→\s+'))
      .map((String part) => part.trim().replaceAll(RegExp(r'[.;]+$'), ''))
      .where((String part) => part.isNotEmpty)
      .toList();

  return <String>[
    'Sal del salón $classroom con calma, sin correr',
    ...hint,
    'Llega al punto ${point.code} · ${point.name}'
        '${homeroomTeacher == null ? '' : ' y busca a tu director de grupo, $homeroomTeacher'}',
  ];
}
