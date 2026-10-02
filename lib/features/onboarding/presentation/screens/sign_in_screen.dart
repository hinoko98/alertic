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

/// «Ya tengo cuenta»: la entrada de docentes y administradores.
///
/// Es la **única** forma de entrar para ellos. No hay código impreso para quien
/// puede emitir una alerta a 1.248 personas: un papel se queda sobre un
/// escritorio, se fotografía y no se puede cambiar. Una contraseña sí.
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
    if (_isSigningIn) {
      return;
    }

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

      final Session session = await scope.credentialsRepository.signIn(
        credentials,
      );
      await scope.sessionStore.save(session);

      if (!mounted) {
        return;
      }

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
      if (mounted) {
        setState(() => _error = failure.message);
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'iniciar sesión');
      if (mounted) {
        setState(() => _error = 'No pudimos entrar. Intenta otra vez.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Con el teclado abierto, en un celular quedan unos 200 puntos de pantalla: el
    // botón fijo abajo se comía el campo de la contraseña y no se veía lo que se
    // escribía. Con el teclado arriba, el botón pasa a ser parte del formulario y
    // baja con él.
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final Widget enterButton = PrimaryButton(
      label: 'ENTRAR',
      isLoading: _isSigningIn,
      onPressed: _signIn,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                onPressed: _isSigningIn
                    ? null
                    : () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: SafeArea(
        // En el computador de coordinación el formulario no se estira a todo el
        // ancho de la pantalla: un campo de correo de 1.200 puntos no se lee. En
        // el celular, 480 es más que el ancho disponible y no cambia nada.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      0,
                      AppSpacing.screenGutter,
                      AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const ServerStatusBadge(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'DOCENTES Y COORDINACIÓN',
                          style: AppTextStyles.eyebrow.copyWith(
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'INICIAR SESIÓN',
                          style: AppTextStyles.screenTitle,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Con la cuenta que te dio el colegio. Si eres estudiante '
                          'o acudiente, vuelve atrás y usa tu código del carné.',
                          style: AppTextStyles.caption,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        const _FieldLabel('Correo'),
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
                          decoration: _decoration('nombre@iic.edu.co'),
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
                          decoration: _decoration('').copyWith(
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
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                          style: AppTextStyles.body,
                        ),

                        if (_error != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          _ErrorNote(message: _error!),
                        ],

                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          '¿Olvidaste la contraseña? Pídele a coordinación que te '
                          'la restablezca.',
                          style: AppTextStyles.caption,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenGutter,
                      0,
                      AppSpacing.screenGutter,
                      AppSpacing.lg,
                    ),
                    child: enterButton,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// El error se va en cuanto la persona empieza a corregir.
  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: AppTextStyles.caption,
      isDense: true,
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.brand, width: 2),
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: AppColors.border),
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
      child: Text(text, style: AppTextStyles.eyebrow),
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
