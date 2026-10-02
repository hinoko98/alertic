import 'package:flutter/foundation.dart';

/// Cómo arranca la app.
///
/// **Siempre habla con el servidor del colegio.** No hay modo de prueba: lo que
/// se ve es lo que hay en la base de datos, aunque esté vacía.
///
/// La dirección se puede cambiar al compilar:
///
/// ```bash
/// flutter run --dart-define=ALERTIC_API=http://192.168.1.10:3000
/// ```
///
/// Sin ella se usa la que sirve para desarrollar en este mismo computador: el
/// emulador de Android ve el computador como `10.0.2.2`; el navegador y Windows,
/// como `localhost`. Un celular real necesita su propia dirección (por USB con
/// `adb reverse`, o la IP del computador en el wifi): ver el README.
abstract final class AppConfig {
  static const String _configured = String.fromEnvironment('ALERTIC_API');

  /// Raíz de la API.
  static String get apiBaseUrl {
    if (_configured.isNotEmpty) {
      return _configured;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  /// La API solo debe viajar por HTTPS fuera de la red del colegio.
  ///
  /// En desarrollo se permite `http` contra direcciones locales, que es como se
  /// prueba desde un celular conectado al wifi del instituto.
  static bool get isInsecureTransport =>
      apiBaseUrl.startsWith('http://') && !_isLocalAddress;

  static bool get _isLocalAddress {
    final Uri? uri = Uri.tryParse(apiBaseUrl);
    final String host = uri?.host ?? '';
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' || // el equipo anfitrión, visto desde el emulador
        host.startsWith('192.168.') ||
        host.startsWith('10.') ||
        host.startsWith('172.');
  }
}
