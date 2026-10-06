import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app_scope.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/errors/app_error_screen.dart';
import 'core/errors/error_reporter.dart';
import 'core/network/api_client.dart';
import 'core/network/server_status.dart';
import 'core/notifications/device_registrar.dart';
import 'core/notifications/silent_notification_service.dart';
import 'core/session/user_role.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/app_theme.dart';
import 'features/alerts/data/api_event_hub.dart';
import 'features/alerts/data/api_alert_repository.dart';
import 'features/alerts/data/logging_alert_repository.dart';
import 'features/guardian/data/api_guardian_repository.dart';
import 'features/incidents/data/api_incident_repository.dart';
import 'features/onboarding/data/api_credentials_repository.dart';
import 'features/onboarding/data/api_enrollment_repository.dart';
import 'features/onboarding/presentation/screens/sign_in_screen.dart';
import 'features/panel/data/api_panel_repository.dart';
import 'features/panel/presentation/panel_shell.dart';
import 'features/session/data/in_memory_session_store.dart';
import 'features/session/domain/session.dart';
import 'features/teacher/data/api_teacher_repository.dart';

/// Punto de entrada del panel del colegio (bloque F).
///
///   flutter run -d windows -t lib/panel_main.dart
///
/// Sin `--dart-define=ALERTIC_API=...` usa `http://localhost:3001`.
///
/// Es otra app, no otra pantalla de la app móvil: corre en el computador de
/// coordinación y responde otra pregunta. Comparte el mismo proyecto para no
/// duplicar el dominio, el tema ni los repositorios.
///
/// Pide iniciar sesión y solo deja pasar a coordinación: el panel puede evacuar
/// el colegio y ver los datos de toda la comunidad, así que no abre sin una
/// cuenta. Siempre habla con el servidor: si no responde, la pantalla de inicio
/// de sesión lo dice.
void main() {
  ErrorReporter.runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorReporter.install();
    ErrorWidget.builder = (FlutterErrorDetails details) =>
        AppErrorScreen(details: details);

    runApp(const PanelApp());
  });
}

class PanelApp extends StatefulWidget {
  const PanelApp({super.key});

  @override
  State<PanelApp> createState() => _PanelAppState();
}

class _PanelAppState extends State<PanelApp> {
  late final ApiClient _api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  late final ApiEventHub _hub = ApiEventHub(_api);
  late final ApiAlertRepository _alerts = ApiAlertRepository(_api, hub: _hub);

  @override
  Widget build(BuildContext context) {
    return AppScope(
      enrollmentRepository: ApiEnrollmentRepository(_api),
      credentialsRepository: ApiCredentialsRepository(_api),
      alertRepository: LoggingAlertRepository(_alerts),
      sessionStore: InMemorySessionStore(),
      // El panel no recibe notificaciones: es el que las origina. Su aviso es el
      // tablero, que está delante de quien lo tiene abierto.
      notifications: SilentNotificationService(),
      deviceRegistrar: const NoDeviceRegistrar(),
      guardianRepository: ApiGuardianRepository(_api),
      panelRepository: ApiPanelRepository(_api, _alerts),
      // Emitir y finalizar alertas es de docentes y de coordinación: el mismo
      // repositorio y las mismas rutas, el servidor decide quién puede.
      teacherRepository: ApiTeacherRepository(_api),
      incidentRepository: ApiIncidentRepository(_api),
      liveUpdates: ApiLiveUpdates(_hub),
      serverStatus: ApiServerStatus(_api),
      child: MaterialApp(
        title: '${AppStrings.appName} · Panel del colegio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: _PanelGate(api: _api),
      ),
    );
  }
}

/// La puerta del panel: sin sesión de coordinación no se ve nada.
class _PanelGate extends StatefulWidget {
  const _PanelGate({required this.api});

  /// Cliente del servidor, para soltar el token al salir.
  final ApiClient api;

  @override
  State<_PanelGate> createState() => _PanelGateState();
}

class _PanelGateState extends State<_PanelGate> {
  Session? _session;

  void _signOut() {
    // El token se suelta del cliente: sin esto, la siguiente persona que se
    // sentara en este computador seguiría teniendo una sesión abierta.
    widget.api.useToken(null);
    unawaited(AppScope.of(context).sessionStore.clear());
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final Session? session = _session;
    if (session == null) {
      return SignInScreen(
        showBack: false,
        onSignedIn: (Session session) => setState(() => _session = session),
      );
    }

    // Solo coordinación. Un docente que escriba su correo aquí entra bien al
    // servidor pero no tiene nada que hacer en este panel: la comunidad, los
    // protocolos y los códigos son de coordinación, y el servidor igual los
    // rechazaría. Se le dice claro en vez de mostrarle un tablero lleno de
    // errores.
    if (session.role != UserRole.administrador) {
      return _NotForYou(session: session, onSignOut: _signOut);
    }

    return PanelShell(onSignOut: _signOut);
  }
}

class _NotForYou extends StatelessWidget {
  const _NotForYou({required this.session, required this.onSignOut});

  final Session session;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ESTE PANEL ES DE COORDINACIÓN',
                  style: AppTextStyles.eyebrow.copyWith(color: AppColors.brand),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('SIN ACCESO', style: AppTextStyles.screenTitle),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Entraste como ${session.role.label.toLowerCase()}. La comunidad, '
                  'los protocolos y los códigos los maneja coordinación. Usa tu '
                  'celular para emitir alertas y ver tu grupo.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: onSignOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.border),
                    shape: const RoundedRectangleBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                  child: const Text('SALIR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
