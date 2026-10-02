import 'package:flutter/material.dart';

import 'app/alertic_app.dart';
import 'core/errors/app_error_screen.dart';
import 'core/errors/error_reporter.dart';

void main() {
  ErrorReporter.runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorReporter.install();

    // En vez del recuadro gris de Flutter, una pantalla que explica que pasó.
    ErrorWidget.builder = (FlutterErrorDetails details) =>
        AppErrorScreen(details: details);

    runApp(AlerticApp.production());
  });
}
