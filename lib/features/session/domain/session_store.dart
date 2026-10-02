import 'session.dart';

/// Dónde vive la sesión entre aperturas de la app.
///
/// Es una interfaz porque el almacenamiento real depende de la plataforma y
/// tiene que ser cifrado: en Android, `EncryptedSharedPreferences`; en iOS, el
/// llavero. Hoy la implementación es en memoria, para no guardar un token de
/// verdad en un sitio inseguro mientras el backend no existe.
abstract interface class SessionStore {
  Future<Session?> read();

  Future<void> save(Session session);

  /// Borra la sesión del dispositivo. Se llama al cerrar sesión y cuando el
  /// servidor responde que el token ya no vale.
  Future<void> clear();
}
