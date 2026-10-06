import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/server_status_badge.dart';
import '../../../session/domain/session.dart';
import '../../domain/credentials.dart';
import '../../domain/enrollment_failure.dart';

/// «Ya tengo cuenta»: la entrada de docentes y coordinación.
///
/// Es la **única** forma de entrar para ellos. No hay código impreso para quien
/// puede emitir una alerta a 1.248 personas: un papel se queda sobre un
/// escritorio, se fotografía y no se puede cambiar. Una contraseña sí.
///
/// Se ve distinta a propósito —encabezado oscuro— para que nadie la confunda con
/// el registro de estudiantes y acudientes.
class SignInScreen extends StatefulWidget {
  const SignInScreen({this.onSignedIn, this.showBack = true, super.key});

  /// Qué hacer al entrar. Sin esto, la app sigue al paso de permisos, que es el
  /// camino del celular. El panel del computador lo usa para ir directo al
  /// tablero: no pide permisos de notificaciones.
  final void Function(Session session)? onSignedIn;

  /// Si muestra la flecha de volver. El panel no tiene a dónde volver.
  final bool showBack;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _isSigningIn = false;
  bool _showPassword = false;

  /// Lo que salió mal, para mostrarlo bajo los campos en vez de en un mensaje
  /// que se va solo: quien está entrando necesita poder leerlo mientras corrige.
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSigningIn) return;

    final (Credentials? credentials, String? problem) = Credentials.tryBuild(
      email: _email.text,
      password: _password.text,
    );

    if (credentials == null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _isSigningIn = true;
      _error = null;
    });

    try {
      final AppScope scope = AppScope.of(context);
      final NavigatorState navigator = Navigator.of(context);

      final Session session = await scope.credentialsRepository.signIn(credentials);
      await scope.sessionStore.save(session);

      if (!mounted) return;

      final void Function(Session session)? onSignedIn = widget.onSignedIn;
      if (onSignedIn != null) {
        onSignedIn(session);
        return;
      }

      // Al paso de permisos, igual que quien entra con código: un docente
      // también necesita que la alerta le suene con el celular en el bolsillo.
      await navigator.pushNamed(AppRoutes.permissions);
    } on EnrollmentFailure catch (failure, stack) {
      ErrorReporter.report(failure, stack, context: 'iniciar sesión');
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'iniciar sesión');
      if (mounted) setState(() => _error = 'No pudimos entrar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    // Con el teclado abierto, en un celular quedan unos 200 puntos de pantalla: el
    // botón fijo abajo se comía el campo de la contraseña. Con el teclado
    // arriba, el botón pasa a ser parte del formulario y baja con él.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final Widget enterButton = PrimaryButton(
      label: 'Entrar',
      icon: null,
      background: AppColors.ink,
      isLoading: _isSigningIn,
      onPressed: _signIn,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        // En el computador de coordinación el formulario no se estira a todo el
        // ancho de la pantalla. En el celular, 480 es más que el ancho disponible.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: <Widget>[
              _DarkHeader(
                showBack: widget.showBack,
                onBack: _isSigningIn ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const ServerStatusBadge(),
                      const SizedBox(height: AppSpacing.md),
                      const _FieldLabel('Correo institucional'),
                      TextField(
                        controller: _email,
                        enabled: !_isSigningIn,
                        keyboardType: TextInputType.emailAddress,
                        // El teclado del celular pone mayúscula al inicio y
                        // autocorrige: las dos cosas rompen un correo.
                        textCapitalization: TextCapitalization.none,
                        autocorrect: false,
                        autofillHints: const <String>[AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        onChanged: (_) => _clearError(),
                        decoration: const InputDecoration(hintText: 'nombre@colegio.edu.co'),
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const _FieldLabel('Contraseña'),
                      TextField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        enabled: !_isSigningIn,
                        obscureText: !_showPassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const <String>[AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _signIn(),
                        onChanged: (_) => _clearError(),
                        decoration: InputDecoration(
                          // Poder verla evita el error más común de escribir una
                          // contraseña larga en un teclado de celular, y la
                          // decisión de mostrarla es de quien la escribe.
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: AppColors.inkMuted,
                            ),
                            tooltip: _showPassword ? 'Ocultar' : 'Mostrar',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        style: AppTextStyles.body,
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _ErrorNote(message: _error!),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '¿Olvidaste tu contraseña? Pídele a coordinación que '
                          'la restablezca.',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (keyboardOpen) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        enterButton,
                      ],
                    ],
                  ),
                ),
              ),
              if (!keyboardOpen)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      0,
                      AppSpacing.screenGutter,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(Icons.info_outline, size: 14, color: AppColors.inkFaint),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Solo para docentes y responsables de ALERTIC en '
                                'la institución. Si eres estudiante o acudiente, '
                                'vuelve atrás y usa el código de tu carné.',
                                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        enterButton,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkHeader extends StatelessWidget {
  const _DarkHeader({required this.showBack, required this.onBack});

  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.md,
            AppSpacing.screenGutter,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showBack)
                InkResponse(
                  onTap: onBack,
                  radius: 22,
                  child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.onBrand),
                )
              else
                const SizedBox(height: 18),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_outline, size: 22, color: AppColors.onBrand),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Docentes y coordinación',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: AppColors.onBrand,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Ingreso fijo, sin código de un solo uso.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text.toUpperCase(), style: AppTextStyles.eyebrow),
    );
  }
}

/// El error, debajo de los campos y en rojo, no en un mensaje que se va solo.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.error_outline, size: 16, color: AppColors.brand),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.caption.copyWith(color: AppColors.brand),
          ),
        ),
      ],
    );
  }
}
