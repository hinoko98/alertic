import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';

/// Una guía corta para la familia: un título y una lista de puntos.
///
/// El contenido es general —consejos de calma y de preparación que sirven en
/// cualquier colegio—, no un protocolo del colegio: lo que el colegio decide
/// (puntos de encuentro, horas de entrega) lo dice la app durante la alerta.
class FamilyContentScreen extends StatelessWidget {
  const FamilyContentScreen({
    required this.title,
    required this.subtitle,
    required this.intro,
    required this.points,
    super.key,
  });

  final String title;
  final String subtitle;
  final String intro;
  final List<String> points;

  static const FamilyContentScreen familyPlan = FamilyContentScreen(
    title: 'Plan familiar de emergencia',
    subtitle: 'Punto de reunión y quién recoge a cada hijo',
    intro: 'Hablarlo antes, con calma, evita decidir en medio del susto.',
    points: <String>[
      'Acuerden un punto de reunión fuera de casa, por si no pueden volver a ella.',
      'Decidan quién recoge a cada hijo y quién es la segunda opción si esa persona no puede.',
      'Anoten en papel los teléfonos de la familia: el celular puede quedarse sin batería.',
      'Elijan un familiar o amigo fuera de la ciudad al que todos puedan avisar que están bien.',
      'Repasen el plan dos veces al año y cuéntenselo a quien cuide a sus hijos.',
    ],
  );

  static const FamilyContentScreen afterTheScare = FamilyContentScreen(
    title: 'Cómo hablarles después del susto',
    subtitle: 'Calma y apoyo para niños y jóvenes',
    intro: 'Después de una emergencia es normal que estén inquietos, callados o más '
        'pegados a ustedes.',
    points: <String>[
      'Escúchalos primero. Déjalos contar lo que vivieron sin interrumpir ni corregir.',
      'Dile la verdad con palabras sencillas: qué pasó, que ya terminó y que están a salvo.',
      'Acepta lo que sienten: tener miedo no es de débiles. No les digas «no pasó nada».',
      'Mantén las rutinas: comer, dormir y estudiar a la misma hora les devuelve seguridad.',
      'Evita que vean noticias o videos del suceso una y otra vez.',
      'Si pasan varios días con pesadillas, mucho miedo o no quieren volver al colegio, '
          'habla con su director de grupo o con orientación escolar.',
    ],
  );

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: title,
      subtitle: subtitle,
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          Text(intro, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < points.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == points.length - 1 ? 0 : AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(points[i], style: AppTextStyles.body)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
