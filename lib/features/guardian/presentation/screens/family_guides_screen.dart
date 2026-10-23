import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/design/section_label.dart';
import '../../../student/presentation/screens/guide_screen.dart';
import '../../../student/presentation/screens/kit_screen.dart';
import 'family_content_screen.dart';

/// Pantalla 42: guías para la familia.
///
/// Qué hace un acudiente cuando hay una emergencia en el colegio, y cómo
/// prepararse en casa. Arriba, lo más importante: si recibe una alerta.
class FamilyGuidesScreen extends StatelessWidget {
  const FamilyGuidesScreen({super.key});

  static const List<String> _whenAlert = <String>[
    'Mira en Inicio si tu hijo ya está a salvo.',
    'No vayas ni llames: deja las vías y las líneas libres.',
    'Espera el aviso del colegio con el punto y la hora de entrega.',
  ];

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Guías para la familia',
      subtitle: 'Cómo actuar si hay una emergencia en el colegio',
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          Container(
            key: const Key('si-recibes-una-alerta'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.brand, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    IconBubble(icon: Icons.warning_amber_outlined, size: 38),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Si recibes una alerta', style: AppTextStyles.itemTitle),
                          Text('Lo más importante', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                for (int i = 0; i < _whenAlert.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == _whenAlert.length - 1 ? 0 : AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            _whenAlert[i],
                            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SectionLabel('Prepárate en casa'),
          _GuideLink(
            key: const Key('guia-kit-familiar'),
            icon: Icons.medical_services_outlined,
            title: 'Kit de emergencia familiar',
            subtitle: 'Lista para revisar en casa',
            onTap: () => _open(context, const KitScreen()),
          ),
          const SizedBox(height: AppSpacing.sm),
          _GuideLink(
            key: const Key('guia-plan-familiar'),
            icon: Icons.home_outlined,
            title: 'Plan familiar de emergencia',
            subtitle: 'Punto de reunión y quién recoge a cada hijo',
            onTap: () => _open(context, FamilyContentScreen.familyPlan),
          ),
          const SizedBox(height: AppSpacing.sm),
          _GuideLink(
            key: const Key('guia-que-aprende'),
            icon: Icons.menu_book_outlined,
            title: 'Qué aprende tu hijo en el colegio',
            subtitle: 'Sismo, inundación, lluvias e incendio',
            onTap: () => _open(context, const GuideScreen()),
          ),
          const SizedBox(height: AppSpacing.sm),
          _GuideLink(
            key: const Key('guia-hablar-despues'),
            icon: Icons.favorite_border,
            title: 'Cómo hablarles después del susto',
            subtitle: 'Calma y apoyo para niños y jóvenes',
            onTap: () => _open(context, FamilyContentScreen.afterTheScare),
          ),
        ],
      ),
    );
  }
}

class _GuideLink extends StatelessWidget {
  const _GuideLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          IconBubble.neutral(icon: icon, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.itemTitle),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        ],
      ),
    );
  }
}
