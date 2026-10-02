import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/notifications/device_registrar.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../session/domain/session.dart';
import '../widgets/permission_toggle.dart';

/// Pantalla 06: último paso del registro. Sin estos permisos la alerta puede
/// no sonar, que es justo lo que la app existe para evitar.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _criticalAlerts = true;
  bool _location = true;
  bool _offlineMaps = true;
  bool _isActivating = false;

  Future<void> _activate() async {
    setState(() => _isActivating = true);
    try {
      final NavigatorState navigator = Navigator.of(context);
      final AppScope scope = AppScope.of(context);
      final Session? session = await scope.sessionStore.read();

      if (_criticalAlerts) {
        /*
         * Aquí Android muestra el diálogo de notificaciones, se crean los
         * canales y el token del celular queda registrado en el colegio.
         *
         * No se espera un resultado para dejar entrar: `enroll` nunca lanza y
         * devuelve si quedó conectado. Si la persona dice que no, o si el
         * colegio todavía no tiene Firebase, entra igual y las alertas le
         * llegan por el canal en vivo mientras tenga la app abierta. Bloquear
         * el registro por un permiso sería dejar a un estudiante sin la app.
         */
        final bool ready = await DeviceEnrollment(
          notifications: scope.notifications,
          registrar: scope.deviceRegistrar,
        ).enroll();

        if (!ready) {
          ErrorReporter.trace(
            'notificaciones sin activar: la alerta llegará con la app abierta',
          );
        }
      }

      // TODO(permisos): faltan los otros dos permisos reales.
      //   - Ubicación: permiso "mientras se usa la app" (geolocator).
      //   - Sin conexión: descargar plano y protocolos a almacenamiento local.

      if (!mounted) {
        return;
      }
      if (session == null) {
        // La sesión se abre al confirmar la identidad. Si no está, algo se
        // perdió por el camino y hay que empezar de nuevo.
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.welcome,
          (Route<void> _) => false,
        );
        return;
      }

      // El rol lo trae la sesión: la app que se abre la decide el servidor.
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (Route<void> _) => false,
        arguments: session,
      );
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'activar permisos');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron activar los permisos. Intenta otra vez.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                  AppSpacing.screenGutter,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('ÚLTIMO PASO', style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Para que la alerta te llegue siempre, activa estos '
                      'permisos.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Divider(height: 1),
                    PermissionToggle(
                      icon: Icons.notifications_active_outlined,
                      title: 'Alertas críticas',
                      description: 'Suenan al máximo aunque el celular esté en '
                          'silencio o en No molestar.',
                      value: _criticalAlerts,
                      onChanged: (bool value) =>
                          setState(() => _criticalAlerts = value),
                    ),
                    const Divider(height: 1),
                    PermissionToggle(
                      icon: Icons.location_on_outlined,
                      title: 'Ubicación',
                      description: 'Solo se comparte durante una alerta activa, '
                          'con tu docente y acudientes.',
                      value: _location,
                      onChanged: (bool value) =>
                          setState(() => _location = value),
                    ),
                    const Divider(height: 1),
                    PermissionToggle(
                      icon: Icons.cloud_off_outlined,
                      title: 'Guardar sin conexión',
                      description: 'Plano del colegio y protocolos en el '
                          'celular. 4 MB.',
                      value: _offlineMaps,
                      onChanged: (bool value) =>
                          setState(() => _offlineMaps = value),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                0,
                AppSpacing.screenGutter,
                AppSpacing.lg,
              ),
              child: PrimaryButton(
                label: 'ACTIVAR Y ENTRAR',
                isLoading: _isActivating,
                onPressed: _activate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
