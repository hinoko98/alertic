import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/enrollment.dart';
import '../../domain/enrollment_failure.dart';
import '../../domain/personal_code.dart';
import '../../domain/school.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 03: el código del colegio y el código personal.
///
/// Primero los cuatro caracteres del colegio: al escribirlos, el servidor dice de
/// qué colegio son y la pantalla muestra su nombre para que la persona confirme
/// que es el suyo. Después, los cuatro de la persona. Entre los dos son los ocho
/// caracteres del carné (`IICB-7K4P`).
///
/// Solo estudiantes y acudientes: los docentes entran con correo y contraseña.
class EnterCodeScreen extends StatefulWidget {
  const EnterCodeScreen({super.key});

  @override
  State<EnterCodeScreen> createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final TextEditingController _school = TextEditingController();
  final TextEditingController _personal = TextEditingController();
  final FocusNode _schoolFocus = FocusNode();
  final FocusNode _personalFocus = FocusNode();

  School? _confirmedSchool;
  String? _schoolError;
  String? _error;
  bool _checkingSchool = false;
  bool _isValidating = false;

  /// El código del colegio que ya se comprobó, para no volver a preguntar lo
  /// mismo cada vez que se redibuja.
  String _checkedSchoolCode = '';

  @override
  void initState() {
    super.initState();
    _schoolFocus.addListener(() => setState(() {}));
    _personalFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _school.dispose();
    _personal.dispose();
    _schoolFocus.dispose();
    _personalFocus.dispose();
    super.dispose();
  }

  String get _digits => '${_school.text}${_personal.text}';

  bool get _isComplete =>
      _confirmedSchool != null && _digits.length == PersonalCode.digitsLength;

  Future<void> _onSchoolChanged(String value) async {
    setState(() {
      _error = null;
      _schoolError = null;
    });

    if (value.length < PersonalCode.groupLength) {
      setState(() => _confirmedSchool = null);
      _checkedSchoolCode = '';
      return;
    }
    if (value == _checkedSchoolCode) return;
    _checkedSchoolCode = value;

    setState(() => _checkingSchool = true);
    try {
      final School school =
          await AppScope.of(context).enrollmentRepository.findSchool(value);
      // Si la persona siguió escribiendo mientras se preguntaba, esa respuesta ya
      // no es de lo que hay en el campo.
      if (!mounted || _school.text != value) return;
      setState(() {
        _confirmedSchool = school;
        _checkingSchool = false;
      });
      // El campo personal se habilita con este mismo redibujo: se le pide el foco
      // cuando ya está habilitado, no antes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _personalFocus.requestFocus();
      });
    } on EnrollmentFailure catch (failure) {
      if (mounted && _school.text == value) {
        setState(() {
          _confirmedSchool = null;
          _schoolError = failure.message;
          _checkingSchool = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'validar colegio');
      if (mounted && _school.text == value) {
        setState(() {
          _confirmedSchool = null;
          _checkedSchoolCode = '';
          _schoolError = 'No pudimos comprobar el colegio. Revisa tu conexión.';
          _checkingSchool = false;
        });
      }
    }
  }

  void _onPersonalChanged(String value) {
    setState(() => _error = null);
    if (value.isEmpty) {
      _schoolFocus.unfocus();
    }
    if (_isComplete) {
      _validate();
    }
  }

  Future<void> _validate() async {
    if (_isValidating) return;

    final PersonalCode? code = PersonalCode.tryParse(_digits);
    if (code == null) {
      setState(() => _error = 'Revisa el código: son 8 caracteres del carné.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final Enrollment enrollment =
          await AppScope.of(context).enrollmentRepository.findByCode(code);
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        AppRoutes.confirmIdentity,
        arguments: enrollment,
      );
    } on EnrollmentFailure catch (failure, stack) {
      // Errores esperados: el mensaje ya viene escrito para la persona.
      ErrorReporter.report(failure, stack, context: 'validar código');
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'validar código');
      if (mounted) {
        setState(() => _error = 'No pudimos validar el código. Intenta otra vez.');
      }
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Acceso institucional',
      step: 1,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.lock_outline, size: 14, color: AppColors.inkFaint),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Tu código abre únicamente el perfil que creó tu colegio. No '
                  'es un código compartido.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Validar código',
            isLoading: _isValidating,
            onPressed: _isComplete ? _validate : null,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Tu código de acceso', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Primero el código de tu colegio y luego tu código personal. Ambos '
            'los entrega secretaría o el director de grupo.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _CodeBox(
                        label: '1 · COLEGIO',
                        fieldKey: const Key('codigo-colegio'),
                        controller: _school,
                        focusNode: _schoolFocus,
                        dark: true,
                        autofocus: true,
                        hint: 'IICB',
                        onChanged: _onSchoolChanged,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _CodeBox(
                        label: '2 · TU CÓDIGO PERSONAL',
                        fieldKey: const Key('codigo-personal'),
                        controller: _personal,
                        focusNode: _personalFocus,
                        enabled: _confirmedSchool != null,
                        hint: '7K4P',
                        onChanged: _onPersonalChanged,
                      ),
                    ),
                  ],
                ),
                if (_checkingSchool)
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.brand,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                if (_confirmedSchool != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _SchoolCard(school: _confirmedSchool!),
                ],
                if (_schoolError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorLine(message: _schoolError!, key: const Key('error-colegio')),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorLine(message: _error!, key: const Key('error-codigo')),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const HintCard(
            title: '¿No tienes código?',
            body: 'Pídelo en la secretaría de tu colegio. El código personal es '
                'de un solo uso y dura una hora; si no lo usas a tiempo o '
                'cambias de celular, te dan uno nuevo.',
          ),
        ],
      ),
    );
  }
}

/// Un grupo de cuatro caracteres, grande y espaciado como en el carné.
class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.label,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    this.dark = false,
    this.enabled = true,
    this.autofocus = false,
  });

  final String label;
  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool dark;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final bool focused = focusNode.hasFocus;
    final Color foreground = dark ? AppColors.onBrand : AppColors.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: dark ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: Border.all(
              color: dark
                  ? AppColors.ink
                  : focused
                      ? AppColors.brand
                      : AppColors.brand.withValues(alpha: enabled ? 0.6 : 0.2),
              width: focused && !dark ? 2 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.visiblePassword,
            maxLength: PersonalCode.groupLength,
            style: AppTextStyles.code.copyWith(color: foreground),
            cursorColor: foreground,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              TextInputFormatter.withFunction(
                (TextEditingValue old, TextEditingValue value) =>
                    value.copyWith(text: value.text.toUpperCase()),
              ),
            ],
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 22,
                letterSpacing: 4,
                color: dark ? Colors.white30 : AppColors.inkFaint,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school});

  final School school;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('colegio-confirmado'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
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
                Text(
                  school.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  school.city,
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

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message, super.key});

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
