import 'package:flutter/widgets.dart';

import '../core/location/location_service.dart';

import '../core/network/server_status.dart';
import '../core/notifications/device_registrar.dart';
import '../core/notifications/notification_service.dart';
import '../features/account/domain/account_repository.dart';
import '../features/alerts/domain/alert_repository.dart';
import '../features/drills/domain/drill_repository.dart';
import '../features/risks/domain/risk_repository.dart';
import '../features/alerts/domain/live_updates.dart';
import '../features/guardian/domain/guardian_repository.dart';
import '../features/incidents/domain/incident.dart';
import '../features/onboarding/data/credentials_repository.dart';
import '../features/onboarding/data/enrollment_repository.dart';
import '../features/panel/domain/panel_repository.dart';
import '../features/support/domain/support_repository.dart';
import '../features/teacher/domain/teacher_repository.dart';
import '../features/session/domain/session_store.dart';

/// Deja las dependencias de la app disponibles para las pantallas.
///
/// Es un [InheritedWidget] a propósito: alcanza para lo que la app necesita hoy
/// y permite inyectar dobles de prueba sin traer un paquete de inyección de
/// dependencias.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.enrollmentRepository,
    required this.credentialsRepository,
    required this.alertRepository,
    required this.sessionStore,
    required this.notifications,
    required this.deviceRegistrar,
    required super.child,
    this.liveUpdates = const NoLiveUpdates(),
    this.serverStatus = const DemoServerStatus(),
    this.incidentRepository,
    this.teacherRepository,
    this.guardianRepository,
    this.panelRepository,
    this.supportRepository,
    this.accountRepository,
    this.drillRepository,
    this.riskRepository,
    this.locationService = const NoLocationService(),
    super.key,
  });

  /// La matrícula: quién es el dueño de un código. La usan estudiantes y
  /// acudientes.
  final EnrollmentRepository enrollmentRepository;

  /// La otra puerta: correo y contraseña. La usan docentes y administradores.
  final CredentialsRepository credentialsRepository;

  final AlertRepository alertRepository;
  final SessionStore sessionStore;

  /// Cómo llegan los avisos cuando la app está cerrada. En el panel y en las
  /// pruebas es la implementación silenciosa.
  final NotificationService notifications;

  /// Quién le dice al colegio que este celular existe.
  final DeviceRegistrar deviceRegistrar;

  /// Avisos de que algo cambió mientras la pantalla estaba abierta: un reporte
  /// nuevo, un hijo que confirmó. Con datos de prueba no emite nada.
  final LiveUpdates liveUpdates;

  /// Con quién habla la app. Por omisión, con nadie: datos de prueba.
  final ServerStatus serverStatus;

  /// Reportes de emergencia: los hace un estudiante o un docente, y los atienden
  /// docentes y coordinación.
  final IncidentRepository? incidentRepository;

  /// Solo lo usa la app del docente. Es nulo en los demás roles: una pantalla
  /// de estudiante no debería ni poder nombrar «emitir alerta».
  final TeacherRepository? teacherRepository;

  /// Solo lo usa la app del acudiente.
  final GuardianRepository? guardianRepository;

  /// Solo lo usa el panel del colegio, que es otra app con otro punto de
  /// entrada. En la app móvil es nulo.
  final PanelRepository? panelRepository;

  /// El chat con el soporte del colegio. Lo usan los cuatro roles, cada uno por
  /// su lado.
  final SupportRepository? supportRepository;

  /// Ajustes, contactos de familia e historial de avisos de cada persona.
  final AccountRepository? accountRepository;

  /// Simulacros programados y sus resultados.
  final DrillRepository? drillRepository;

  /// Reportes de riesgo: una grieta, un cable suelto.
  final RiskRepository? riskRepository;

  /// La ubicación del celular, para el mapa y la ruta en vivo. Por omisión no hay.
  final LocationService locationService;

  static AppScope of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No hay un AppScope arriba en el árbol de widgets.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.enrollmentRepository != enrollmentRepository ||
      oldWidget.credentialsRepository != credentialsRepository ||
      oldWidget.alertRepository != alertRepository ||
      oldWidget.sessionStore != sessionStore ||
      oldWidget.notifications != notifications ||
      oldWidget.deviceRegistrar != deviceRegistrar ||
      oldWidget.liveUpdates != liveUpdates ||
      oldWidget.serverStatus != serverStatus ||
      oldWidget.incidentRepository != incidentRepository ||
      oldWidget.teacherRepository != teacherRepository ||
      oldWidget.guardianRepository != guardianRepository ||
      oldWidget.panelRepository != panelRepository ||
      oldWidget.supportRepository != supportRepository ||
      oldWidget.accountRepository != accountRepository ||
      oldWidget.drillRepository != drillRepository ||
      oldWidget.riskRepository != riskRepository ||
      oldWidget.locationService != locationService;
}
