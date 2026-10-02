import 'dart:async';

import '../../../core/network/api_client.dart';
import '../domain/live_updates.dart';

/// La única conexión en vivo con el servidor.
///
/// Varias partes de la app necesitan escuchar el mismo canal: la alerta activa,
/// el tablero, la lista del grupo, los hijos del acudiente. Si cada una abriera
/// el suyo, un teléfono tendría cuatro conexiones abiertas al servidor del
/// colegio por una sola persona, y 1.248 personas serían cinco mil.
///
/// Esta clase abre **una** conexión cuando aparece el primer oyente y la cierra
/// cuando se va el último, y reparte lo que llega a todos.
class ApiEventHub {
  ApiEventHub(this._api) {
    _controller = StreamController<Map<String, dynamic>>.broadcast(
      onListen: _open,
      onCancel: _close,
    );
  }

  static const String _path = '/alerts/stream';

  final ApiClient _api;

  late final StreamController<Map<String, dynamic>> _controller;
  StreamSubscription<Map<String, dynamic>>? _connection;

  /// Lo que manda el servidor, ya interpretado como JSON.
  Stream<Map<String, dynamic>> get events => _controller.stream;

  void _open() {
    // `ApiClient.events` se reconecta solo si la conexión se cae: lo que llega
    // aquí es un flujo continuo, no hay que reintentar.
    _connection = _api.events(_path).listen(
          _controller.add,
          onError: _controller.addError,
        );
  }

  Future<void> _close() async {
    await _connection?.cancel();
    _connection = null;
  }
}

/// Los cambios en vivo contra el servidor.
///
/// Traduce los mensajes del canal a [LiveChange]. Lo que no reconoce lo ignora:
/// un servidor más nuevo puede mandar tipos que esta versión de la app no
/// conoce, y eso no es un error.
class ApiLiveUpdates implements LiveUpdates {
  const ApiLiveUpdates(this._hub);

  final ApiEventHub _hub;

  @override
  Stream<LiveChange> get changes => _hub.events
      .map((Map<String, dynamic> event) => switch (event['type']) {
            'reporte' => LiveChange.reports,
            'hijo_reporto' => LiveChange.myChildren,
            'aviso_externo' => LiveChange.hazardSignals,
            'incidente' => LiveChange.incidents,
            _ => null,
          })
      .where((LiveChange? change) => change != null)
      .cast<LiveChange>();
}
