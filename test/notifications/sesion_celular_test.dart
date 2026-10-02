import 'dart:async';

import 'package:alertic/app/app_scope.dart';
import 'package:alertic/app/sign_out.dart';
import 'package:alertic/core/notifications/alert_notification.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/notification_channels.dart';
import 'package:alertic/core/notifications/notification_service.dart';
import '../support/fakes/fake_alert_repository.dart';
import 'package:alertic/features/onboarding/data/credentials_repository.dart';
import '../support/fakes/fake_enrollment_repository.dart';
import 'package:alertic/features/onboarding/domain/credentials.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:alertic/features/session/domain/session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Qué pasa con el celular cuando alguien cierra sesión, y que los avisos de
/// reportes de emergencia lleguen a su pantalla.
void main() {
  group('un reporte de emergencia llega como aviso', () {
    // Es el aviso que el servidor le manda al director de grupo y a
    // coordinación. Mientras la app no conocía este tipo, lo descartaba en
    // silencio: el reporte llegaba al servidor y nadie sonaba.
    final Map<String, dynamic> data = <String, dynamic>{
      'tipo': 'reporte_emergencia',
      'incidentId': 'abc',
      'titulo': 'Reporte de incendio',
      'primerPaso': 'Laura · 10° B. Abre ALERTIC para verlo.',
      'nivel': 'naranja',
      'tomarPantalla': 'false',
      'privado': 'true',
    };

    test('se entiende y no se descarta', () {
      final AlertNotification? notification = AlertNotification.tryFrom(data);

      expect(notification, isNotNull);
      expect(notification!.kind, PushKind.reporteEmergencia);
      expect(notification.title, 'Reporte de incendio');
    });

    test('lleva el nombre de un menor: no se ve en la pantalla bloqueada', () {
      expect(AlertNotification.tryFrom(data)!.isPrivate, isTrue);
    });

    test('tiene su propio canal, que se puede crear', () {
      final AlertNotification notification = AlertNotification.tryFrom(data)!;

      expect(NotificationChannels.forNotification(notification), NotificationChannels.reports);
      expect(
        NotificationChannels.all.any((c) => c.id == NotificationChannels.reports),
        isTrue,
        reason: 'un canal que no se crea al iniciar no sirve: Android lo ignora',
      );
    });

    test('no toma la pantalla: es un reporte, no una evacuación', () {
      expect(AlertNotification.tryFrom(data)!.takesOverScreen, isFalse);
    });
  });

  group('cerrar sesión da de baja el celular', () {
    late List<String> log;
    late _FakeNotifications notifications;
    late _FakeRegistrar registrar;
    late _FakeCredentials credentials;
    late InMemorySessionStore sessionStore;
    late AppScope scope;

    setUp(() {
      log = <String>[];
      notifications = _FakeNotifications('token-de-este-celular');
      registrar = _FakeRegistrar(log);
      credentials = _FakeCredentials(log);
      sessionStore = InMemorySessionStore();

      scope = AppScope(
        enrollmentRepository: FakeEnrollmentRepository(latency: Duration.zero),
        credentialsRepository: credentials,
        alertRepository: FakeAlertRepository(latency: Duration.zero),
        sessionStore: _LoggingStore(sessionStore, log),
        notifications: notifications,
        deviceRegistrar: registrar,
        child: const SizedBox.shrink(),
      );
    });

    test('el servidor recibe la baja del token de ESTE celular', () async {
      await signOutOfDevice(scope);

      // Sin esto, el teléfono seguiría recibiendo los avisos de quien lo usó
      // antes, incluidos los que llevan el nombre de un menor.
      expect(registrar.unregistered, <String>['token-de-este-celular']);
    });

    test('la baja sale ANTES de soltar la sesión', () async {
      await signOutOfDevice(scope);

      // La baja necesita un token que todavía valga. Si se soltara primero,
      // saldría sin permiso y el celular quedaría registrado a nombre de alguien
      // que ya no lo usa.
      expect(log, <String>[
        'baja del celular',
        'sesión borrada',
        'token del cliente soltado',
      ]);
    });

    test('si no hay notificaciones (sin Firebase), igual cierra la sesión', () async {
      notifications.token = null;

      await signOutOfDevice(scope);

      expect(registrar.unregistered, isEmpty);
      expect(log, contains('sesión borrada'));
      expect(log, contains('token del cliente soltado'));
    });

    test('si la baja falla (sin red), cerrar sesión NO falla', () async {
      registrar.fails = true;

      // No puede quedar atrapada una persona en una cuenta porque se cayó el
      // wifi: la baja es un esfuerzo, la sesión se cierra siempre.
      await signOutOfDevice(scope);

      expect(log, contains('sesión borrada'));
      expect(log, contains('token del cliente soltado'));
    });
  });
}

class _FakeNotifications implements NotificationService {
  _FakeNotifications(this.token);

  String? token;

  @override
  Future<bool> start() async => token != null;

  @override
  Future<String?> deviceToken() async => token;

  @override
  Stream<String> get tokenChanges => const Stream<String>.empty();

  @override
  Stream<AlertNotification> get opened => const Stream<AlertNotification>.empty();

  @override
  Future<void> dispose() async {}
}

class _FakeRegistrar implements DeviceRegistrar {
  _FakeRegistrar(this._log);

  final List<String> _log;
  final List<String> unregistered = <String>[];
  bool fails = false;

  @override
  Future<void> register(String token) async {}

  @override
  Future<void> unregister(String token) async {
    if (fails) {
      throw StateError('sin red');
    }
    _log.add('baja del celular');
    unregistered.add(token);
  }
}

class _FakeCredentials implements CredentialsRepository {
  _FakeCredentials(this._log);

  final List<String> _log;

  @override
  Future<Session> signIn(Credentials credentials) =>
      throw UnimplementedError('no se usa aquí');

  @override
  Future<void> signOut() async => _log.add('token del cliente soltado');

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError('no se usa aquí');
}

/// Registra cuándo se borra la sesión, para comprobar el orden.
class _LoggingStore extends InMemorySessionStore {
  _LoggingStore(this._inner, this._log);

  final InMemorySessionStore _inner;
  final List<String> _log;

  @override
  Future<Session?> read() => _inner.read();

  @override
  Future<void> save(Session session) => _inner.save(session);

  @override
  Future<void> clear() async {
    _log.add('sesión borrada');
    await _inner.clear();
  }
}
