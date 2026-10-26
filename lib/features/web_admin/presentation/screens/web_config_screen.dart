import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../onboarding/domain/credentials.dart';
import '../../../onboarding/domain/enrollment_failure.dart';
import '../../../onboarding/domain/school.dart';
import '../../../panel/domain/panel_repository.dart';
import '../web_nav.dart';
import '../web_style.dart';
import '../web_widgets.dart';
import 'web_usuarios_screen.dart';

/// Datos de la institución, quién administra el panel y la seguridad de la
/// propia cuenta.
class WebConfigScreen extends StatefulWidget {
  const WebConfigScreen({super.key});

  @override
  State<WebConfigScreen> createState() => _WebConfigScreenState();
}

class _WebConfigScreenState extends State<WebConfigScreen> {
  late Future<School?> _school;
  late Future<List<CommunityMember>> _admins;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reload();
  }

  void _reload() {
    final AppScope scope = AppScope.of(context);
    setState(() {
      _school = scope.accountRepository == null ? Future<School?>.value() : scope.accountRepository!.loadSchool();
      _admins = scope.panelRepository!.loadCommunity(role: 'administrador');
    });
  }

  @override
  Widget build(BuildContext context) {
    final WebNav nav = WebNav.of(context);
    return WebPageFrame(
      title: 'Configuración',
      subtitle: 'Datos de la institución, administradores y seguridad de tu cuenta',
      children: <Widget>[
        WebGrid(minWidth: 380, children: <Widget>[
          WebFuture<School?>(
            future: _school,
            onRetry: _reload,
            builder: (BuildContext context, School? s) => WebPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const WebPanelHeader(title: 'Institución'),
                  const SizedBox(height: 8),
                  WebKeyValue('Nombre', s?.name ?? '—'),
                  WebKeyValue('Municipio', s?.city ?? '—'),
                  const SizedBox(height: 10),
                  const WebNotice('El nombre y el código del colegio los define ALERTIC al crearlo. Para cambiarlos, escríbele a soporte.'),
                ],
              ),
            ),
          ),
          WebPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const WebPanelHeader(title: 'Tu cuenta'),
                const SizedBox(height: 8),
                WebKeyValue('Nombre', nav.session.profile.fullName),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
                  WebButton(
                    label: 'Cambiar mi contraseña',
                    secondary: true,
                    icon: Icons.lock_outline,
                    onPressed: () => showDialog<void>(context: context, builder: (_) => const _ChangePasswordDialog()),
                  ),
                ]),
              ],
            ),
          ),
        ]),
        WebPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const WebPanelHeader(title: 'Administradores', subtitle: 'Quién puede emitir alertas y cambiar lo del colegio'),
              const SizedBox(height: 8),
              WebFuture<List<CommunityMember>>(
                future: _admins,
                onRetry: _reload,
                builder: (BuildContext context, List<CommunityMember> admins) => WebTable(
                  headers: const <String>['Persona', 'Correo', 'Acceso'],
                  empty: 'No hay administradores.',
                  rows: <List<Widget>>[
                    for (final CommunityMember a in admins)
                      <Widget>[
                        Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                          WebAvatar(a.fullName, dark: true),
                          const SizedBox(width: 10),
                          Text(a.fullName, style: WebText.strong),
                        ]),
                        Text(a.linkedTo ?? '—'),
                        WebChip(webCodeStatus(a.codeStatus).$1, tone: webCodeStatus(a.codeStatus).$2),
                      ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const WebUnavailable(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Permisos por administrador, equipo de respuesta y avisos',
          detail: 'Dar permisos distintos a cada administrador, editar el equipo de respuesta, los contactos de emergencia y los ajustes de avisos todavía no existe en el servidor. Hoy todo administrador puede todo.',
        ),
      ],
    );
  }
}

/// Cambiar la contraseña de quien tiene la sesión abierta.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  bool get _hasLength => _next.text.length >= Credentials.minPasswordLength;
  bool get _hasUpperAndNumber => RegExp(r'[A-ZÁÉÍÓÚÑ]').hasMatch(_next.text) && RegExp(r'\d').hasMatch(_next.text);

  Future<void> _save() async {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña actual.');
      return;
    }
    if (!_hasLength || !_hasUpperAndNumber) {
      setState(() => _error = 'La nueva contraseña no cumple los requisitos.');
      return;
    }
    if (_next.text != _again.text) {
      setState(() => _error = 'Las dos contraseñas nuevas no coinciden.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).credentialsRepository.changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      webToast(context, 'Contraseña cambiada');
    } on EnrollmentFailure catch (f) {
      if (mounted) setState(() => _error = f.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cambiar contraseña (panel web)');
      if (mounted) setState(() => _error = 'No se pudo cambiar la contraseña.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _rule(bool ok, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: <Widget>[
          Icon(ok ? Icons.check : Icons.circle_outlined, size: 16, color: ok ? WebColors.goodText : WebColors.inkMuted),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 13, color: ok ? WebColors.goodText : WebColors.inkMuted)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar mi contraseña'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            WebField(label: 'Contraseña actual', controller: _current, obscure: true, enabled: !_busy),
            const SizedBox(height: 14),
            WebField(label: 'Nueva contraseña', controller: _next, obscure: true, enabled: !_busy, onChanged: (_) => setState(() => _error = null)),
            const SizedBox(height: 14),
            WebField(label: 'Repítela', controller: _again, obscure: true, enabled: !_busy, onSubmitted: (_) => _save()),
            _rule(_hasLength, 'Al menos ${Credentials.minPasswordLength} caracteres'),
            _rule(_hasUpperAndNumber, 'Una mayúscula y un número'),
            if (_error != null) ...<Widget>[const SizedBox(height: 12), WebErrorNote(_error!)],
          ]),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('CANCELAR')),
        TextButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'GUARDANDO…' : 'GUARDAR')),
      ],
    );
  }
}

/// La repetición minuto a minuto de un simulacro.
class WebRepeticionScreen extends StatelessWidget {
  const WebRepeticionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebPageFrame(
      title: 'Repetición de simulacros',
      subtitle: 'Mira cómo se movió el colegio minuto a minuto y dónde se formaron filas',
      children: <Widget>[
        WebUnavailable(
          icon: Icons.play_circle_outline,
          title: 'Todavía no se guarda el movimiento',
          detail: 'Para repetir un simulacro con el mapa de calor, la app tendría que registrar por dónde pasa cada persona. Hoy solo se guarda quién confirmó a salvo y cuándo; esos resultados están en Informes y Simulacros.',
        ),
      ],
    );
  }
}
