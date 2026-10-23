import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/enrollment_failure.dart';
import '../../domain/guardian_link.dart';
import '../../domain/school.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 10: el acudiente busca a su hijo o hija por documento.
///
/// Con el código del colegio y el documento del estudiante el servidor devuelve
/// sus datos **parciales**: lo justo para que el acudiente lo reconozca. Si ya
/// vino de «Agregar otro hijo», trae el borrador y el colegio ya está confirmado.
///
/// El ingreso con el código del carné sigue disponible abajo, para quien ya lo
/// tiene.
class GuardianSearchScreen extends StatefulWidget {
  const GuardianSearchScreen({this.draft, super.key});

  /// Con valor, el acudiente viene de agregar otro hijo.
  final GuardianDraft? draft;

  @override
  State<GuardianSearchScreen> createState() => _GuardianSearchScreenState();
}

class _GuardianSearchScreenState extends State<GuardianSearchScreen> {
  static const Map<String, String> _documentTypes = <String, String>{
    'TI': 'Tarjeta de identidad',
    'RC': 'Registro civil',
    'CC': 'Cédula de ciudadanía',
  };

  final TextEditingController _schoolCode = TextEditingController();
  final TextEditingController _document = TextEditingController();

  School? _school;
  String? _schoolError;
  String? _error;
  String _documentType = 'TI';
  String _checkedSchool = '';
  bool _checkingSchool = false;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final GuardianDraft? draft = widget.draft;
    if (draft != null) {
      _schoolCode.text = draft.schoolCode;
      _school = draft.school;
      _checkedSchool = draft.schoolCode;
    }
  }

  @override
  void dispose() {
    _schoolCode.dispose();
    _document.dispose();
    super.dispose();
  }

  String get _digits => _document.text.replaceAll(RegExp(r'\D'), '');

  bool get _canSearch => _school != null && _digits.length >= 5;

  Future<void> _onSchoolChanged(String value) async {
    setState(() {
      _error = null;
      _schoolError = null;
      if (value != _checkedSchool) _school = null;
    });
    if (value.length < 4 || value == _checkedSchool) return;
    _checkedSchool = value;

    setState(() => _checkingSchool = true);
    try {
      final School school =
          await AppScope.of(context).enrollmentRepository.findSchool(value);
      if (!mounted || _schoolCode.text != value) return;
      setState(() {
        _school = school;
        _checkingSchool = false;
      });
    } on EnrollmentFailure catch (failure) {
      if (mounted && _schoolCode.text == value) {
        setState(() {
          _school = null;
          _schoolError = failure.message;
          _checkingSchool = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'validar colegio');
      if (mounted && _schoolCode.text == value) {
        setState(() {
          _school = null;
          _checkedSchool = '';
          _schoolError = 'No pudimos comprobar el colegio. Revisa tu conexión.';
          _checkingSchool = false;
        });
      }
    }
  }

  Future<void> _search() async {
    final School? school = _school;
    if (school == null) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final StudentMatch student =
          await AppScope.of(context).enrollmentRepository.findStudentByDocument(
                schoolCode: _schoolCode.text,
                document: _digits,
              );
      if (!mounted) return;
      final GuardianDraft draft =
          widget.draft ?? GuardianDraft(schoolCode: _schoolCode.text, school: school);
      await Navigator.of(context).pushNamed(
        AppRoutes.guardianConfirm,
        arguments: GuardianStepArgs(draft: draft, student: student),
      );
    } on EnrollmentFailure catch (failure, stack) {
      ErrorReporter.report(failure, stack, context: 'buscar estudiante');
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'buscar estudiante');
      if (mounted) setState(() => _error = 'No pudimos buscar. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Registro del acudiente',
      subtitle: 'Paso 1 de 4',
      step: 0,
      stepCount: 4,
      footer: PrimaryButton(
        label: 'Buscar estudiante',
        icon: Icons.search,
        isLoading: _searching,
        onPressed: _canSearch ? _search : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Busca a tu hijo o hija', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Con el código del colegio y su documento cargamos sus datos de la '
            'matrícula.',
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
                const _FieldLabel('1 · CÓDIGO DEL COLEGIO'),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: TextField(
                    key: const Key('acudiente-colegio'),
                    controller: _schoolCode,
                    enabled: widget.draft == null,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 4,
                    style: AppTextStyles.code.copyWith(color: AppColors.onBrand),
                    cursorColor: AppColors.onBrand,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      TextInputFormatter.withFunction(
                        (TextEditingValue old, TextEditingValue value) =>
                            value.copyWith(text: value.text.toUpperCase()),
                      ),
                    ],
                    decoration: const InputDecoration(
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      hintText: 'IICB',
                      hintStyle: TextStyle(
                        fontSize: 22,
                        letterSpacing: 4,
                        color: Colors.white30,
                      ),
                    ),
                    onChanged: _onSchoolChanged,
                  ),
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
                if (_school != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _SchoolCard(school: _school!),
                ],
                if (_schoolError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorLine(message: _schoolError!, key: const Key('error-colegio')),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(height: 1),
                ),
                const _FieldLabel('2 · DOCUMENTO DEL ESTUDIANTE'),
                DropdownButtonFormField<String>(
                  key: const Key('acudiente-tipo-documento'),
                  initialValue: _documentType,
                  isExpanded: true,
                  items: <DropdownMenuItem<String>>[
                    for (final MapEntry<String, String> type in _documentTypes.entries)
                      DropdownMenuItem<String>(value: type.key, child: Text(type.value)),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _documentType = value ?? _documentType),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: const Key('acudiente-documento'),
                  controller: _document,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 .]')),
                  ],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'Número de documento del estudiante',
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ErrorLine(message: _error!, key: const Key('error-estudiante')),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.lock_outline, size: 14, color: AppColors.inkFaint),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Verás solo datos parciales hasta confirmar que eres el '
                  'acudiente registrado en el colegio.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
          if (widget.draft == null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                key: const Key('acudiente-tengo-codigo'),
                onPressed: () => Navigator.of(context).pushNamed(AppRoutes.enterCode),
                child: const Text('Ya tengo un código de acceso'),
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.inkMuted,
        ),
      ),
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
          const Icon(Icons.check, size: 18, color: AppColors.success),
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
