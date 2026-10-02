import 'api_client.dart';

/// Con quién está hablando la app, y si responde.
///
/// Existe por un problema concreto: con `flutter run` a secas la app **no usa el
/// servidor**, usa datos de prueba en memoria. Se ve igual que la de verdad, y
/// durante días alguien puede creer que «no se conecta» cuando en realidad
/// nunca se le pidió que lo hiciera. Esto lo dice en pantalla.
abstract interface class ServerStatus {
  /// Dirección del servidor, o `null` si la app corre con datos de prueba.
  String? get address;

  /// Si la app corre con datos de prueba, sin servidor.
  bool get isDemo;

  /// Pregunta al servidor si está vivo.
  Future<bool> check();
}

/// Sin servidor: la app corre con datos de prueba en memoria.
class DemoServerStatus implements ServerStatus {
  const DemoServerStatus();

  @override
  String? get address => null;

  @override
  bool get isDemo => true;

  @override
  Future<bool> check() async => true;
}

/// Contra el servidor del colegio.
class ApiServerStatus implements ServerStatus {
  const ApiServerStatus(this._api);

  final ApiClient _api;

  /// `host:puerto`, sin el protocolo. Es lo que una persona puede comparar con
  /// la dirección que le muestra la consola del servidor.
  @override
  String get address {
    final Uri? uri = Uri.tryParse(_api.baseUrl);
    if (uri == null || uri.host.isEmpty) {
      return _api.baseUrl;
    }
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  @override
  bool get isDemo => false;

  @override
  Future<bool> check() async {
    try {
      await _api.get('/health');
      return true;
    } on ApiException {
      return false;
    }
  }
}
