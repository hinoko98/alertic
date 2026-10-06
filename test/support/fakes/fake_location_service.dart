import 'dart:async';

import 'package:alertic/core/location/geo.dart';
import 'package:alertic/core/location/location_service.dart';

/// Un GPS de mentira para las pruebas: se le dice dónde está la persona y avisa.
///
/// Sirve para «caminar» a alguien por el colegio sin celular ni emulador.
class FakeLocationService implements LocationService {
  FakeLocationService({this.access = LocationAccess.granted});

  /// Lo que responde al pedir el permiso.
  LocationAccess access;

  /// Lo que responde [ensureAccess] la próxima vez que se llame (p. ej. después
  /// de «dar el permiso en los ajustes»).
  LocationAccess? accessAfterRetry;

  final StreamController<LocationFix> _controller = StreamController<LocationFix>.broadcast();

  int accessRequests = 0;
  int settingsOpened = 0;

  /// La ubicación que devuelve [current].
  LocationFix? last;

  /// Mueve a la persona.
  void moveTo(
    GeoPoint point, {
    double accuracy = 5,
    double? heading,
  }) {
    final LocationFix fix = LocationFix(
      point: point,
      accuracy: accuracy,
      at: DateTime.now(),
      heading: heading,
    );
    last = fix;
    _controller.add(fix);
  }

  @override
  Future<LocationAccess> ensureAccess({bool ask = true}) async {
    accessRequests++;
    final LocationAccess answer = accessAfterRetry != null && accessRequests > 1
        ? accessAfterRetry!
        : access;
    access = answer;
    return answer;
  }

  @override
  Stream<LocationFix> watch() => _controller.stream;

  @override
  Future<LocationFix?> current() async => last;

  @override
  Future<void> openSettings() async => settingsOpened++;

  Future<void> dispose() => _controller.close();
}
