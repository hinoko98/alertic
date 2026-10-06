import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../account/presentation/family_contacts_view.dart';
import '../../../session/domain/session.dart';
import '../widgets/onboarding_scaffold.dart';

/// Pantalla 05: a quién se avisa cuando el estudiante está a salvo.
///
/// El colegio ya registró a los acudientes; aquí se pueden sumar más. Es el
/// último detalle antes de entrar.
class FamilySetupScreen extends StatelessWidget {
  const FamilySetupScreen({required this.session, super.key});

  final Session session;

  void _finish(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (Route<void> _) => false,
      arguments: session,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Tu familia',
      subtitle: 'Último detalle',
      showBack: false,
      footer: PrimaryButton(
        label: 'Terminar y entrar',
        icon: null,
        onPressed: () => _finish(context),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '¿A quién avisamos cuando estés a salvo?',
            style: AppTextStyles.screenTitle,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'El colegio ya registró a tu acudiente. Puedes sumar a alguien más.',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: AppSpacing.lg),
          FamilyContactsView(),
        ],
      ),
    );
  }
}
