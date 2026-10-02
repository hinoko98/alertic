/// Qué cambió en el colegio mientras la pantalla estaba abierta.
///
/// Son avisos de «algo cambió, vuelve a preguntar», **no datos**. El tablero, la
/// lista del grupo y el estado de los hijos se piden al servidor cada vez: así
/// la fuente de verdad sigue siendo una sola, y un aviso perdido no deja una
/// pantalla con números viejos para siempre (el siguiente trae el estado
/// completo).
enum LiveChange {
  /// Alguien reportó o fue marcado a salvo. Lo reciben docentes y coordinación;
  /// refresca el tablero y la lista del grupo.
  reports,

  /// Uno de los hijos del acudiente reportó. Solo les llega a sus acudientes.
  myChildren,

  /// Entró un aviso nuevo de una fuente externa (sismo, lluvia).
  hazardSignals,

  /// Llegó o cambió un reporte de emergencia de la comunidad. Lo reciben docentes
  /// y coordinación; vuelven a pedir la bandeja, donde el servidor les da solo
  /// lo que les corresponde.
  incidents,
}

/// Cambios en vivo, venga de donde venga.
///
/// Es una interfaz para que las pantallas no sepan si detrás hay un canal SSE
/// contra el servidor o nada: con datos de prueba y en las pruebas automáticas
/// la implementación no emite, y las pantallas funcionan igual con lo que
/// cargaron.
abstract interface class LiveUpdates {
  Stream<LiveChange> get changes;
}

/// Sin canal en vivo: no emite nunca.
class NoLiveUpdates implements LiveUpdates {
  const NoLiveUpdates();

  @override
  Stream<LiveChange> get changes => const Stream<LiveChange>.empty();
}
