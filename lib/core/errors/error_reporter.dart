import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Un solo sitio por donde pasan todos los errores de la app.
///
/// Hoy los imprime en la consola con su pila completa; cuando el colegio tenga
/// la app en producción, aquí se enchufa Crashlytics o Sentry y no hay que
/// tocar el resto del código.
abstract final class ErrorReporter {
  /// Registra los manejadores globales. Se llama una vez, antes de `runApp`.
  static void install() {
    // Errores del framework: build, layout y paint. Sin esto, un error al
    // construir una pantalla solo se ve como un recuadro raro.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      report(
        details.exception,
        details.stack,
        context: details.context?.toDescription() ?? 'error de Flutter',
      );
    };

    // Errores asíncronos que nadie atrapó (futuros, callbacks de plugins).
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      report(error, stack, context: 'error asíncrono sin capturar');
      return true;
    };
  }

  /// Corre la app dentro de una zona que atrapa lo que se escape de [install].
  static void runGuarded(void Function() body) {
    runZonedGuarded(body, (Object error, StackTrace stack) {
      report(error, stack, context: 'error fuera del árbol de widgets');
    });
  }

  /// Deja una traza de algo que salió bien: una llamada al servidor, una
  /// alerta que llegó. Solo se imprime en debug.
  ///
  /// Nunca recibe datos personales sin pasar por `Redact`.
  static void trace(String message, {String context = 'app'}) {
    if (!kDebugMode) {
      return;
    }
    developer.log(message, name: 'ALERTIC · $context');
  }

  static void report(
    Object error,
    StackTrace? stack, {
    String context = 'sin contexto',
  }) {
    developer.log(
      '[$context] $error',
      name: 'ALERTIC',
      error: error,
      stackTrace: stack,
      level: 1000,
    );
    if (kDebugMode) {
      debugPrint('ALERTIC · $context → $error');
      if (stack != null) {
        debugPrintStack(stackTrace: stack, maxFrames: 12);
      }
    }
  }
}
