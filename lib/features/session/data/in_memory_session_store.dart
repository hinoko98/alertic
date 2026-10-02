import '../domain/session.dart';
import '../domain/session_store.dart';

/// Guarda la sesión solo mientras la app está abierta.
///
/// Al cerrar la app hay que volver a registrarse. Es a propósito: es preferible
/// pedir el código otra vez que escribir un token en un almacenamiento sin
/// cifrar.
///
/// TODO(sesión): reemplazar por una implementación con `flutter_secure_storage`
/// cuando exista el backend, y agregar el borrado de la sesión cuando el
/// servidor responda 401.
class InMemorySessionStore implements SessionStore {
  Session? _session;

  @override
  Future<Session?> read() async {
    final Session? session = _session;
    if (session == null) {
      return null;
    }
    if (session.isExpired()) {
      await clear();
      return null;
    }
    return session;
  }

  @override
  Future<void> save(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
