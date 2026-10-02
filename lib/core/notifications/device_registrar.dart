import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../errors/error_reporter.dart';
import '../network/api_client.dart';
import 'notification_service.dart';

/// Registra este celular en el colegio para que le lleguen las notificaciones.
///
/// Es una interfaz por lo mismo que los repositorios: la app del panel y las
/// pruebas no hablan con la API, y no tienen por qué arrastrar un cliente HTTP
/// para no usarlo.
abstract interface class DeviceRegistrar {
  /// Le dice al servidor que este token es de la persona con esta sesión.
  ///
  /// Es idempotente: se puede llamar en cada arranque sin llevar la cuenta de si
  /// ya se hizo. El servidor decide a qué tema suscribirlo según el rol.
  Future<void> register(String token);

  /// Da de baja el celular. Se llama al cerrar sesión.
  ///
  /// Sin esto, el celular de un docente que devolvió el equipo seguiría
  /// recibiendo las alertas del colegio.
  Future<void> unregister(String token);
}

/// Adaptador contra la API del colegio.
class ApiDeviceRegistrar implements DeviceRegistrar {
  const ApiDeviceRegistrar(this._api);

  final ApiClient _api;

  @override
  Future<void> register(String token) async {
    await _api.post(
      '/devices',
      body: <String, dynamic>{'token': token, 'platform': _platform},
    );
  }

  @override
  Future<void> unregister(String token) async {
    await _api.delete('/devices', body: <String, dynamic>{'token': token});
  }

  /// Qué sistema es este celular.
  ///
  /// El servidor lo valida contra `android` o `ios` y rechaza cualquier otro: es
  /// lo que decide si el aviso lleva el bloque de iOS. `Platform` no existe en
  /// web, de ahí la comprobación previa.
  static String get _platform {
    if (kIsWeb) {
      return 'android';
    }
    return Platform.isIOS ? 'ios' : 'android';
  }
}

/// El registrador que no registra nada.
///
/// La usa el panel, que no recibe notificaciones, y la app con datos de prueba.
class NoDeviceRegistrar implements DeviceRegistrar {
  const NoDeviceRegistrar();

  @override
  Future<void> register(String token) async {}

  @override
  Future<void> unregister(String token) async {}
}

/// Une las dos piezas: consigue el token y lo registra.
///
/// Vive aparte del servicio de notificaciones a propósito. Una cosa es hablar
/// con Firebase y otra es hablar con el colegio; juntarlas haría que un fallo de
/// red dejara la app sin notificaciones, o que un fallo de Firebase impidiera
/// abrir sesión.
class DeviceEnrollment {
  DeviceEnrollment({
    required this.notifications,
    required this.registrar,
  });

  final NotificationService notifications;
  final DeviceRegistrar registrar;

  /// Da de baja este celular en el colegio. Se llama al cerrar sesión.
  ///
  /// Hay que hacerlo **antes** de soltar la sesión: la baja necesita un token
  /// que todavía valga. Sin esto, el teléfono seguiría recibiendo los avisos de
  /// quien lo usó antes —un docente que devuelve un equipo, un hermano que
  /// comparte celular—, incluidos los que llevan el nombre de un menor.
  ///
  /// Nunca lanza: cerrar sesión no puede fallar porque Firebase o la red lo hagan.
  Future<void> unenroll() async {
    try {
      final String? token = await notifications.deviceToken();
      if (token != null) {
        await registrar.unregister(token);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'dar de baja el celular');
    }
  }

  /// Arranca las notificaciones y registra el token.
  ///
  /// Nunca lanza: se llama al final del registro, y que Firebase falle no puede
  /// impedirle entrar a un estudiante. Devuelve si quedó todo conectado, para
  /// poder decírselo con honestidad en pantalla.
  Future<bool> enroll() async {
    try {
      final bool ready = await notifications.start();
      if (!ready) {
        return false;
      }

      final String? token = await notifications.deviceToken();
      if (token == null) {
        return false;
      }

      await registrar.register(token);

      // Firebase renueva el token cada tanto, y al reinstalar la app. Si no se
      // vuelve a registrar, el colegio le manda las alertas a una dirección
      // muerta y la persona deja de recibirlas sin enterarse.
      notifications.tokenChanges.listen(
        (String renewed) {
          registrar.register(renewed).catchError((Object error, StackTrace stack) {
            ErrorReporter.report(error, stack, context: 'renovar token');
          });
        },
        onError: (Object error, StackTrace stack) {
          ErrorReporter.report(error, stack, context: 'cambios de token');
        },
      );

      return true;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'registrar notificaciones');
      return false;
    }
  }
}
