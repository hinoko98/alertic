import 'dart:async';

import 'package:flutter/foundation.dart';

import '../errors/error_reporter.dart';
import 'geo.dart';
import 'location_service.dart';

/// Sigue la ubicación mientras una pantalla está abierta y guarda por dónde pasó
/// la persona.
///
/// Es de la pantalla, no de la app: al cerrarla se apaga el GPS ([dispose]). La
/// ubicación de un menor no se sigue cuando no hace falta.
class LocationTracker extends ChangeNotifier {
  LocationTracker(this._service);

  final LocationService _service;

  /// Cuántos puntos del recorrido se guardan; los más viejos se descartan.
  static const int _maxTrail = 300;

  /// Cuánto hay que moverse para anotar otro punto del recorrido, en metros.
  /// Evita llenar el rastro de puntos casi iguales por el ruido del GPS.
  static const double _minStep = 3;

  LocationAccess? _access;
  LocationFix? _fix;
  final List<GeoPoint> _trail = <GeoPoint>[];
  StreamSubscription<LocationFix>? _subscription;
  bool _disposed = false;

  /// El estado del permiso; null mientras se revisa.
  LocationAccess? get access => _access;

  /// La última ubicación, o null si todavía no llega.
  LocationFix? get fix => _fix;

  /// Por dónde ha pasado, del más viejo al más reciente.
  List<GeoPoint> get trail => List<GeoPoint>.unmodifiable(_trail);

  /// ¿Hay permiso y el GPS está dando datos?
  bool get isLive => _access == LocationAccess.granted && _fix != null;

  /// Revisa el permiso (y lo pide si [ask]) y empieza a escuchar.
  Future<void> start({bool ask = true}) async {
    try {
      _access = await _service.ensureAccess(ask: ask);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'permiso de ubicación');
      _access = LocationAccess.unsupported;
    }
    _notify();
    if (_access != LocationAccess.granted) return;

    await _subscription?.cancel();
    _subscription = _service.watch().listen(
      _onFix,
      onError: (Object error, StackTrace stack) {
        ErrorReporter.report(error, stack, context: 'ubicación en vivo');
      },
    );

    // El primer dato puede tardar en llegar por el flujo: se pide aparte para que
    // el punto azul aparezca cuanto antes.
    unawaited(_service.current().then((LocationFix? first) {
      if (first != null && _fix == null) _onFix(first);
    }));
  }

  /// Vuelve a intentar, por ejemplo tras dar el permiso en los ajustes.
  Future<void> retry() => start();

  /// Abre los ajustes del celular (cuando el permiso se negó para siempre).
  Future<void> openSettings() => _service.openSettings();

  void _onFix(LocationFix fix) {
    _fix = fix;
    if (_trail.isEmpty || Geo.distance(_trail.last, fix.point) >= _minStep) {
      _trail.add(fix.point);
      if (_trail.length > _maxTrail) _trail.removeAt(0);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
