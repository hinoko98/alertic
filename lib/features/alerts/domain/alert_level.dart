/// Los tres niveles del protocolo del colegio, del más leve al más grave.
///
/// El orden importa: `severity` decide cuánto interrumpe la alerta y si exige
/// respuesta. No se agregan niveles sin revisar el protocolo con coordinación.
enum AlertLevel {
  amarilla(wire: 'amarilla', label: 'AMARILLA', meaning: 'Estar atentos', severity: 1),
  naranja(
    wire: 'naranja',
    label: 'NARANJA',
    meaning: 'Prepararse para salir',
    severity: 2,
  ),
  roja(wire: 'roja', label: 'ROJA', meaning: 'Evacuar ya', severity: 3);

  const AlertLevel({
    required this.wire,
    required this.label,
    required this.meaning,
    required this.severity,
  });

  /// Valor con el que viaja el nivel en la API.
  final String wire;

  final String label;
  final String meaning;

  /// 1 es la más leve. Se compara, nunca se muestra.
  final int severity;

  /// La roja exige que cada persona responda: el tablero del colegio se arma
  /// con esas respuestas, así que sin respuesta nadie sabe quién falta.
  bool get requiresResponse => this == AlertLevel.roja;

  /// De naranja para arriba la alerta toma la pantalla completa.
  bool get takesOverScreen => severity >= naranja.severity;

  /// Convierte lo que responde el servidor. Devuelve `null` si el valor no es
  /// uno de los tres niveles: una alerta que no se entiende no se muestra a
  /// medias, se rechaza.
  static AlertLevel? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final String normalized = value.trim().toLowerCase();
    for (final AlertLevel level in values) {
      if (level.wire == normalized) {
        return level;
      }
    }
    return null;
  }
}
