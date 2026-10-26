import 'dart:async';

import '../errors/error_reporter.dart';
import '../network/api_client.dart';

/// La última respuesta del servidor para lo que hay que poder leer sin red:
/// protocolos, puntos de encuentro, alertas anteriores.
///
/// **No es la fuente de verdad**: eso es la base del servidor (PostgreSQL). La
/// caché solo responde cuando el servidor no contesta, y nunca guarda la alerta
/// activa: una alerta vieja mostrada como si estuviera en curso es peor que
/// ninguna.
abstract interface class ResponseCache {
  Future<Map<String, dynamic>?> read(String key);

  Future<void> write(String key, Map<String, dynamic> body);

  /// Vacía todo. Lo guardado es del colegio (protocolos, puntos, alertas
  /// anteriores), no de la persona, así que cerrar sesión no lo exige; sirve
  /// para empezar de cero.
  Future<void> clear();
}

/// En memoria: para las pruebas y para el navegador, donde no hay SQLite.
class MemoryResponseCache implements ResponseCache {
  final Map<String, Map<String, dynamic>> _entries = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, Map<String, dynamic> body) async => _entries[key] = body;

  @override
  Future<void> clear() async => _entries.clear();
}

/// Pide [path] al servidor y guarda la respuesta. Si el servidor **no
/// responde** (sin red, caído, tiempo agotado), devuelve lo último guardado.
///
/// Si el servidor sí respondió con un error (401, 403, 404…), ese error se
/// propaga: la caché no debe tapar que la sesión venció o que algo ya no existe.
Future<Map<String, dynamic>> cachedGet(ApiClient api, ResponseCache? cache, String path) async {
  try {
    final Map<String, dynamic> body = await api.get(path);
    if (cache != null) {
      // Guardar no debe demorar ni romper la respuesta.
      unawaited(
        cache.write(path, body).catchError((Object error, StackTrace stack) {
          ErrorReporter.report(error, stack, context: 'guardar en caché');
        }),
      );
    }
    return body;
  } on ApiException catch (error) {
    if (error.statusCode != null || cache == null) rethrow;
    final Map<String, dynamic>? saved = await cache.read(path);
    if (saved == null) rethrow;
    ErrorReporter.trace('sin servidor: se usa lo guardado de $path', context: 'caché');
    return saved;
  }
}
