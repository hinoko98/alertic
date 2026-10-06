import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_scope.dart';
import '../../../core/errors/error_reporter.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/design/app_card.dart';
import '../../../shared/design/app_page.dart';
import '../../../shared/design/icon_bubble.dart';
import '../../../shared/design/section_label.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/secondary_button.dart';
import '../../alerts/domain/alert.dart';
import '../../alerts/domain/safety_report.dart';

/// Pantalla 12: necesito ayuda.
///
/// Dos caminos, el mismo formulario:
///
/// - **Con una alerta activa** es el reporte de estado «necesito ayuda» que ve el
///   tablero de coordinación, con qué pasa y dónde está.
/// - **Sin alerta** sale como un mensaje urgente en el chat con el colegio: lo ve
///   primero y llega con un aviso prioritario a coordinación y al director de
///   grupo.
///
/// Todo son opciones cerradas más una frase corta opcional: en una emergencia
/// nadie escribe.
class HelpScreen extends StatefulWidget {
  const HelpScreen({this.alert, this.classroom, this.initialKind, super.key});

  /// La alerta activa, si la hay.
  final Alert? alert;

  /// Dónde recibe clase quien pide ayuda, para decirlo en el pedido.
  final String? classroom;

  final HelpKind? initialKind;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  late HelpKind _kind = widget.initialKind ?? HelpKind.injured;
  ReportedLocation _location = ReportedLocation.inClassroom;
  final TextEditingController _details = TextEditingController();

  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final AppScope scope = AppScope.of(context);
    final String details = _details.text.trim();

    try {
      final Alert? alert = widget.alert;
      if (alert != null) {
        await scope.alertRepository.submitSafetyReport(
          SafetyReport(
            alertId: alert.id,
            status: SafetyStatus.needsHelp,
            location: _location,
            reportedAt: DateTime.now(),
            helpKind: _kind,
            helpDetails: details.isEmpty ? null : details,
          ),
        );
      } else {
        final support = scope.supportRepository;
        if (support == null) {
          throw StateError('Sin chat con el colegio');
        }
        await support.sendMine(_message(details), urgent: true);
      }
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'pedir ayuda');
      if (mounted) {
        setState(
          () => _error = 'No se pudo enviar. Si es grave, llama a la Línea 123 o '
              'avisa a un adulto cerca.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// El pedido tal como lo lee coordinación en el chat.
  String _message(String details) {
    final StringBuffer text = StringBuffer('Necesito ayuda: ${_kind.label.toLowerCase()}.');
    if (widget.classroom != null) text.write(' Estoy cerca de ${widget.classroom}.');
    if (details.isNotEmpty) text.write(' $details');
    return text.toString();
  }

  Future<void> _call123() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      if (!await launchUrl(Uri(scheme: 'tel', path: '123'))) {
        messenger.showSnackBar(const SnackBar(content: Text('No pudimos abrir el teléfono. Marca el 123.')));
      }
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'llamar al 123');
      messenger.showSnackBar(const SnackBar(content: Text('No pudimos abrir el teléfono. Marca el 123.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return _Sent(onDone: () => Navigator.of(context).maybePop(true), onCall: _call123);
    }

    final bool inAlert = widget.alert != null;

    return AppPage(
      title: 'Necesito ayuda',
      subtitle: inAlert ? 'Llega a coordinación y a tu docente' : 'Llega al colegio al instante',
      onBack: () => Navigator.of(context).maybePop(),
      showHelp: false,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        children: <Widget>[
          const SectionLabel('¿Qué pasa?', padding: EdgeInsets.only(bottom: AppSpacing.sm)),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final HelpKind kind in HelpKind.values)
                _KindChip(
                  kind: kind,
                  selected: _kind == kind,
                  onTap: () => setState(() => _kind = kind),
                ),
            ],
          ),
          if (inAlert) ...<Widget>[
            const SectionLabel('¿Dónde estás?'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final ReportedLocation place in ReportedLocation.values)
                  ChoiceChip(
                    label: Text(place.label),
                    selected: _location == place,
                    onSelected: (_) => setState(() => _location = place),
                    showCheckmark: false,
                    selectedColor: AppColors.brandSoft,
                    side: BorderSide(
                      color: _location == place ? AppColors.brand : AppColors.border,
                    ),
                  ),
              ],
            ),
          ],
          if (widget.classroom != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  const IconBubble(icon: Icons.location_on_outlined, size: 38),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(widget.classroom!, style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
                        const Text(
                          'Tu salón. Se comparte con coordinación.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SectionLabel('Detalles (opcional)'),
          TextField(
            key: const Key('detalles-ayuda'),
            controller: _details,
            maxLength: 160,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Ej. me torcí el tobillo en la escalera'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                key: const Key('error-ayuda'),
                style: AppTextStyles.caption.copyWith(color: AppColors.brand),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Si es grave o hay fuego, llama también a la Línea 123.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            key: const Key('enviar-ayuda'),
            label: 'Enviar pedido de ayuda',
            icon: Icons.send_outlined,
            isLoading: _sending,
            onPressed: _send,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Llamar a la Línea 123', onPressed: _call123),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.selected, required this.onTap});

  final HelpKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double width =
        (MediaQuery.sizeOf(context).width - AppSpacing.screenGutter * 2 - AppSpacing.sm) / 2;

    return SizedBox(
      width: width,
      child: AppCard(
        onTap: onTap,
        color: selected ? AppColors.brandSoft : AppColors.surface,
        borderColor: selected ? AppColors.brand : AppColors.border,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(_icon(kind), size: 18, color: selected ? AppColors.brand : AppColors.ink),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                kind.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.brand : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(HelpKind kind) => switch (kind) {
        HelpKind.injured => Icons.add,
        HelpKind.trapped => Icons.lock_outline,
        HelpKind.someoneElse => Icons.person_add_alt_outlined,
        HelpKind.other => Icons.more_horiz,
      };
}

/// Confirmación: el pedido llegó.
class _Sent extends StatelessWidget {
  const _Sent({required this.onDone, required this.onCall});

  final VoidCallback onDone;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenGutter),
          child: Column(
            children: <Widget>[
              const Spacer(),
              const IconBubble.success(icon: Icons.check, size: 72),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Pedido enviado',
                key: Key('ayuda-enviada'),
                style: AppTextStyles.screenTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Coordinación y tu director de grupo ya lo ven. Si es seguro, '
                'quédate donde estás. Si es grave, llama también a la Línea 123.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              const Spacer(),
              SecondaryButton(label: 'Llamar a la Línea 123', onPressed: onCall),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(label: 'Volver', icon: null, onPressed: onDone),
            ],
          ),
        ),
      ),
    );
  }
}
