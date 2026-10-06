import 'geo.dart';

/// En qué punto está el permiso de ubicación.
enum LocationAccess {
  /// Se puede usar.
  granted,

  /// La persona no lo dio (todavía o esta vez).
  denied,

  /// Lo negó para siempre: solo se arregla desde los ajustes del celular.
  deniedForever,

  /// El GPS del celular está apagado.
  serviceOff,

  /// Esta plataforma no tiene ubicación (pruebas, panel de escritorio).
  unsupported,
}

/// Dónde está el celular en un instante.
class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracy,
    required this.at,
    this.heading,
    this.speed,
  });

  final GeoPoint point;

  /// Margen de error en metros («GPS ±6 m»).
  final double accuracy;

  /// Hacia dónde camina, en grados desde el norte; null si está quieto o no se
  /// sabe. El GPS solo la da en movimiento.
  final double? heading;

  /// Velocidad en m/s, si se sabe.
  final double? speed;

  final DateTime at;
}

/// La ubicación del celular.
///
/// Es una interfaz para que las pantallas no dependan del paquete del GPS y las
/// pruebas puedan mover a una persona por el colegio sin celular.
///
/// **Solo se usa durante una evacuación o un repaso de ruta**, nunca de fondo: la
/// ubicación de un menor no se sigue cuando no hay emergencia. Nada de esto sale
/// del celular salvo lo que la persona decida compartir.
abstract interface class LocationService {
  /// Revisa el permiso y, con [ask], lo pide si falta.
  Future<LocationAccess> ensureAccess({bool ask = true});

  /// Cambios de ubicación mientras alguien escuche. Al dejar de escuchar se
  /// apaga el GPS.
  Stream<LocationFix> watch();

  /// La mejor ubicación que haya ahora mismo, o null si no se pudo.
  Future<LocationFix?> current();

  /// Abre los ajustes del celular para dar el permiso.
  Future<void> openSettings();
}

/// Sin ubicación: pruebas, Windows y web. Las pantallas lo dicen con honestidad
/// en vez de inventar un punto azul.
class NoLocationService implements LocationService {
  const NoLocationService();

  @override
  Future<LocationAccess> ensureAccess({bool ask = true}) async => LocationAccess.unsupported;

  @override
  Stream<LocationFix> watch() => const Stream<LocationFix>.empty();

  @override
  Future<LocationFix?> current() async => null;

  @override
  Future<void> openSettings() async {}
}
