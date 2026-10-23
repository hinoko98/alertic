import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/pill.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/enrollment_failure.dart';
import '../../domain/guardian_link.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 12: los datos de contacto del acudiente.
///
/// Al continuar se envía una solicitud por cada hijo. Ninguna abre sesión: el
/// colegio las aprueba y el celular las reclama en el último paso.
class GuardianDataScreen extends StatefulWidget {
  const GuardianDataScreen({required this.draft, super.key});

  final GuardianDraft draft;

  @override
  State<GuardianDataScreen> createState() => _GuardianDataScreenState();
}

class _GuardianDataScreenState extends State<GuardianDataScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _document = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();

  GuardianDocumentType _type = GuardianDocumentType.cc;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _document.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _documentDigits => _document.text.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

  /// El primer problema que ve la persona, o `null` si todo está bien.
  String? _validate() {
    if (_name.text.trim().split(' ').where((String p) => p.isNotEmpty).length < 2) {
      return 'Escribe tu nombre completo.';
    }
    if (_documentDigits.length < 5) return 'Revisa tu número de documento.';
    if (!RegExp(r'^[0-9+() -]{7,20}$').hasMatch(_phone.text.trim())) {
      return 'Revisa el celular: solo números, mínimo 7.';
    }
    final String email = _email.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Revisa el correo o déjalo vacío.';
    }
    return null;
  }

  Future<void> _send() async {
    final String? problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final contact = GuardianContact(
        fullName: _name.text.trim(),
        documentType: _type,
        document: _documentDigits,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
      );
      final repository = AppScope.of(context).enrollmentRepository;
      final List<LinkRequest> requests = <LinkRequest>[];
      for (final StudentMatch child in widget.draft.children) {
        requests.add(
          await repository.requestGuardianLink(
            draft: widget.draft,
            student: child,
            contact: contact,
          ),
        );
      }
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        AppRoutes.guardianLinked,
        arguments: GuardianStepArgs(draft: widget.draft, requests: requests),
      );
    } on EnrollmentFailure catch (failure, stack) {
      ErrorReporter.report(failure, stack, context: 'solicitar vinculación');
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'solicitar vinculación');
      if (mounted) setState(() => _error = 'No pudimos enviar tus datos. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<StudentMatch> children = widget.draft.children;

    return OnboardingScaffold(
      title: 'Registro del acudiente',
      subtitle: 'Paso 3 de 4',
      step: 2,
      stepCount: 4,
      footer: PrimaryButton(
        label: 'Continuar',
        icon: null,
        isLoading: _sending,
        onPressed: _send,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('Tus datos de contacto', style: AppTextStyles.screenTitle),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final StudentMatch child in children)
                Pill('${child.firstName} · ${child.grade}', tone: PillTone.success),
              Pill(widget.draft.relationship.label),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('acudiente-nombre'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const <String>[AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Nombre completo'),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<GuardianDocumentType>(
                  key: const Key('acudiente-tipo'),
                  initialValue: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: <DropdownMenuItem<GuardianDocumentType>>[
                    for (final GuardianDocumentType type in GuardianDocumentType.values)
                      DropdownMenuItem<GuardianDocumentType>(
                        value: type,
                        child: Text(type.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (GuardianDocumentType? value) =>
                      setState(() => _type = value ?? _type),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: const Key('acudiente-numero'),
                  controller: _document,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9 .]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Número de documento'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('acudiente-celular'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            autofillHints: const <String>[AutofillHints.telephoneNumber],
            decoration: const InputDecoration(labelText: 'Celular'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('acudiente-correo'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Correo (opcional)',
              hintText: 'nombre@correo.com',
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 16, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _error!,
                    key: const Key('error-datos'),
                    style: AppTextStyles.caption.copyWith(color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
