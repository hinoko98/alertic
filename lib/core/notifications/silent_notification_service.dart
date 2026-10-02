import 'dart:async';

import 'alert_notification.dart';
import 'notification_service.dart';

/// El servicio que no notifica nada.
///
/// La usan tres sitios, por tres razones distintas:
///
/// - El **panel del colegio**, que corre en Windows: no recibe push, es el que
///   las origina. Su aviso lo da el tablero en pantalla.
/// - Las **pruebas**, que no pueden inicializar Firebase.
/// - La app **sin servidor configurado**, cuando corre con los datos de prueba.
///
/// No es un doble de prueba: es una implementación legítima del caso «esta
/// plataforma no tiene notificaciones». Por eso vive en `lib/` y no en `test/`.
class SilentNotificationService implements NotificationService {
  @override
  Future<bool> start() async => false;

  @override
  Future<String?> deviceToken() async => null;

  @override
  Stream<String> get tokenChanges => const Stream<String>.empty();

  @override
  Stream<AlertNotification> get opened => const Stream<AlertNotification>.empty();

  @override
  Future<void> dispose() async {}
}
