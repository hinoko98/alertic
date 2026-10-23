import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../onboarding/domain/guardian_link.dart';
import '../domain/account_repository.dart';

/// Agregar otro hijo, desde la cuenta de un acudiente que ya tiene sesión.
///
/// Se busca por documento, se confirma que es el hijo (con el apellido tapado) y
/// se dice el parentesco. La solicitud **no vincula sola**: el colegio la aprueba
/// y el hijo aparece en el perfil cuando lo haga.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final TextEditingController _document = TextEditingController();

  StudentMatch? _found;
  GuardianRelationship _relationship = GuardianRelationship.mother;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _document.dispose();
    super.dispose();
  }

  String get _digits => _document.text.replaceAll(RegExp(r'\D'), '');

  AccountRepository get _repository => AppScope.of(context).accountRepository!;

  /// Un mensaje claro para lo que el servidor sabe explicar; si no, uno genérico.
  String _messageFor(Object error, String fallback) {
    if (error is ApiException && error.statusCode != null && error.message.isNotEmpty) {
      return error.message;
    }
    if (error.toString().contains('estudiante_no_encontrado')) {
      return 'No encontramos un estudiante con esos datos. Revisa el documento o pide '
          'ayuda en secretaría.';
    }
    return fallback;
  }

  Future<void> _search() async {
    final AccountRepository repository = _repository;
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final StudentMatch student = await repository.lookupChild(_digits);
      if (mounted) setState(() => _found = student);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'buscar hijo');
      if (mounted) setState(() => _error = _messageFor(error, 'No pudimos buscar. Intenta otra vez.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final StudentMatch? student = _found;
    if (student == null) return;
    final AccountRepository repository = _repository;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.requestChild(student.document, _relationship);
      if (mounted) setState(() => _sent = true);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'pedir hijo');
      if (mounted) setState(() => _error = _messageFor(error, 'No pudimos enviar la solicitud.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Agregar un hijo',
      subtitle: 'El colegio confirma la vinculación',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      bottom: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.screenGutter,
            AppSpacing.md,
          ),
          child: _sent
              ? PrimaryButton(
                  key: const Key('listo-hijo'),
                  label: 'Listo',
                  icon: null,
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : _found == null
                  ? PrimaryButton(
                      key: const Key('buscar-hijo'),
                      label: 'Buscar estudiante',
                      icon: Icons.search,
                      isLoading: _busy,
                      onPressed: _digits.length >= 5 ? _search : null,
                    )
                  : PrimaryButton(
                      key: const Key('enviar-solicitud-hijo'),
                      label: 'Enviar solicitud',
                      icon: null,
                      isLoading: _busy,
                      onPressed: _send,
                    ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: _sent ? _sentView() : _formView(),
      ),
    );
  }

  List<Widget> _sentView() {
    return <Widget>[
      const SizedBox(height: AppSpacing.xl),
      Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
          child: const Icon(Icons.send_outlined, size: 44, color: AppColors.success),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      const Text(
        'Solicitud enviada',
        key: Key('solicitud-hijo-enviada'),
        textAlign: TextAlign.center,
        style: AppTextStyles.screenTitle,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'El colegio revisará que seas el acudiente de ${_found?.firstName ?? 'tu hijo'}. '
        'Cuando la apruebe, aparecerá en tu perfil.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      ),
    ];
  }

  List<Widget> _formView() {
    final StudentMatch? student = _found;

    return <Widget>[
      const Text('Busca a tu hijo o hija', style: AppTextStyles.screenTitle),
      const SizedBox(height: AppSpacing.sm),
      const Text(
        'Con el documento del estudiante cargamos sus datos de la matrícula.',
        style: AppTextStyles.caption,
      ),
      const SizedBox(height: AppSpacing.lg),
      TextField(
        key: const Key('hijo-documento'),
        controller: _document,
        enabled: student == null,
        keyboardType: TextInputType.number,
        maxLength: 16,
        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9 .]'))],
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
        decoration: const InputDecoration(
          counterText: '',
          labelText: 'Número de documento del estudiante',
        ),
        onChanged: (_) => setState(() => _error = null),
      ),
      if (student != null) ...<Widget>[
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          key: const Key('hijo-encontrado'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          borderColor: AppColors.success,
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.ink,
                child: Text(
                  student.initials,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      student.maskedName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${student.grade} · ${student.shift} · ${student.maskedDocument}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('TU PARENTESCO', style: AppTextStyles.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final GuardianRelationship option in GuardianRelationship.values)
              ChoiceChip(
                key: Key('hijo-parentesco-${option.name}'),
                label: Text(option.label),
                selected: option == _relationship,
                showCheckmark: false,
                selectedColor: AppColors.brandSoft,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: option == _relationship ? AppColors.brand : AppColors.border),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: option == _relationship ? AppColors.brand : AppColors.ink,
                ),
                onSelected: (_) => setState(() => _relationship = option),
              ),
          ],
        ),
        TextButton(
          key: const Key('no-es-mi-hijo-cuenta'),
          onPressed: () => setState(() {
            _found = null;
            _document.clear();
          }),
          child: const Text('No es mi hijo · buscar de nuevo'),
        ),
      ],
      if (_error != null) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(
          _error!,
          key: const Key('error-hijo'),
          style: AppTextStyles.caption.copyWith(color: AppColors.brand),
        ),
      ],
    ];
  }
}
