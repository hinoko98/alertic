import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/error_reporter.dart';

/// Lo que puede salir mal al hablar con el servidor del colegio.
///
/// Trae el mensaje que ve la persona. Cuando el servidor manda uno propio se
/// usa ese, porque está escrito para el caso concreto; si no, uno genérico.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;

  /// Código corto del error, tal como lo nombra la API: `codigo_usado`,
  /// `sin_permiso`.
  final String? code;

  /// La sesión dejó de valer y hay que registrarse otra vez.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}

/// Cliente HTTP de ALERTIC.
///
/// Un solo sitio donde se arma la petición, se pone el token, se interpreta la
/// respuesta y se traducen los errores. Las pantallas nunca ven un `statusCode`.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  /// Raíz de la API: `http://192.168.1.10:3000`.
  final String baseUrl;

  /// Cuánto se espera antes de rendirse.
  ///
  /// Corto a propósito: en una emergencia es mejor decir «no se pudo, reintento»
  /// que dejar a la persona mirando un indicador de carga.
  final Duration timeout;

  final http.Client _http;

  String? _token;

  /// Guarda el token de la sesión. Se manda en cada petición posterior.
  void useToken(String? token) => _token = token;

  /// Se llama cuando el servidor responde que la sesión ya no vale.
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send('PUT', path, body: body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send('PATCH', path, body: body);

  /// `DELETE` con cuerpo.
  ///
  /// Lo usa la baja de un dispositivo. El token va en el cuerpo y no en la ruta a
  /// propósito: las rutas quedan escritas en los logs de acceso del servidor y de
  /// cualquier proxy del colegio, y los cuerpos no.
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      _send('DELETE', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    final http.Request request = http.Request(method, uri)
      ..headers['accept'] = 'application/json';

    final String? token = _token;
    if (token != null) {
      request.headers['authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    try {
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(timeout);
      final String raw = await streamed.stream.bytesToString();
      return _parse(streamed.statusCode, raw);
    } on TimeoutException {
      throw const ApiException(
        'El colegio no responde. Revisa tu conexión e intenta otra vez.',
      );
    } on http.ClientException catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'red');
      throw const ApiException(
        'No pudimos conectarnos. Revisa tu conexión e intenta otra vez.',
      );
    }
  }

  Map<String, dynamic> _parse(int statusCode, String raw) {
    Map<String, dynamic> decoded;
    try {
      decoded = raw.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException catch (error, stack) {
      // El servidor respondió algo que no es JSON: un proxy, un portal cautivo
      // del wifi del colegio, una página de error.
      ErrorReporter.report(error, stack, context: 'respuesta ilegible');
      throw ApiException(
        'El colegio respondió algo que no entendemos.',
        statusCode: statusCode,
      );
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    }

    if (statusCode == 401) {
      onUnauthorized?.call();
    }

    throw ApiException(
      decoded['message'] as String? ?? 'No se pudo completar la operación.',
      statusCode: statusCode,
      code: decoded['error'] as String?,
    );
  }

  /// Abre el flujo de eventos del servidor (SSE) y devuelve cada mensaje ya
  /// interpretado.
  ///
  /// Se reconecta solo: si la conexión se cae en mitad de una emergencia, el
  /// celular vuelve a engancharse y lo primero que recibe es el estado actual.
  ///
  /// **Cancelar cierra la conexión de inmediato.** Está armado con un
  /// controlador y no con un `async*` a propósito: un generador que está
  /// esperando datos no atiende la cancelación hasta su siguiente `yield`, y los
  /// latidos del servidor no llegan a ninguno. En un colegio en calma eso dejaba
  /// el socket abierto indefinidamente, incluso con la sesión ya cerrada.
  Stream<Map<String, dynamic>> events(
    String path, {
    Duration retryDelay = const Duration(seconds: 3),
  }) {
    late final StreamController<Map<String, dynamic>> controller;
    StreamSubscription<Map<String, dynamic>>? connection;
    bool stopped = false;

    Future<void> run() async {
      while (!stopped) {
        try {
          final Stream<Map<String, dynamic>> stream = await _openEventStream(path);

          final Completer<void> ended = Completer<void>();
          connection = stream.listen(
            controller.add,
            onError: (Object error, StackTrace stack) {
              if (!ended.isCompleted) ended.completeError(error, stack);
            },
            onDone: () {
              if (!ended.isCompleted) ended.complete();
            },
            cancelOnError: true,
          );

          // Si se canceló mientras se conectaba, se suelta lo recién abierto.
          if (stopped) {
            await connection?.cancel();
            return;
          }
          await ended.future;
        } catch (error, stack) {
          ErrorReporter.report(error, stack, context: 'flujo de eventos');
          // Con la sesión vencida no tiene sentido reintentar cada tres
          // segundos: cada intento fallaría igual. La app ya fue avisada por
          // `onUnauthorized` y pedirá registrarse otra vez.
          if (error is ApiException && error.isUnauthorized) {
            return;
          }
        }

        if (stopped) {
          return;
        }
        await Future<void>.delayed(retryDelay);
      }
    }

    controller = StreamController<Map<String, dynamic>>(
      onListen: () => unawaited(run()),
      onCancel: () async {
        stopped = true;
        await connection?.cancel();
      },
    );
    return controller.stream;
  }

  /// Abre la conexión y devuelve los mensajes ya interpretados.
  Future<Stream<Map<String, dynamic>>> _openEventStream(String path) async {
    final http.Request request = http.Request('GET', Uri.parse('$baseUrl$path'))
      ..headers['accept'] = 'text/event-stream';

    final String? token = _token;
    if (token != null) {
      request.headers['authorization'] = 'Bearer $token';
    }

    final http.StreamedResponse response = await _http.send(request);
    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }
      throw ApiException(
        'No se pudo abrir el canal de alertas.',
        statusCode: response.statusCode,
      );
    }

    return _parseEvents(response.stream);
  }

  /// Parte el flujo de bytes en mensajes SSE.
  ///
  /// Es una cadena de transformadores y no un `async*`: así cancelar la
  /// suscripción cancela la lectura del socket en el acto.
  static Stream<Map<String, dynamic>> _parseEvents(Stream<List<int>> bytes) {
    final StringBuffer buffer = StringBuffer();

    return bytes
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .transform(
          StreamTransformer<String, Map<String, dynamic>>.fromHandlers(
            handleData: (String line, EventSink<Map<String, dynamic>> sink) {
              if (line.startsWith(':')) {
                // Latido del servidor, para que los proxies no cierren la
                // conexión.
                return;
              }
              if (line.startsWith('data:')) {
                buffer.write(line.substring(5).trim());
                return;
              }
              if (line.isEmpty && buffer.isNotEmpty) {
                final String payload = buffer.toString();
                buffer.clear();
                try {
                  final Object? decoded = jsonDecode(payload);
                  if (decoded is Map<String, dynamic>) {
                    sink.add(decoded);
                  }
                } on FormatException {
                  // Un evento ilegible se descarta; el siguiente trae el
                  // estado igual.
                }
              }
            },
          ),
        );
  }

  void close() => _http.close();
}
