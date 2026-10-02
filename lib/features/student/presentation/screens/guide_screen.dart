import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../alerts/domain/protocol.dart';
import '../../../alerts/presentation/widgets/hazard_icon.dart';

/// Guía: qué hacer ante cada amenaza, según el plan del colegio.
///
/// Es la pestaña que se lee en frío, antes de que pase nada, y la única que
/// sirve cuando no hay señal. Por eso su contenido se guarda en el celular y no
/// se consulta en línea cada vez.
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('QUÉ HACER', style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.cloud_off,
                        size: 14,
                        color: AppColors.inkFaint,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Guardado en el celular. Funciona sin datos.',
                          style: AppTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Protocol>>(
                future: _protocols,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<Protocol>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return _GuideError(
                      onRetry: () => setState(() => _protocols = _load()),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                      ),
                    );
                  }
                  final List<Protocol> protocols = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    itemCount: protocols.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _ProtocolTile(protocol: protocols[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un protocolo, plegado hasta que hace falta.
class _ProtocolTile extends StatelessWidget {
  const _ProtocolTile({required this.protocol});

  final Protocol protocol;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Divider(height: 1),
        Theme(
          // Las líneas que Material dibuja al expandir pelean con el borde de
          // la lista.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              hazardIcon(protocol.hazard),
              color: AppColors.brand,
              size: 22,
            ),
            title: Text(protocol.hazard.label, style: AppTextStyles.itemTitle),
            iconColor: AppColors.ink,
            collapsedIconColor: AppColors.ink,
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              0,
              AppSpacing.screenGutter,
              AppSpacing.lg,
            ),
            children: <Widget>[
              _Steps(title: 'Antes', steps: protocol.beforeSteps),
              _Steps(title: 'Durante', steps: protocol.duringSteps),
              _Steps(title: 'Después', steps: protocol.afterSteps),
            ],
          ),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title.toUpperCase(), style: AppTextStyles.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          for (final String step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('· ', style: AppTextStyles.body),
                  Expanded(child: Text(step, style: AppTextStyles.body)),
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
            Text(
              'No pudimos abrir la guía. Intenta otra vez.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: AppColors.brand),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }
}
