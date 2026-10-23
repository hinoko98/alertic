import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../session/domain/session.dart';
import 'screens/web_login_screen.dart';
import 'web_shell.dart';
import 'web_style.dart';

/// La puerta del panel web: con sesión de administrador vigente muestra el
/// panel; si no, el ingreso.
///
/// Recupera la sesión guardada al abrir, para que recargar la pestaña no
/// obligue a volver a escribir la contraseña mientras el servidor la acepte.
class WebGate extends StatefulWidget {
  const WebGate({super.key});

  @override
  State<WebGate> createState() => _WebGateState();
}

class _WebGateState extends State<WebGate> {
  Session? _session;
  bool _restoring = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _restore();
  }

  Future<void> _restore() async {
    final Session? saved = await AppScope.of(context).sessionStore.read();
    if (!mounted) return;
    setState(() {
      _session = (saved != null && !saved.isExpired() && saved.role.wire == 'administrador')
          ? saved
          : null;
      _restoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const Scaffold(
        backgroundColor: WebColors.page,
        body: Center(child: CircularProgressIndicator(color: WebColors.brand)),
      );
    }
    final Session? session = _session;
    if (session == null) {
      return WebLoginScreen(onSignedIn: (Session s) => setState(() => _session = s));
    }
    return WebShell(
      session: session,
      onSignedOut: () => setState(() => _session = null),
    );
  }
}
