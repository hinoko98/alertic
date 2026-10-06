import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/notifications/device_registrar.dart';
import '../../../../core/session/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../session/domain/session.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 04: los permisos.
///
/// Explica para qué sirve cada uno antes de pedirlo: así la gente acepta con
/// confianza. «Ahora no» no bloquea el registro: sin las notificaciones la alerta
/// igual llega por el canal en vivo mientras la app esté abierta, y dejar a un
/// estudiante sin la app por un permiso sería peor.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _criticalAlerts = true;
  bool _location = true;
  bool _busy = false;

  Future<void> _continue({required bool grant}) async {
    if (_busy) return;
    setState(() => _busy = true);

    final NavigatorState navigator = Navigator.of(context);
    final AppScope scope = AppScope.of(context);

    try {
      final Session? session = await scope.sessionStore.read();

      if (grant) {
        if (_criticalAlerts) {
          /*
           * Aquí Android muestra el diálogo de notificaciones, se crean los
           * canales y el token del celular queda registrado en el colegio.
           *
           * No se espera un resultado para dejar entrar: `enroll` nunca lanza y
           * devuelve si quedó conectado. Si la persona dice que no, o si el
           * colegio todavía no tiene Firebase, entra igual.
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

        // Lo que la persona eligió se guarda en el colegio: el perfil lo muestra
        // y lo puede cambiar. Si no se puede guardar ahora, no se frena el
        // registro: queda con los valores por omisión, que son los mismos.
        try {
          await scope.accountRepository?.updateSettings(
            criticalAlerts: _criticalAlerts,
            shareLocation: _location,
          );
        } catch (error, stack) {
          ErrorReporter.report(error, stack, context: 'guardar permisos');
        }
      }

      if (!mounted) return;
      if (session == null) {
        // La sesión se abre al confirmar la identidad. Si no está, algo se
        // perdió por el camino y hay que empezar de nuevo.
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.welcome,
          (Route<void> _) => false,
        );
        return;
      }

      // Un estudiante deja anotado a quién avisar; los demás entran ya.
      if (session.role == UserRole.estudiante) {
        navigator.pushNamed(AppRoutes.familySetup, arguments: session);
      } else {
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.home,
          (Route<void> _) => false,
          arguments: session,
        );
      }
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
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Activa los avisos',
      step: 2,
      showBack: false,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PrimaryButton(
            label: 'Permitir y continuar',
            isLoading: _busy,
            onPressed: () => _continue(grant: true),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: _busy ? null : () => _continue(grant: false),
            child: const Text(
              'Ahora no',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.inkMuted,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FutureBuilder<Session?>(
            future: AppScope.of(context).sessionStore.read(),
            builder: (BuildContext context, AsyncSnapshot<Session?> snapshot) {
              final Session? session = snapshot.data;
              if (session == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: _Validated(role: session.role.label),
              );
            },
          ),
          const Text(
            'Para avisarte a tiempo necesitamos dos permisos',
            style: AppTextStyles.screenTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Solo se usan durante una alerta o un simulacro.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: <Widget>[
                _PermissionRow(
                  switchKey: const Key('permiso-alertas'),
                  icon: Icons.notifications_none,
                  title: 'Alertas críticas',
                  description: 'Suenan aunque el celular esté en silencio',
                  value: _criticalAlerts,
                  onChanged: (bool value) => setState(() => _criticalAlerts = value),
                ),
                const Divider(height: 1),
                _PermissionRow(
                  switchKey: const Key('permiso-ubicacion'),
                  icon: Icons.location_on_outlined,
                  title: 'Ubicación',
                  description: 'Para guiarte por la ruta al punto de encuentro',
                  value: _location,
                  onChanged: (bool value) => setState(() => _location = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.shield_outlined, size: 14, color: AppColors.inkFaint),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tu ubicación no se guarda ni se comparte fuera de una '
                  'emergencia. Puedes cambiar esto en Perfil.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Validated extends StatelessWidget {
  const _Validated({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 18, color: AppColors.success),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Acceso validado',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(fontSize: 11, color: AppColors.success),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          IconBubble(icon: icon, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.surface,
            activeTrackColor: AppColors.brand,
            inactiveThumbColor: AppColors.surface,
            inactiveTrackColor: AppColors.border,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
