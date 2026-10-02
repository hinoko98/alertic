import 'package:alertic/app/alertic_app.dart';
import 'package:alertic/core/network/server_status.dart';
import 'package:alertic/core/notifications/device_registrar.dart';
import 'package:alertic/core/notifications/notification_service.dart';
import 'package:alertic/core/notifications/silent_notification_service.dart';
import 'package:alertic/features/alerts/domain/alert_repository.dart';
import 'package:alertic/features/alerts/domain/live_updates.dart';
import 'package:alertic/features/guardian/domain/guardian_repository.dart';
import 'package:alertic/features/incidents/domain/incident.dart';
import 'package:alertic/features/onboarding/data/credentials_repository.dart';
import 'package:alertic/features/onboarding/data/enrollment_repository.dart';
import 'package:alertic/features/panel/domain/panel_repository.dart';
import 'package:alertic/features/session/data/in_memory_session_store.dart';
import 'package:alertic/features/session/domain/session_store.dart';
import 'package:alertic/features/teacher/domain/teacher_repository.dart';
import 'package:flutter/widgets.dart';

import 'fakes/fake_alert_repository.dart';
import 'fakes/fake_credentials_repository.dart';
import 'fakes/fake_enrollment_repository.dart';
import 'fakes/fake_guardian_repository.dart';
import 'fakes/fake_incident_repository.dart';
import 'fakes/fake_panel_repository.dart';
import 'fakes/fake_teacher_repository.dart';

/// La app con dobles en memoria, **solo para pruebas**.
///
/// La app de verdad no tiene datos inventados: se arma con
/// `AlerticApp.production()` y habla con el servidor. Las pruebas, en cambio,
/// necesitan una matrícula conocida y sin red, y esa vive aquí, en `test/`,
/// fuera de lo que se compila en la app.
///
/// Lo que no se pase, se completa con el doble que corresponde, y los dobles que
/// se comunican entre sí (alertas, reportes, panel) comparten la misma instancia.
AlerticApp testApp({
  EnrollmentRepository? enrollmentRepository,
  CredentialsRepository? credentialsRepository,
  AlertRepository? alertRepository,
  SessionStore? sessionStore,
  TeacherRepository? teacherRepository,
  GuardianRepository? guardianRepository,
  PanelRepository? panelRepository,
  IncidentRepository? incidentRepository,
  LiveUpdates? liveUpdates,
  NotificationService? notifications,
  DeviceRegistrar? deviceRegistrar,
  Key? key,
}) {
  final FakeAlertRepository? fakeAlerts =
      alertRepository == null ? FakeAlertRepository() : null;
  final FakeIncidentRepository? fakeIncidents =
      incidentRepository == null ? FakeIncidentRepository() : null;

  return AlerticApp(
    key: key,
    enrollmentRepository: enrollmentRepository ?? FakeEnrollmentRepository(),
    credentialsRepository: credentialsRepository ?? FakeCredentialsRepository(),
    alertRepository: alertRepository ?? fakeAlerts!,
    sessionStore: sessionStore ?? InMemorySessionStore(),
    teacherRepository: teacherRepository ??
        (fakeAlerts == null ? null : FakeTeacherRepository(fakeAlerts)),
    guardianRepository: guardianRepository ?? FakeGuardianRepository(),
    panelRepository: panelRepository ??
        (fakeAlerts == null ? null : FakePanelRepository(fakeAlerts)),
    incidentRepository: incidentRepository ?? fakeIncidents,
    liveUpdates: liveUpdates ?? fakeIncidents ?? const NoLiveUpdates(),
    serverStatus: const DemoServerStatus(),
    notifications: notifications ?? SilentNotificationService(),
    deviceRegistrar: deviceRegistrar ?? const NoDeviceRegistrar(),
  );
}
