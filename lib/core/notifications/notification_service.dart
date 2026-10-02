import 'alert_notification.dart';

/// Cómo llegan los avisos al celular.
///
/// Es una interfaz porque hay dos implementaciones de verdad distintas, no dos
/// variantes de la misma: [PushNotificationService] habla con Firebase y solo
/// existe en Android y iOS, y [SilentNotificationService] no hace nada y es la
/// que usan el panel de Windows y las pruebas. Las pantallas no distinguen.
abstract interface class NotificationService {
  /// Pide permiso, crea los canales y se engancha a Firebase.
  ///
  /// Devuelve si quedó funcionando. Un `false` no es un error que haya que
  /// mostrar: significa que las alertas llegarán solo mientras la app esté
  /// abierta, por el canal SSE, y la app sigue sirviendo.
  Future<bool> start();

  /// Token de este dispositivo en Firebase, o `null` si no hay push.
  ///
  /// Es la dirección del celular, no una credencial de la persona: con él solo
  /// se le puede *mandar* un aviso. Aun así no se registra en los logs.
  Future<String?> deviceToken();

  /// Cuando Firebase renueva el token. Hay que volver a registrarlo en la API.
  Stream<String> get tokenChanges;

  /// Cuando la persona toca un aviso.
  ///
  /// Lo que llega es el aviso, no la alerta: quien escuche esto debe pedirle al
  /// servidor el estado actual. Entre que el aviso salió y que la persona lo
  /// tocó pueden haber pasado diez minutos y la alerta puede haber terminado.
  Stream<AlertNotification> get opened;

  Future<void> dispose();
}
