import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../errors/error_reporter.dart';
import 'alert_notification.dart';
import 'notification_channels.dart';
import 'notification_service.dart';

/// Icono del aviso. Es el del lanzador mientras no haya uno monocromo propio.
const String _notificationIcon = '@mipmap/ic_launcher';

/// Las notificaciones reales, con Firebase Cloud Messaging.
///
/// ## Por qué el servidor manda solo datos y no un aviso ya armado
///
/// Firebase puede mandar un bloque `notification` que el sistema dibuja solo, sin
/// que la app se despierte. Es más simple y aquí no se usa, por una razón: ese
/// camino no permite pedir `fullScreenIntent`, que es lo que hace que la alerta
/// roja tome la pantalla de un celular bloqueado. Tampoco permitiría que el mismo
/// mensaje se comporte distinto según el rol.
///
/// El precio es que la app tiene que despertar para dibujar el aviso. Android
/// exime de la espera a los mensajes de prioridad alta, así que llega igual con
/// el celular en reposo. Lo que sí queda fuera del alcance de cualquier sistema
/// de push: si la persona forzó el cierre de la app, Firebase deja de entregarle
/// nada, con datos o sin ellos.
class PushNotificationService implements NotificationService {
  PushNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _local = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _local;

  final StreamController<String> _tokenChanges =
      StreamController<String>.broadcast();
  final StreamController<AlertNotification> _opened =
      StreamController<AlertNotification>.broadcast();

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  FirebaseMessaging? _messaging;
  bool _started = false;

  @override
  Stream<String> get tokenChanges => _tokenChanges.stream;

  @override
  Stream<AlertNotification> get opened => _opened.stream;

  @override
  Future<bool> start() async {
    if (_started) {
      return _messaging != null;
    }
    _started = true;

    try {
      await Firebase.initializeApp();
    } catch (error, stack) {
      /*
       * Aquí se cae cuando falta `android/app/google-services.json`, que es el
       * estado del proyecto mientras el colegio no tenga cuenta de Firebase.
       *
       * No se relanza a propósito: la app arranca igual y las alertas siguen
       * llegando por SSE mientras esté abierta. Un registro de notificaciones
       * sin configurar no puede impedir que un estudiante vea la alerta.
       */
      ErrorReporter.report(error, stack, context: 'firebase no configurado');
      return false;
    }

    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      _messaging = messaging;

      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_notificationIcon),
          iOS: DarwinInitializationSettings(
            // Los permisos se piden con Firebase, no dos veces.
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onTap,
      );
      await NotificationChannels.ensure(_local);

