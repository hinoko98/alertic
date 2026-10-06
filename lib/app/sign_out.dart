import 'package:flutter/material.dart';

import '../core/notifications/device_registrar.dart';
import '../core/theme/app_colors.dart';
import 'app_routes.dart';
import 'app_scope.dart';

/// Cierra la sesión de este celular.
///
/// El orden importa, y por eso vive en un solo sitio:
///
/// 1. **Se da de baja el celular en el colegio**, mientras la sesión todavía
///    vale. Si se soltara primero, la baja saldría sin permiso y quedaría
///    registrado un celular que ya no es de esa persona.
/// 2. Se borra la sesión guardada.
/// 3. Se suelta el token del cliente de red.
///
/// Ningún paso puede impedir los siguientes: cerrar sesión no puede fallar
/// porque se cayó la red.
Future<void> signOutOfDevice(AppScope scope) async {
  await DeviceEnrollment(
    notifications: scope.notifications,
    registrar: scope.deviceRegistrar,
  ).unenroll();

  await scope.sessionStore.clear();
  await scope.credentialsRepository.signOut();
}

/// Pregunta si de verdad quiere salir y, si es así, cierra la sesión y vuelve a
/// la pantalla de inicio.
///
/// Es la misma pregunta y la misma salida para los cuatro roles: el único
/// cambio es el mensaje, porque lo que pasa al volver a entrar depende de cómo
/// entra cada uno (un código de un solo uso que ya se gastó, o la contraseña de
/// siempre).
///
/// Pregunta antes porque cerrar sesión **da de baja el celular**: quien lo hace
/// por un toque sin querer deja de recibir las alertas hasta volver a entrar, y
/// un estudiante o una madre no pueden volver a entrar sin otro código.
Future<void> confirmAndSignOut(
  BuildContext context, {
  required String message,
}) async {
  final NavigatorState navigator = Navigator.of(context);
  final AppScope scope = AppScope.of(context);

  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          child: const Text('CERRAR SESIÓN'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return;
  }

  // Se da de baja el celular y se borra la sesión antes de salir de la pantalla:
  // si algo falla después, el token ya no está.
  await signOutOfDevice(scope);
  navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (Route<void> _) => false);
}

/// Lo que se le advierte a cada rol al salir.
abstract final class SignOutMessages {
  /// Estudiantes y acudientes: su código ya se usó.
  static const String withCode = 'Para volver a entrar necesitas un código nuevo '
      'de secretaría, porque el tuyo ya se usó.';

  /// Docentes y coordinación: vuelven con lo de siempre.
  static const String withPassword =
      'Volverás a entrar con tu correo y tu contraseña. Mientras tanto este '
      'celular no recibirá alertas.';
}
