import 'package:alertic/core/notifications/alert_notification.dart';
import 'package:alertic/core/notifications/notification_channels.dart';
import 'package:alertic/features/alerts/domain/alert_level.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// La carga de un push llega por la red y se interpreta en un aislado sin
/// pantalla, donde un error no se puede mostrar ni reportar. Estas pruebas
/// existen para eso: comprobar que nada de lo que llegue mal revienta la app ni
/// se cuela hasta la bandeja de notificaciones.
void main() {
  /// Una alerta roja como la manda el servidor a un estudiante.
  Map<String, dynamic> redAlert({
    String tomarPantalla = 'true',
    String? titulo,
  }) =>
      <String, dynamic>{
        'tipo': 'alerta_nueva',
        'alertId': 'a1b2c3',
        'nivel': 'roja',
        'amenaza': 'sismo',
        'titulo': titulo ?? 'SISMO',
        'alcance': 'Todo el instituto',
        'puntoEncuentro': 'C',
        'primerPaso': 'Sal en fila, sin correr',
        'tomarPantalla': tomarPantalla,
      };

  group('lo que llega bien', () {
    test('una alerta roja se interpreta completa', () {
      final AlertNotification? notification =
          AlertNotification.tryFrom(redAlert());

      expect(notification, isNotNull);
      expect(notification!.kind, PushKind.alertaNueva);
      expect(notification.level, AlertLevel.roja);
      expect(notification.title, 'SISMO');
      expect(notification.body, 'Sal en fila, sin correr');
      expect(notification.takesOverScreen, isTrue);
      expect(notification.alertId, 'a1b2c3');
    });

    test('sin primer paso, el cuerpo dice a dónde ir', () {
      final Map<String, dynamic> data = redAlert()..['primerPaso'] = '';
      expect(AlertNotification.tryFrom(data)!.body, 'Punto de encuentro C');
    });

    test('sin paso ni punto, el cuerpo dice a quién cobija', () {
      final Map<String, dynamic> data = redAlert()
        ..['primerPaso'] = ''
        ..['puntoEncuentro'] = '';
      expect(AlertNotification.tryFrom(data)!.body, 'Todo el instituto');
    });
  });

  group('lo que el servidor decide y la app obedece', () {
    test('al acudiente no se le toma la pantalla', () {
      // El servidor manda `tomarPantalla: false` al tema de acudientes. Es la
      // misma decisión que toma AlertGate: las instrucciones de evacuación son
      // para quien está dentro del edificio.
      final AlertNotification notification =
          AlertNotification.tryFrom(redAlert(tomarPantalla: 'false'))!;

      expect(notification.takesOverScreen, isFalse);

      final NotificationDetailsProbe probe = NotificationDetailsProbe(
        NotificationChannels.detailsFor(notification, allowFullScreen: true),
      );
      expect(
        probe.fullScreenIntent,
        isFalse,
        reason: 'aunque la app lo permita, si el servidor dijo que no, es no',
      );
    });

    test('con la app abierta tampoco, aunque sea roja', () {
      // La app ya está delante: AlertGate cubre la pantalla. Volver a taparla
      // con el aviso del sistema solo estorbaría.
      final NotificationDetailsProbe probe = NotificationDetailsProbe(
        NotificationChannels.detailsFor(
          AlertNotification.tryFrom(redAlert())!,
          allowFullScreen: false,
        ),
      );
      expect(probe.fullScreenIntent, isFalse);
    });

    test('roja en segundo plano sí toma la pantalla', () {
      final NotificationDetailsProbe probe = NotificationDetailsProbe(
        NotificationChannels.detailsFor(
          AlertNotification.tryFrom(redAlert())!,
          allowFullScreen: true,
        ),
      );
      expect(probe.fullScreenIntent, isTrue);
      expect(probe.channelId, NotificationChannels.red);
    });

    test('cada nivel va por su canal', () {
      String channelFor(String level) {
        final Map<String, dynamic> data = redAlert()..['nivel'] = level;
        return NotificationChannels.forNotification(
          AlertNotification.tryFrom(data)!,
        );
      }

      expect(channelFor('roja'), NotificationChannels.red);
      expect(channelFor('naranja'), NotificationChannels.orange);
      expect(channelFor('amarilla'), NotificationChannels.yellow);
    });
  });

  group('lo que llega mal no revienta nada', () {
    test('un tipo desconocido se ignora', () {
      final Map<String, dynamic> data = redAlert()..['tipo'] = 'algo_nuevo';
      expect(AlertNotification.tryFrom(data), isNull);
    });

    test('sin título no se muestra: un aviso vacío no le dice nada a nadie', () {
      final Map<String, dynamic> data = redAlert()..['titulo'] = '   ';
      expect(AlertNotification.tryFrom(data), isNull);
    });

    test('un mapa vacío no lanza', () {
      expect(AlertNotification.tryFrom(<String, dynamic>{}), isNull);
    });

    test('valores que no son texto no lanzan', () {
      expect(
        AlertNotification.tryFrom(<String, dynamic>{
          'tipo': 42,
          'titulo': <String>['no', 'soy', 'texto'],
          'nivel': <String, String>{},
        }),
        isNull,
      );
    });

    test('un nivel inventado no impide mostrar el aviso', () {
      // Al contrario que una alerta en pantalla, que se rechaza entera: aquí
      // vale más un aviso por el canal más suave que ningún aviso.
      final Map<String, dynamic> data = redAlert()..['nivel'] = 'morada';
      final AlertNotification? notification = AlertNotification.tryFrom(data);

      expect(notification, isNotNull);
      expect(notification!.level, isNull);
      expect(
        NotificationChannels.forNotification(notification),
        NotificationChannels.yellow,
      );
    });

    test('un título larguísimo se recorta, no se descarta', () {
      final AlertNotification notification =
          AlertNotification.tryFrom(redAlert(titulo: 'SISMO ' * 100))!;
      expect(notification.title.length, AlertNotification.maxTitleLength);
    });

    test('los caracteres de control se limpian', () {
      // Un salto de línea o un retorno de carro metidos en el título rompen cómo
      // Android dibuja el aviso.
      final AlertNotification notification =
          AlertNotification.tryFrom(redAlert(titulo: 'SIS\nMO\u0000 YA'))!;
      expect(notification.title, 'SIS MO  YA');
    });
  });

  group('no se filtra nada sensible', () {
    test('en la bandeja del sistema solo queda el identificador', () {
      // La bandeja de notificaciones sobrevive al cierre de la app y la puede
      // leer cualquiera que tenga el teléfono en la mano.
      final AlertNotification notification = AlertNotification.tryFrom(
        <String, dynamic>{
          'tipo': 'hijo_necesita_ayuda',
          'alertId': 'a1b2c3',
          'titulo': 'Laura pidió ayuda',
          'privado': 'true',
        },
      )!;

      expect(notification.tapPayload, 'a1b2c3');
      expect(notification.tapPayload, isNot(contains('Laura')));
      expect(notification.isPrivate, isTrue);
    });

    test('el aviso de un menor no se ve en la pantalla bloqueada', () {
      final NotificationDetailsProbe probe = NotificationDetailsProbe(
        NotificationChannels.detailsFor(
          AlertNotification.tryFrom(<String, dynamic>{
            'tipo': 'hijo_necesita_ayuda',
            'titulo': 'Laura pidió ayuda',
            'privado': 'true',
          })!,
          allowFullScreen: true,
        ),
      );
      expect(probe.visibility, 'private');
      expect(probe.channelId, NotificationChannels.personal);
    });

    test('toString no imprime el cuerpo del aviso', () {
      final AlertNotification notification = AlertNotification.tryFrom(
        <String, dynamic>{
          'tipo': 'hijo_necesita_ayuda',
          'titulo': 'Laura pidió ayuda',
          'primerPaso': 'Coordinación ya fue avisada',
        },
      )!;

      expect(notification.toString(), isNot(contains('Laura')));
      expect(notification.toString(), isNot(contains('Coordinación')));
    });
  });
}

/// Lee de un [NotificationDetails] lo que hace falta comprobar.
///
/// Existe porque los campos de Android viven en un objeto anidado y repetir el
/// camino en cada `expect` hace las pruebas ilegibles.
class NotificationDetailsProbe {
  NotificationDetailsProbe(NotificationDetails details)
      : _android = details.android!;

  final AndroidNotificationDetails _android;

  bool get fullScreenIntent => _android.fullScreenIntent;

  String get channelId => _android.channelId;

  String get visibility => _android.visibility?.name ?? 'sin definir';
}