      // Android 13 y siguientes exigen permiso explícito de notificaciones.
      // Antes de esa versión se concede al instalar y esto devuelve `authorized`.
      final NotificationSettings permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        // Las alertas críticas de iOS necesitan una autorización aparte de
        // Apple, que se pide por formulario. Se solicita; si no está concedida,
        // iOS la ignora y el aviso suena como uno normal.
        criticalAlert: true,
      );

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        // Se sigue adelante igual: el token se registra y el día que la persona
        // active las notificaciones en los ajustes, empiezan a llegar sin tener
        // que volver a registrarse.
        ErrorReporter.trace('notificaciones denegadas por la persona');
      }

      // El aislado de fondo. Tiene que ser una función de primer nivel: cuando
      // se ejecuta, esta instancia no existe.
      FirebaseMessaging.onBackgroundMessage(alerticBackgroundHandler);

      _subscriptions.addAll(<StreamSubscription<Object?>>[
        // Con la app abierta. No se pide pantalla completa: la app ya está
        // delante y `AlertGate` la cubre.
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _show(message, allowFullScreen: false);
        }),
        // Solo ocurre en iOS, donde el servidor sí manda texto visible.
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final AlertNotification? notification =
              AlertNotification.tryFrom(message.data);
          if (notification != null) {
            _opened.add(notification);
          }
        }),
        messaging.onTokenRefresh.listen(_tokenChanges.add),
      ]);

      await _emitLaunchNotification(messaging);
      return true;
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'iniciar notificaciones');
      return false;
    }
  }

  @override
  Future<String?> deviceToken() async {
    final FirebaseMessaging? messaging = _messaging;
    if (messaging == null) {
      return null;
    }
    try {
      return await messaging.getToken();
    } catch (error, stack) {
      // Pasa en un emulador sin Google Play Services, que es lo que hay en la
      // imagen por defecto de algunos AVD.
      ErrorReporter.report(error, stack, context: 'token de dispositivo');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _tokenChanges.close();
    await _opened.close();
  }

  Future<void> _show(RemoteMessage message, {required bool allowFullScreen}) {
    return showAlertNotification(
      _local,
      message.data,
      allowFullScreen: allowFullScreen,
    );
  }

  /// La app se abrió porque alguien tocó un aviso.
  ///
  /// Hay dos caminos según de dónde vino, y los dos hay que mirarlos: el aviso
  /// que dibujó la app (Android, mensajes solo-datos) y el que dibujó el sistema
  /// (iOS). Si solo se mirara el segundo, en Android abrir desde el aviso no
  /// llevaría a la alerta.
  Future<void> _emitLaunchNotification(FirebaseMessaging messaging) async {
    final NotificationAppLaunchDetails? launch =
        await _local.getNotificationAppLaunchDetails();

    if (launch != null && launch.didNotificationLaunchApp) {
      final String? payload = launch.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        _opened.add(_fromPayload(payload));
      }
    }

    final RemoteMessage? initial = await messaging.getInitialMessage();
    if (initial != null) {
      final AlertNotification? notification =
          AlertNotification.tryFrom(initial.data);
      if (notification != null) {
        _opened.add(notification);
      }
    }
  }

  void _onTap(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    _opened.add(_fromPayload(payload));
  }

  /// Reconstruye lo mínimo a partir del identificador guardado en el aviso.
  ///
  /// En la bandeja de notificaciones solo se guarda el id de la alerta, nunca el
  /// texto ni el nombre de nadie: esa bandeja sobrevive al cierre de la app y no
  /// es sitio para datos de un menor. Quien escuche `opened` pide el estado al
  /// servidor con ese id.
  AlertNotification _fromPayload(String alertId) {
    return AlertNotification.tryFrom(<String, dynamic>{
          'tipo': PushKind.alertaNueva.wire,
          'alertId': alertId,
          'titulo': 'Alerta del colegio',
        }) ??
        // No puede pasar: ese mapa siempre valida. Se deja explícito para no
        // devolver un nulo que obligue a todos los oyentes a comprobarlo.
        _unreachable();
  }

  static Never _unreachable() =>
      throw StateError('no se pudo armar la notificación desde el identificador');
}

/// Dibuja el aviso a partir de la carga cruda del push.
///
/// Está fuera de la clase porque la usan dos mundos: la instancia normal y el
/// aislado de fondo, que no tiene acceso a nada de la app.
Future<void> showAlertNotification(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> data, {
  required bool allowFullScreen,
}) async {
  final AlertNotification? notification = AlertNotification.tryFrom(data);
  if (notification == null) {
    return;
  }

  await plugin.show(
    // Un id fijo por alerta hace que un reintento de Firebase reemplace el aviso
    // en vez de apilar tres iguales. El aviso personal va en otro id para que no
    // borre el de la alerta.
    id: notification.kind == PushKind.hijoNecesitaAyuda ? 2 : 1,
    title: notification.title,
    body: notification.body,
    notificationDetails: NotificationChannels.detailsFor(
      notification,
      allowFullScreen: allowFullScreen,
    ),
    payload: notification.tapPayload,
  );
}

/// Lo que corre cuando llega un push y la app está cerrada o en segundo plano.
///
/// Es un **aislado aparte**: no hay pantalla, no hay `AppScope`, no hay sesión y
/// no sirve nada que se haya guardado en memoria. Solo puede hacer dos cosas:
/// arrancar Firebase y dibujar el aviso. Todo lo demás espera a que la persona
/// abra la app.
///
/// `@pragma('vm:entry-point')` es obligatorio: sin él, la compilación en modo
/// release descarta esta función por parecer código muerto, y las alertas dejan
/// de llegar exactamente en la versión que se instala en los celulares.
@pragma('vm:entry-point')
Future<void> alerticBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();

    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_notificationIcon),
      ),
    );
    await NotificationChannels.ensure(plugin);

    // Aquí sí se permite tomar la pantalla: la app no está delante, y si el
    // servidor lo pidió para este rol es porque hay que evacuar.
    await showAlertNotification(plugin, message.data, allowFullScreen: true);
  } catch (error, stack) {
    // En este aislado no hay a quién reportarle: no hay pantalla ni sesión. Se
    // deja en el log del sistema, que es lo que se puede leer con `adb logcat`.
    ErrorReporter.report(error, stack, context: 'notificación en segundo plano');
  }
}
