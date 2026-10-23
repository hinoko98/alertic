import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';

/// Pantalla 28: el kit de emergencia que cada persona arma en casa.
///
/// La lista es general, de las entidades de gestión del riesgo, no un protocolo
/// del colegio. Lo que la persona va marcando se guarda **solo en su celular**:
/// es una lista de tareas de su casa, no algo que el colegio necesite saber.
class KitScreen extends StatefulWidget {
  const KitScreen({super.key});

  /// Qué se guarda en el celular: los textos marcados. Se guarda el texto y no
  /// la posición, para que cambiar el orden de la lista no marque lo que no es.
  static const String storageKey = 'kit-de-emergencia';

  static const List<String> items = <String>[
    'Agua: 3 litros por persona',
    'Linterna y pilas de repuesto',
    'Botiquín básico',
    'Silbato para pedir ayuda',
    'Copia de documentos en bolsa plástica',
    'Comida que no se dañe (3 días)',
    'Batería externa cargada',
    'Medicamentos que tomes a diario',
  ];

  @override
  State<KitScreen> createState() => _KitScreenState();
}

class _KitScreenState extends State<KitScreen> {
  Set<String> _checked = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> saved = prefs.getStringList(KitScreen.storageKey) ?? <String>[];
      if (mounted) {
        setState(() => _checked = saved.where(KitScreen.items.contains).toSet());
      }
    } catch (error, stack) {
      // Sin almacenamiento la lista se puede usar igual, solo que no se recuerda.
      ErrorReporter.report(error, stack, context: 'kit de emergencia');
    }
  }

  Future<void> _toggle(String item, bool value) async {
    setState(() => value ? _checked.add(item) : _checked.remove(item));
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(KitScreen.storageKey, _checked.toList());
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'guardar el kit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final int total = KitScreen.items.length;
    final int done = _checked.length;

    return AppPage(
      title: 'Kit de emergencia',
      subtitle: 'Arma el tuyo en casa',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(child: Text('Tu kit', style: AppTextStyles.itemTitle)),
                    Text(
                      '$done de $total',
                      key: const Key('avance-kit'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  label: '$done de $total elementos',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : done / total,
                      minHeight: 8,
                      color: AppColors.success,
                      backgroundColor: AppColors.border,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Tenlo listo en casa por si hay que salir rápido.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < KitScreen.items.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1),
                  CheckboxListTile(
                    key: Key('kit-$i'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.success,
                    title: Text(
                      KitScreen.items[i],
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    value: _checked.contains(KitScreen.items[i]),
                    onChanged: (bool? value) => _toggle(KitScreen.items[i], value ?? false),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.schedule, size: 16, color: AppColors.inkMuted),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Revísalo cada 6 meses: cambia el agua y las pilas.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
