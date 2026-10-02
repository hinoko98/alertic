import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/alerts/domain/alert_level.dart';
import 'alert_notification.dart';

/// Los canales de notificación de Android.
///
/// Un canal es la unidad con la que Android decide cuánto interrumpe un aviso, y
/// la persona puede ajustarlo desde los ajustes del sistema. Hay uno por nivel
/// de alerta a propósito: así alguien puede silenciar los avisos amarillos —que
/// son informativos— sin poder silenciar los rojos, que son los que salvan el
/// día.
///
/// **Cuidado al cambiarlos.** Android congela la importancia y el sonido de un
/// canal cuando se crea; volver a crearlo con otros valores no hace nada. Para
/// cambiar de verdad la importancia hay que publicar un canal con otro `id`, o
/// que la persona desinstale la app. Por eso los ids llevan versión.
abstract final class NotificationChannels {
  static const String red = 'alertic_roja_v1';
  static const String orange = 'alertic_naranja_v1';
  static const String yellow = 'alertic_amarilla_v1';
  static const String personal = 'alertic_personal_v1';
  static const String reports = 'alertic_reportes_v1';

  /// El canal que le toca a un aviso.
  static String forNotification(AlertNotification notification) {
    if (notification.kind == PushKind.hijoNecesitaAyuda) {
      return personal;
    }
    if (notification.kind == PushKind.reporteEmergencia) {
      return reports;
    }
    return switch (notification.level) {
      AlertLevel.roja => red,
      AlertLevel.naranja => orange,
      AlertLevel.amarilla => yellow,
      null => yellow,
    };
  }

  static const List<AndroidNotificationChannel> all =
      <AndroidNotificationChannel>[
    /*
     * Alerta roja: hay que salir del edificio.
     *
     * - `Importance.max` es lo que produce el aviso flotante arriba de la
     *   pantalla en vez de una línea en la bandeja.
     * - `bypassDnd` la deja sonar en No molestar. Android solo lo respeta si la
     *   persona le dio a la app acceso a No molestar; si no, se ignora sin
     *   error, y por eso no es lo único en lo que se confía.
     * - `AudioAttributesUsage.alarm` es la parte que de verdad importa: hace
     *   que suene con el volumen de alarma y no con el de notificaciones. Un
     *   celular en silencio tiene las notificaciones calladas pero la alarma
     *   viva, que es justo lo que hace falta a las 9 de la mañana en un salón.
     */
    AndroidNotificationChannel(
      red,
      'Alerta roja · evacuación',
      description: 'Suena al máximo aunque el celular esté en silencio. '
          'No se puede silenciar sin desactivar las alertas de evacuación.',
      importance: Importance.max,
      bypassDnd: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableLights: true,
    ),

    /// Naranja: prepararse. Interrumpe, pero no con volumen de alarma.
    AndroidNotificationChannel(
      orange,
      'Alerta naranja · prepararse',
      description: 'Avisa que hay que alistarse para salir.',
      importance: Importance.high,
    ),

    /// Amarilla: estar atentos. Esta sí se puede silenciar sin riesgo.
    AndroidNotificationChannel(
      yellow,
      'Alerta amarilla · atención',
      description: 'Información del colegio sobre una amenaza cercana.',
      importance: Importance.defaultImportance,
    ),

    /// Reportes de la comunidad, para el docente y coordinación. Importancia alta:
    /// un reporte de incendio no puede esperar a que alguien mire la bandeja.
    AndroidNotificationChannel(
      reports,
      'Reportes de la comunidad',
      description: 'Cuando un estudiante avisa de una emergencia que el colegio '
          'todavía no vio.',
      importance: Importance.high,
    ),

    /// Avisos de una persona concreta: «tu hijo pidió ayuda».
    AndroidNotificationChannel(
      personal,
      'Avisos sobre tus hijos',
      description: 'Cuando un estudiante a tu cargo reporta que necesita ayuda.',
      importance: Importance.high,
    ),
  ];

  /// Crea los canales. Es idempotente: Android ignora los que ya existen.
  static Future<void> ensure(FlutterLocalNotificationsPlugin plugin) async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return;
    }
    for (final AndroidNotificationChannel channel in all) {
      await android.createNotificationChannel(channel);
    }
  }

  /// Cómo se dibuja un aviso concreto.
  static NotificationDetails detailsFor(
    AlertNotification notification, {
    required bool allowFullScreen,
  }) {
    final bool fullScreen = allowFullScreen && notification.takesOverScreen;

    return NotificationDetails(
      android: AndroidNotificationDetails(
        forNotification(notification),
        _channelName(notification),
        channelDescription: _channelDescription(notification),
        importance: notification.level == AlertLevel.roja
            ? Importance.max
            : Importance.high,
        priority: Priority.max,
        /*
         * `fullScreenIntent` es el mecanismo de una llamada entrante: toma la
         * pantalla aunque el celular esté bloqueado. Necesita el permiso
         * `USE_FULL_SCREEN_INTENT`, que Android 14 restringió a las apps de
         * alarma y emergencia; esta califica. Solo se usa en la roja, y solo
         * cuando el servidor lo pidió para este rol.
         */
        fullScreenIntent: fullScreen,
        category: AndroidNotificationCategory.alarm,
        // El nombre de un menor no se muestra en la pantalla bloqueada.
        visibility: notification.isPrivate
            ? NotificationVisibility.private
            : NotificationVisibility.public,
        // El texto completo, para cuando el aviso se despliega.
        styleInformation: BigTextStyleInformation(
          notification.body,
          contentTitle: notification.title,
        ),
        // Se cierra al tocarlo; no se queda pegado en la bandeja.
        autoCancel: true,
        // Sin esto, una alerta que llega dos veces (push y reintento de
        // Firebase) suena dos veces.
        onlyAlertOnce: false,
        ticker: notification.title,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: notification.level == AlertLevel.roja && fullScreen
            ? InterruptionLevel.critical
            : InterruptionLevel.timeSensitive,
      ),
    );
  }

  static String _channelName(AlertNotification notification) {
    final String id = forNotification(notification);
    return all.firstWhere((AndroidNotificationChannel c) => c.id == id).name;
  }

  static String? _channelDescription(AlertNotification notification) {
    final String id = forNotification(notification);
    return all
        .firstWhere((AndroidNotificationChannel c) => c.id == id)
        .description;
  }
}
