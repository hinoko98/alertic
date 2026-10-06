import 'package:flutter/material.dart';

import '../core/errors/error_reporter.dart';
import '../features/assistant/presentation/assistant_screen.dart';
import '../features/onboarding/domain/enrollment.dart';
import '../features/onboarding/presentation/screens/confirm_identity_screen.dart';
import '../features/onboarding/presentation/screens/enter_code_screen.dart';
import '../features/onboarding/presentation/screens/family_setup_screen.dart';
import '../features/onboarding/presentation/screens/splash_screen.dart';
import '../features/onboarding/presentation/screens/who_are_you_screen.dart';
import '../features/onboarding/presentation/screens/permissions_screen.dart';
import '../features/onboarding/presentation/screens/sign_in_screen.dart';
import '../features/onboarding/presentation/screens/welcome_screen.dart';
import '../features/session/domain/session.dart';
import '../features/support/presentation/support_chat_screen.dart';
import 'app_shell.dart';

/// Rutas de la app. Por ahora solo el registro (bloque A del diseño).
///
/// Los nombres son de un solo segmento a propósito: Flutter arma la pila
/// inicial segmento por segmento, así que una ruta anidada cuyo padre no existe
/// en la tabla cae de vuelta al inicio.
abstract final class AppRoutes {
  /// La entrada animada. La app de verdad arranca aquí; las pruebas, en la
  /// bienvenida.
  static const String splash = '/entrada';
  static const String welcome = '/';
  static const String whoAreYou = '/quien-eres';
  static const String enterCode = '/codigo';
  static const String confirmIdentity = '/confirmar-identidad';
  static const String permissions = '/permisos';

  /// A quién se avisa cuando el estudiante está a salvo: el último paso.
  static const String familySetup = '/familia';

  /// «Ya tengo cuenta»: docentes y administradores.
  static const String signIn = '/ingresar';

  /// La app ya registrada. Recibe la sesión emitida por el servidor.
  static const String home = '/inicio';

  /// El chat con el soporte del colegio (estudiantes y acudientes).
  static const String chat = '/chat';

  /// El asistente de riesgos: el botón «Ayuda».
  static const String assistant = '/asistente';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      splash => _route(const SplashScreen(), settings),
      welcome => _route(const WelcomeScreen(), settings),
      whoAreYou => _route(const WhoAreYouScreen(), settings),
      familySetup => _familySetupRoute(settings),
      enterCode => _route(const EnterCodeScreen(), settings),
      permissions => _route(const PermissionsScreen(), settings),
      signIn => _route(const SignInScreen(), settings),
      confirmIdentity => _confirmIdentityRoute(settings),
      home => _homeRoute(settings),
      chat => _route(const SupportChatScreen(), settings),
      assistant => _route(const AssistantScreen(), settings),
      _ => null,
    };
  }

  static Route<dynamic> _familySetupRoute(RouteSettings settings) {
    final Object? session = settings.arguments;
    if (session is! Session) {
      ErrorReporter.report(
        ArgumentError.value(session, 'arguments', 'Falta la sesión'),
        StackTrace.current,
        context: 'navegación',
      );
      return _route(const WelcomeScreen(), const RouteSettings(name: welcome));
    }
    return _route(FamilySetupScreen(session: session), settings);
  }

  /// Ruta para un nombre que no existe. Nunca debería pasar, pero si pasa la
  /// persona vuelve al inicio en vez de quedarse con la pantalla en blanco.
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    ErrorReporter.report(
      StateError('Ruta desconocida: ${settings.name}'),
      StackTrace.current,
      context: 'navegación',
    );
    return _route(const WelcomeScreen(), const RouteSettings(name: welcome));
  }

  static Route<dynamic> _confirmIdentityRoute(RouteSettings settings) {
    final Object? enrollment = settings.arguments;
    // Solo un perfil que entra por código: un docente no pasa por esta pantalla.
    if (enrollment is! CodeEnrollment) {
      // Llegar aquí sin perfil significa que alguien navegó saltándose la
      // validación del código: se registra y se devuelve al inicio.
      ErrorReporter.report(
        ArgumentError.value(
          enrollment,
          'arguments',
          'La pantalla de confirmar identidad necesita un perfil con código',
        ),
        StackTrace.current,
        context: 'navegación',
      );
      return _route(const WelcomeScreen(), const RouteSettings(name: welcome));
    }
    return _route(ConfirmIdentityScreen(enrollment: enrollment), settings);
  }

  /// La app solo se abre con una sesión válida. Sin ella se vuelve al inicio:
  /// es la única forma de entrar, y no se puede saltar navegando.
  static Route<dynamic> _homeRoute(RouteSettings settings) {
    final Object? session = settings.arguments;
    if (session is! Session) {
      ErrorReporter.report(
        ArgumentError.value(
          session,
          'arguments',
          'La app necesita una sesión emitida por el servidor',
        ),
        StackTrace.current,
        context: 'navegación',
      );
      return _route(const WelcomeScreen(), const RouteSettings(name: welcome));
    }
    if (session.isExpired()) {
      ErrorReporter.report(
        StateError('La sesión ya venció'),
        StackTrace.current,
        context: 'navegación',
      );
      return _route(const WelcomeScreen(), const RouteSettings(name: welcome));
    }
    return _route(AppShell(session: session), settings);
  }

  static Route<dynamic> _route(Widget screen, RouteSettings settings) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => screen,
      settings: settings,
    );
  }
}
