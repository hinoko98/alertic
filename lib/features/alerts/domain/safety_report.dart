/// Cómo está la persona durante una alerta.
enum SafetyStatus {
  safe(wire: 'a_salvo', label: 'ESTOY BIEN'),
  needsHelp(wire: 'necesita_ayuda', label: 'NECESITO AYUDA');

  const SafetyStatus({required this.wire, required this.label});

  final String wire;
  final String label;
}

/// Dónde dice estar. Son opciones cerradas a propósito: en una evacuación nadie
/// escribe, y una lista fija es lo único que el docente puede leer de un
/// vistazo en la lista del grupo.
enum ReportedLocation {
  atMeetingPoint(wire: 'punto_encuentro', label: 'En el punto de encuentro'),
  inClassroom(wire: 'salon', label: 'Sigo en el salón'),
  outsideSchool(wire: 'fuera', label: 'Estoy fuera del colegio');

  const ReportedLocation({required this.wire, required this.label});

  final String wire;
  final String label;
}

/// Lo que la persona le manda al colegio durante una alerta.
class SafetyReport {
  const SafetyReport({
    required this.alertId,
    required this.status,
    required this.location,
    required this.reportedAt,
    this.coordinates,
  });

  final String alertId;
  final SafetyStatus status;
  final ReportedLocation location;
  final DateTime reportedAt;

  /// Ubicación del GPS, si la persona la autorizó. Es opcional a propósito: el
  /// reporte vale igual sin ella, y sin permiso no se manda nada.
  final GeoPoint? coordinates;
}

/// Un punto del GPS con su margen de error.
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}
