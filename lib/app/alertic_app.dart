import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/constants/app_strings.dart';
import '../core/errors/error_reporter.dart';
import '../core/network/api_client.dart';
import '../core/network/server_status.dart';
import '../core/notifications/device_registrar.dart';
import '../core/notifications/notification_service.dart';
import '../core/notifications/push_notification_service.dart';
import '../core/notifications/silent_notification_service.dart';
import '../core/theme/app_theme.dart';
import '../features/alerts/data/api_alert_repository.dart';
import '../features/alerts/data/api_event_hub.dart';
import '../features/alerts/data/logging_alert_repository.dart';
import '../features/alerts/domain/alert_repository.dart';
import '../features/alerts/domain/live_updates.dart';
import '../features/guardian/data/api_guardian_repository.dart';
import '../features/guardian/domain/guardian_repository.dart';
import '../features/incidents/data/api_incident_repository.dart';
import '../features/incidents/domain/incident.dart';
import '../features/onboarding/data/api_credentials_repository.dart';
import '../features/onboarding/data/api_enrollment_repository.dart';
import '../features/onboarding/data/credentials_repository.dart';
import '../features/onboarding/data/enrollment_repository.dart';
import '../features/panel/data/api_panel_repository.dart';
import '../features/panel/domain/panel_repository.dart';
import '../features/session/data/in_memory_session_store.dart';
import '../features/session/domain/session_store.dart';
import '../features/teacher/data/api_teacher_repository.dart';
import '../features/teacher/domain/teacher_repository.dart';
import 'app_routes.dart';
import 'app_scope.dart';

/// La app del celular.
///
/// El constructor recibe todas sus dependencias, y por eso las pruebas pueden
/// darle las que quieran. La app de verdad se arma con [AlerticApp.production],
/// que solo sabe hablar con el servidor del colegio: no existe una versión con
/// datos inventados.
class AlerticApp extends StatelessWidget {
  const AlerticApp({
    required this.enrollmentRepository,
    required this.credentialsRepository,
    required this.alertRepository,
    required this.sessionStore,
    required this.liveUpdates,
    required this.serverStatus,
    required this.notifications,
    required this.deviceRegistrar,
    this.teacherRepository,
    this.guardianRepository,
    this.panelRepository,
    this.incidentRepository,
    super.key,
  });

  /// La app contra el servidor configurado en [AppConfig].
  factory AlerticApp.production({Key? key}) {
    if (AppConfig.isInsecureTransport) {
      // Un token de sesión viajando en claro por internet se puede leer desde
      // cualquier punto del camino.
      ErrorReporter.report(
        StateError('La API está configurada sin HTTPS: ${AppConfig.apiBaseUrl}'),
        StackTrace.current,
        context: 'configuración',
      );
    }

    final ApiClient api = ApiClient(baseUrl: AppConfig.apiBaseUrl);

    // Una sola conexión en vivo para toda la app: la alerta activa, el tablero,
    // la lista del grupo y los hijos escuchan el mismo canal.
    final ApiEventHub hub = ApiEventHub(api);
    final ApiAlertRepository alerts = ApiAlertRepository(api, hub: hub);

    return AlerticApp(
      key: key,
      enrollmentRepository: ApiEnrollmentRepository(api),
      credentialsRepository: ApiCredentialsRepository(api),
      alertRepository: alerts,
      sessionStore: InMemorySessionStore(),
      teacherRepository: ApiTeacherRepository(api),
      guardianRepository: ApiGuardianRepository(api),
      incidentRepository: ApiIncidentRepository(api),
      liveUpdates: ApiLiveUpdates(hub),
      serverStatus: ApiServerStatus(api),
      // El panel del administrador comparte el repositorio de alertas para no
      // mapear el mismo JSON dos veces.
      panelRepository: ApiPanelRepository(api, alerts),
      // Las notificaciones solo existen donde hay Firebase. En Windows y en web
      // la app funciona igual, con la alerta llegando por el canal SSE mientras
      // esté abierta.
      notifications: _supportsPush
          ? PushNotificationService()
          : SilentNotificationService(),
      deviceRegistrar: ApiDeviceRegistrar(api),
    );
  }

  final EnrollmentRepository enrollmentRepository;
  final CredentialsRepository credentialsRepository;
  final AlertRepository alertRepository;
  final SessionStore sessionStore;
  final TeacherRepository? teacherRepository;
  final GuardianRepository? guardianRepository;

  /// Solo lo usa el administrador, que lleva el panel del colegio en el
  /// celular. Es nulo para los demás roles.
  final PanelRepository? panelRepository;

  /// Reportes de emergencia de la comunidad.
  final IncidentRepository? incidentRepository;

  /// Cambios en vivo del servidor.
  final LiveUpdates liveUpdates;

  /// Con quién habla la app y si responde.
  final ServerStatus serverStatus;

  final NotificationService notifications;
  final DeviceRegistrar deviceRegistrar;

  /// ¿Esta plataforma puede recibir notificaciones push?
  ///
  /// Se mira con `defaultTargetPlatform` y no con `Platform.isAndroid`: esto
  /// también se compila para web, donde `dart:io` no existe.
  static bool get _supportsPush =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    return AppScope(
      enrollmentRepository: enrollmentRepository,
      credentialsRepository: credentialsRepository,
      // El decorador de registro envuelve al repositorio real: las pantallas
      // siguen viendo un AlertRepository cualquiera.
      alertRepository: LoggingAlertRepository(alertRepository),
      sessionStore: sessionStore,
      teacherRepository: teacherRepository,
      guardianRepository: guardianRepository,
      panelRepository: panelRepository,
      incidentRepository: incidentRepository,
      liveUpdates: liveUpdates,
      serverStatus: serverStatus,
      notifications: notifications,
      deviceRegistrar: deviceRegistrar,
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        initialRoute: AppRoutes.welcome,
        onGenerateRoute: AppRoutes.onGenerateRoute,
        onUnknownRoute: AppRoutes.onUnknownRoute,
      ),
    );
  }
}
