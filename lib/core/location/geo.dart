import 'dart:math' as math;

/// Una coordenada en la superficie de la Tierra (grados decimales).
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// Cuentas de geografía para un colegio: distancias de cientos de metros, así que
/// basta con la fórmula del haversine y una proyección plana local.
abstract final class Geo {
  static const double _earthRadius = 6371000;

  /// Velocidad de una persona evacuando con calma, en metros por segundo.
  ///
  /// Es una estimación para decir «1 min 40 s», no un dato medido: si la persona
  /// camina distinto, el tiempo se corrige solo con la distancia que le queda.
  static const double walkingSpeed = 1.2;

  static double _rad(double degrees) => degrees * math.pi / 180;

  /// Distancia en metros entre dos puntos.
  static double distance(GeoPoint a, GeoPoint b) {
    final double dLat = _rad(b.latitude - a.latitude);
    final double dLon = _rad(b.longitude - a.longitude);
    final double h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * _earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Rumbo de [from] hacia [to], en grados desde el norte (0–360, a la derecha).
  static double bearing(GeoPoint from, GeoPoint to) {
    final double dLon = _rad(to.longitude - from.longitude);
    final double y = math.sin(dLon) * math.cos(_rad(to.latitude));
    final double x = math.cos(_rad(from.latitude)) * math.sin(_rad(to.latitude)) -
        math.sin(_rad(from.latitude)) * math.cos(_rad(to.latitude)) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Metros al este (x) y al norte (y) de [origin]. Plana, válida a escala de
  /// colegio.
  static ({double x, double y}) toMeters(GeoPoint origin, GeoPoint point) {
    final double x = _rad(point.longitude - origin.longitude) *
        _earthRadius *
        math.cos(_rad(origin.latitude));
    final double y = _rad(point.latitude - origin.latitude) * _earthRadius;
    return (x: x, y: y);
  }

  /// Texto de una distancia: «45 m», «1,2 km».
  static String distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  /// Texto de un tiempo caminando: «40 s», «1 min 40 s», «3 min».
  static String walkLabel(double meters) {
    final int seconds = (meters / walkingSpeed).round();
    if (seconds < 60) return '${math.max(seconds, 1)} s';
    final int minutes = seconds ~/ 60;
    final int rest = seconds % 60;
    if (minutes >= 5 || rest < 5) return '$minutes min';
    return '$minutes min $rest s';
  }

  /// Hacia dónde queda algo, en palabras: «norte», «sureste».
  static String compassWord(double bearing) {
    const List<String> names = <String>[
      'norte',
      'noreste',
      'este',
      'sureste',
      'sur',
      'suroeste',
      'oeste',
      'noroeste',
    ];
    return names[((bearing % 360) / 45).round() % 8];
  }

  /// Lo que hay que girar para quedar mirando al destino, de -180 a 180
  /// (positivo: a la derecha). Sirve para dibujar la flecha relativa a cómo va
  /// la persona.
  static double turnTo(double heading, double bearing) {
    double diff = (bearing - heading) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }
}
