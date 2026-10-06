import 'package:geolocator/geolocator.dart';

import 'geo.dart';
import 'location_service.dart';

/// La ubicación del celular, con el GPS de verdad (paquete `geolocator`).
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<LocationAccess> ensureAccess({bool ask = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceOff;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<LocationFix> watch() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        // Cada 2 m: suficiente para que el punto azul camine sin gastar batería
        // de más.
        distanceFilter: 2,
      ),
    ).map(_fix);
  }

  @override
  Future<LocationFix?> current() async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _fix(position);
    } catch (_) {
      // Sin señal a tiempo: se usa la última conocida, si la hay.
      final Position? last = await Geolocator.getLastKnownPosition();
      return last == null ? null : _fix(last);
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }

  static LocationFix _fix(Position position) => LocationFix(
        point: GeoPoint(position.latitude, position.longitude),
        accuracy: position.accuracy,
        at: position.timestamp,
        // El rumbo del GPS solo vale si la persona se está moviendo.
        heading: position.speed > 0.5 && position.heading >= 0 ? position.heading : null,
        speed: position.speed,
      );
}
