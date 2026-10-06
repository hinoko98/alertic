import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/shell_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/session/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/design/app_card.dart';
import '../../../../shared/design/app_page.dart';
import '../../../../shared/design/icon_bubble.dart';
import '../../../../shared/design/section_label.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../alerts/domain/protocol.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';

/// Pantalla 13: guías, «qué hacer si…».
///
/// Es la pestaña que se lee en frío, antes de que pase nada, y la única que
/// sirve cuando no hay señal. Por eso su contenido se guarda en el celular y no
/// se consulta en línea cada vez. **Todo lo que dice cada amenaza lo escribió el
/// colegio** en sus protocolos.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  Future<List<Protocol>>? _protocols;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No se puede en initState: leer el AppScope necesita que las dependencias
    // del widget ya estén resueltas.
    _protocols ??= _load();
  }

  Future<List<Protocol>> _load() async {
    try {
      return await AppScope.of(context).alertRepository.loadProtocols();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'cargar protocolos');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Qué hacer si…',
      subtitle: 'Guías antes, durante y después',
      body: FutureBuilder<List<Protocol>>(
        future: _protocols,
        builder: (BuildContext context, AsyncSnapshot<List<Protocol>> snapshot) {
          if (snapshot.hasError) {
            return _GuideError(onRetry: () => setState(() => _protocols = _load()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brand));
          }

          final List<Protocol> protocols = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenGutter),
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.cloud_off, size: 14, color: AppColors.inkFaint),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Guardado en el celular. Funciona sin datos.',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
              const SectionLabel('Eventos naturales'),
              for (final Protocol protocol in protocols)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ProtocolCard(
                    protocol: protocol,
                    // Solo un estudiante tiene ruta propia que ver.
                    onViewRoute: ShellScope.maybeOf(context)?.role == UserRole.estudiante
                        ? () => ShellScope.maybeOf(context)!.openTab('Mapa')
                        : null,
                  ),
                ),
              const SectionLabel('Prepárate'),
              AppCard(
                key: const Key('kit-de-emergencia'),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(builder: (_) => const _KitScreen()),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: const Row(
                  children: <Widget>[
                    IconBubble.neutral(icon: Icons.medical_services_outlined, size: 38),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Kit de emergencia', style: AppTextStyles.itemTitle),
                          Text('Qué tener listo en casa y en la maleta', style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.inkMuted),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({required this.protocol, required this.onViewRoute});

  final Protocol protocol;
  final VoidCallback? onViewRoute;

  @override
  Widget build(BuildContext context) {
    // La frase de la tarjeta es lo primero que el colegio dice que se haga.
    final String keyPhrase = protocol.duringSteps.isEmpty
        ? 'Toca para ver la guía'
        : protocol.duringSteps.first;

    return AppCard(
      key: Key('guia-${protocol.hazard.wire}'),
      onTap: () => pushInShell<void>(
        context,
        (_) => HazardGuideScreen(protocol: protocol, onViewRoute: onViewRoute),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          IconBubble(icon: hazardIcon(protocol.hazard), size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _title(protocol),
                  style: AppTextStyles.itemTitle.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(keyPhrase, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
        ],
      ),
    );
  }

  static String _title(Protocol protocol) {
    final String label = protocol.hazard.label;
    return '${label[0]}${label.substring(1).toLowerCase()}';
  }
}

/// Pantalla 14: la guía de una amenaza, con sus pestañas Antes, Durante y Después.
class HazardGuideScreen extends StatefulWidget {
  const HazardGuideScreen({required this.protocol, this.onViewRoute, super.key});

  final Protocol protocol;

  /// Lleva al mapa de quien lee. Sin él no se muestra el botón.
  final VoidCallback? onViewRoute;

  @override
  State<HazardGuideScreen> createState() => _HazardGuideScreenState();
}

class _HazardGuideScreenState extends State<HazardGuideScreen> {
  int _tab = 1; // «Durante» es lo que más se busca.

  @override
  Widget build(BuildContext context) {
    final Protocol protocol = widget.protocol;
    final List<String> steps = switch (_tab) {
      0 => protocol.beforeSteps,
      1 => protocol.duringSteps,
      _ => protocol.afterSteps,
    };
    final String label = protocol.hazard.label;

    return AppPage(
      title: '${label[0]}${label.substring(1).toLowerCase()}',
      subtitle: 'Guía de actuación',
      onBack: () => Navigator.of(context).maybePop(),
      bottom: widget.onViewRoute != null
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.sm,
                AppSpacing.screenGutter,
                AppSpacing.md,
              ),
              child: PrimaryButton(
                label: 'Ver mi ruta de evacuación',
                icon: null,
                onPressed: () {
                  Navigator.of(context).maybePop();
                  widget.onViewRoute!();
                },
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Row(
              children: <Widget>[
                for (final (int i, String name) in <(int, String)>[(0, 'Antes'), (1, 'Durante'), (2, 'Después')])
                  Expanded(
                    child: GestureDetector(
                      key: Key('pestana-$name'),
                      onTap: () => setState(() => _tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tab == i ? AppColors.surface : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall - 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _tab == i ? AppColors.brand : AppColors.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (steps.isEmpty)
            const AppCard(
              child: Text(
                'El colegio todavía no publicó esta parte de la guía.',
                style: AppTextStyles.caption,
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.ink,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.onBrand,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text(steps[i], style: AppTextStyles.body)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.brand),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Evacúa por tu ruta solo cuando tu docente o la alarma lo '
                    'indiquen.',
                    style: TextStyle(fontSize: 12, color: AppColors.brand),
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

/// El kit de emergencia: una lista de lo básico que conviene tener listo.
///
/// Es la lista general de las entidades de gestión del riesgo, no un protocolo del
/// colegio: por eso está aquí y no entre los protocolos que edita coordinación.
class _KitScreen extends StatelessWidget {
  const _KitScreen();

  static const List<String> _items = <String>[
    'Agua potable para varios días',
    'Linterna con pilas de repuesto',
    'Radio de pilas',
    'Botiquín',
    'Copias de documentos en una bolsa plástica',
    'Medicamentos de uso diario',
    'Alimentos que no se dañen',
    'Silbato',
    'Cargador portátil para el celular',
    'Teléfonos de familia anotados en papel',
  ];

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Kit de emergencia',
      subtitle: 'Qué tener listo',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: <Widget>[
                for (final String item in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(item, style: AppTextStyles.body)),
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

class _GuideError extends StatelessWidget {
  const _GuideError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No pudimos abrir la guía. Intenta otra vez.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
