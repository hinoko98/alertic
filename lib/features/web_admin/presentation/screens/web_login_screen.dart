import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../onboarding/domain/credentials.dart';
import '../../../onboarding/domain/enrollment_failure.dart';
import '../../../session/domain/session.dart';
import '../web_style.dart';

/// Ingreso del administrador al panel web.
///
/// Dos columnas como en el diseño: a la izquierda lo que hace el panel, a la
/// derecha el formulario. En pantallas angostas queda solo el formulario.
class WebLoginScreen extends StatefulWidget {
  const WebLoginScreen({required this.onSignedIn, this.notice, super.key});

  final void Function(Session session) onSignedIn;

  /// Un aviso previo al formulario, p. ej. «esta cuenta no es de administrador».
  final String? notice;

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.notice;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    final (Credentials? credentials, String? problem) =
        Credentials.tryBuild(email: _email.text, password: _password.text);
    if (credentials == null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final AppScope scope = AppScope.of(context);
      final Session session = await scope.credentialsRepository.signIn(credentials);
      if (!mounted) return;
      // El rol lo dice el servidor. El panel es solo del administrador: un
      // docente que entra por aquí no ve nada que no pueda ver en el celular,
      // pero tampoco se le deja a medias dentro de una pantalla que no es suya.
      if (!session.role.usesPassword || session.role.wire != 'administrador') {
        await scope.credentialsRepository.signOut();
        if (mounted) {
          setState(() => _error = 'Este panel es solo para la coordinación del colegio. '
              'Usa la app del celular.');
        }
        return;
      }
      await scope.sessionStore.save(session);
      if (mounted) widget.onSignedIn(session);
    } on EnrollmentFailure catch (failure, stack) {
      ErrorReporter.report(failure, stack, context: 'iniciar sesión (panel web)');
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'iniciar sesión (panel web)');
      if (mounted) setState(() => _error = 'No pudimos entrar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 960;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: <Widget>[
          if (wide) const Expanded(child: _Pitch()),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (!wide) ...<Widget>[const _Brand(dark: true), const SizedBox(height: 32)],
                        const Text(
                          'Ingresar',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: WebColors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Usa el correo institucional que te entregó ALERTIC.',
                          style: WebText.sub.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 24),
                        WebField(
                          label: 'Correo institucional',
                          controller: _email,
                          enabled: !_busy,
                          hint: 'nombre@colegio.edu.co',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const <String>[AutofillHints.username],
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 18),
                        WebField(
                          label: 'Contraseña',
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !_busy,
                          obscure: !_showPassword,
                          autofillHints: const <String>[AutofillHints.password],
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _signIn(),
                          suffix: IconButton(
                            tooltip: _showPassword ? 'Ocultar' : 'Mostrar',
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                              color: WebColors.inkMuted,
                            ),
                          ),
                        ),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 14),
                          WebErrorNote(_error!),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          '¿Olvidaste tu contraseña? Pídele a coordinación que la restablezca.',
                          style: WebText.small.copyWith(color: WebColors.brandDark, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          child: WebButton(label: 'Entrar al panel', busy: _busy, onPressed: _signIn),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: WebColors.page,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Icon(Icons.lock_outline, size: 18, color: Color(0xFF4A5560)),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Acceso exclusivo para los responsables de gestión del riesgo '
                                  'del colegio. Cada acción queda registrada.',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF4A5560)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: dark ? WebColors.brand : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.verified_user_outlined, size: 26, color: dark ? Colors.white : WebColors.brand),
        ),
        const SizedBox(width: 12),
        Text(
          'ALERTIC',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: dark ? WebColors.ink : Colors.white,
          ),
        ),
      ],
    );
  }
}

class _Pitch extends StatelessWidget {
  const _Pitch();

  static const List<String> _points = <String>[
    'Alertas a todo el colegio en segundos',
    'Quién está a salvo y quién necesita ayuda',
    'Usuarios, códigos, rutas y simulacros',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WebColors.brand,
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _Brand(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Panel del administrador',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Desde aquí tu colegio emite alertas, sigue la evacuación en vivo '
                      'y prepara a toda la comunidad.',
                      style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
                    ),
                    const SizedBox(height: 26),
                    for (final String point in _points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0x2EFFFFFF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(point, style: const TextStyle(color: Colors.white, fontSize: 16)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Text(
            'Una sola plataforma para cualquier institución educativa.',
            style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
