import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/pill.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../domain/enrollment.dart';
import '../../domain/enrollment_failure.dart';
import '../../domain/guardian_link.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 13: la vinculación.
///
/// Las solicitudes ya están en el colegio. Mientras nadie las apruebe, la
/// pantalla lo dice y vuelve a preguntar sola cada [pollEvery]; cuando el colegio
/// aprueba, el servidor entrega la sesión **a este celular** (el único que
/// conoce el secreto de la solicitud) y el acudiente entra.
class GuardianLinkedScreen extends StatefulWidget {
  const GuardianLinkedScreen({
    required this.draft,
    required this.requests,
    this.pollEvery = const Duration(seconds: 15),
    super.key,
  });

  final GuardianDraft draft;
  final List<LinkRequest> requests;
  final Duration pollEvery;

  @override
  State<GuardianLinkedScreen> createState() => _GuardianLinkedScreenState();
}

enum _Phase { waiting, linked, rejected }

class _GuardianLinkedScreenState extends State<GuardianLinkedScreen> {
  _Phase _phase = _Phase.waiting;
  bool _checking = false;
  String? _error;
  GuardianEnrollment? _profile;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Se pregunta apenas se dibuja la pantalla: con auto-aprobación el colegio
    // ya respondió y no hay por qué esperar a la primera vuelta del reloj.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
    _timer = Timer.periodic(widget.pollEvery, (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (_checking || _phase != _Phase.waiting) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final AppScope scope = AppScope.of(context);
      final ClaimOutcome outcome = await scope.enrollmentRepository.claimGuardianLink(
        requestId: widget.requests.first.id,
        claimSecret: widget.draft.claimSecret,
      );
      switch (outcome) {
        case ClaimPending():
          break;
        case ClaimRejected():
          _timer?.cancel();
          if (mounted) setState(() => _phase = _Phase.rejected);
        case ClaimApproved(:final session):
          _timer?.cancel();
          await scope.sessionStore.save(session);
          final Enrollment profile = session.profile;
          if (mounted) {
            setState(() {
              _phase = _Phase.linked;
              _profile = profile is GuardianEnrollment ? profile : null;
            });
          }
      }
    } on EnrollmentFailure catch (failure, stack) {
      ErrorReporter.report(failure, stack, context: 'reclamar vinculación');
      if (mounted) setState(() => _error = failure.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'reclamar vinculación');
      if (mounted) setState(() => _error = 'No pudimos consultar al colegio. Intenta otra vez.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _enter() => Navigator.of(context).pushNamed(AppRoutes.permissions);

  void _retry() => Navigator.of(context).popUntil(
        (Route<void> route) => route.settings.name == AppRoutes.whoAreYou,
      );

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Registro del acudiente',
      subtitle: 'Paso 4 de 4',
      step: 3,
      stepCount: 4,
      showBack: _phase != _Phase.linked,
      footer: switch (_phase) {
        _Phase.linked => PrimaryButton(label: 'Entrar', icon: null, onPressed: _enter),
        _Phase.waiting => SecondaryButton(
            label: _checking ? 'Consultando…' : 'Revisar estado',
            icon: Icons.refresh,
            onPressed: _checking ? null : _check,
          ),
        _Phase.rejected => PrimaryButton(
            label: 'Volver a empezar',
            icon: null,
            onPressed: _retry,
          ),
      },
      child: switch (_phase) {
        _Phase.linked => _Linked(profile: _profile, requests: widget.requests),
        _Phase.waiting => _Waiting(requests: widget.requests, error: _error),
        _Phase.rejected => const _Rejected(),
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.icon,
    required this.color,
    required this.soft,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final Color soft;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
          child: Icon(icon, size: 44, color: color),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(body, textAlign: TextAlign.center, style: AppTextStyles.caption),
        ),
      ],
    );
  }
}

String _names(Iterable<String> names) {
  final List<String> list = names.toList();
  if (list.length <= 1) return list.join();
  return '${list.sublist(0, list.length - 1).join(', ')} y ${list.last}';
}

class _Linked extends StatelessWidget {
  const _Linked({required this.profile, required this.requests});

  final GuardianEnrollment? profile;
  final List<LinkRequest> requests;

  @override
  Widget build(BuildContext context) {
    final List<LinkedStudent> children = profile?.children ?? const <LinkedStudent>[];
    final Iterable<String> firstNames = children.isNotEmpty
        ? children.map((LinkedStudent c) => c.fullName.split(' ').first)
        : requests.map((LinkRequest r) => r.student.firstName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Hero(
          icon: Icons.link,
          color: AppColors.success,
          soft: AppColors.successSoft,
          title: 'Quedaste vinculado con ${_names(firstNames)}',
          body: 'Tu documento coincide con el acudiente registrado en la matrícula '
              'del colegio.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          key: const Key('hijos-vinculados'),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.surfaceAlt,
                        child: Text(
                          children[i].initials,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              children[i].fullName,
                              style: AppTextStyles.itemTitle.copyWith(fontSize: 14),
                            ),
                            Text(
                              '${children[i].grade} · ${children[i].shift}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      const Pill('Vinculado', tone: PillTone.success),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('QUÉ VAS A RECIBIR', style: AppTextStyles.eyebrow),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            children: <Widget>[
              _Benefit(
                icon: Icons.notifications_none,
                text: 'Aviso cuando haya una alerta en el colegio',
              ),
              SizedBox(height: AppSpacing.md),
              _Benefit(
                icon: Icons.check,
                text: 'Confirmación cuando tu hijo o hija esté a salvo',
                good: true,
              ),
              SizedBox(height: AppSpacing.md),
              _Benefit(
                icon: Icons.schedule,
                text: 'Instrucciones del colegio para recogerlo',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text, this.good = false});

  final IconData icon;
  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: good ? AppColors.successSoft : AppColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: good ? AppColors.success : AppColors.brand),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.requests, required this.error});

  final List<LinkRequest> requests;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Hero(
          icon: Icons.hourglass_top,
          color: AppColors.warning,
          soft: AppColors.warningSoft,
          title: 'Esperando al colegio',
          body: 'Enviamos tu solicitud para vincularte con '
              '${_names(requests.map((LinkRequest r) => r.student.firstName))}. '
              'Cuando el colegio la apruebe, entras desde aquí.',
        ),
        const SizedBox(height: AppSpacing.lg),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, size: 16, color: AppColors.inkMuted),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Si tu documento no aparece en la matrícula, la solicitud queda '
                'pendiente hasta que el colegio la apruebe en su panel. Deja '
                'esta pantalla abierta: volvemos a preguntar sola.',
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            error!,
            key: const Key('error-vinculacion'),
            style: AppTextStyles.caption.copyWith(color: AppColors.brand),
          ),
        ],
      ],
    );
  }
}

class _Rejected extends StatelessWidget {
  const _Rejected();

  @override
  Widget build(BuildContext context) {
    return const _Hero(
      icon: Icons.close,
      color: AppColors.brand,
      soft: AppColors.brandSoft,
      title: 'El colegio no pudo confirmar tus datos',
      body: 'Revisa el documento y el parentesco con secretaría, o pide un '
          'código de acceso. Puedes volver a empezar.',
    );
  }
}
