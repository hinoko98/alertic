import 'package:flutter/material.dart';

import '../../../../app/app_scope.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/format.dart';
import '../../domain/alert.dart';
import '../../domain/evacuation_rating.dart';
import '../../domain/hazard.dart';

/// Pantalla 19: la alerta terminó y es seguro regresar.
///
/// Es lo último que ve la persona de una emergencia, y lo que tiene que decir es
/// claro: ya pasó, vuelve al salón con tu docente. Si confirmó que estaba a
/// salvo, también ve a qué hora y cuánto tardó, y se le pregunta cómo le fue.
class AlertEndedScreen extends StatefulWidget {
  const AlertEndedScreen({
    required this.alert,
    required this.endedAt,
    required this.onClose,
    this.answeredAt,
    super.key,
  });

  final Alert alert;

  /// Cuándo se supo que terminó.
  final DateTime endedAt;

  /// Cuándo confirmó la persona que estaba a salvo. Nulo si no respondió desde
  /// este celular.
  final DateTime? answeredAt;

  final VoidCallback onClose;

  @override
  State<AlertEndedScreen> createState() => _AlertEndedScreenState();
}

class _AlertEndedScreenState extends State<AlertEndedScreen> {
  static const Color _green = Color(0xFF1F6B45);
  static const Color _greenDark = Color(0xFF1F5C3D);

  EvacuationRating? _rating;
  bool _sending = false;
  bool _failed = false;

  Future<void> _rate(EvacuationRating rating) async {
    if (_sending) return;
    setState(() {
      _rating = rating;
      _sending = true;
      _failed = false;
    });
    try {
      await AppScope.of(
        context,
      ).alertRepository.sendEvacuationFeedback(widget.alert.id, rating);
    } catch (error, stack) {
      ErrorReporter.report(error, stack, context: 'opinión de la evacuación');
      // Solo se dice «gracias» cuando el colegio la recibió.
      if (mounted) {
        setState(() {
          _rating = null;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _what(Alert alert) {
    final String noun = switch (alert.hazard) {
      Hazard.sismo => 'sismo',
      Hazard.inundacion => 'inundación',
      Hazard.incendio => 'incendio',
      Hazard.lluvia => 'lluvias',
    };
    return alert.isDrill
        ? 'Terminó el simulacro de $noun.'
        : 'Terminó la alerta de $noun.';
  }

  static String _duration(Duration elapsed) {
    final int seconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
    return seconds < 60
        ? '$seconds s'
        : '${seconds ~/ 60} min ${seconds % 60} s';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? answered = widget.answeredAt;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _green,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '✓ ALERTA FINALIZADA',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: _greenDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            Fmt.hour(widget.endedAt),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 48,
                            color: _green,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Es seguro regresar',
                        key: Key('es-seguro-regresar'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${_what(widget.alert)} Regresa al salón con tu docente.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      if (answered != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: _Figure(
                                  label: 'Confirmaste a salvo',
                                  value: Fmt.hour(answered),
                                ),
                              ),
                              Expanded(
                                child: _Figure(
                                  label: 'Tu tiempo',
                                  value: _duration(
                                    answered.difference(widget.alert.issuedAt),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      _Feedback(
                        rating: _rating,
                        sending: _sending,
                        failed: _failed,
                        onRate: _rate,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  0,
                  AppSpacing.screenGutter,
                  AppSpacing.lg,
                ),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: InkWell(
                      key: const Key('volver-al-inicio'),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      onTap: widget.onClose,
                      child: const Center(
                        child: Text(
                          'Volver al inicio',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _greenDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.rating,
    required this.sending,
    required this.failed,
    required this.onRate,
  });

  final EvacuationRating? rating;
  final bool sending;
  final bool failed;
  final ValueChanged<EvacuationRating> onRate;

  @override
  Widget build(BuildContext context) {
    final bool answered = rating != null && !sending;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '¿Cómo te fue en la evacuación?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (final EvacuationRating option
                  in EvacuationRating.values) ...<Widget>[
                if (option != EvacuationRating.values.first)
                  const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      key: Key('opinion-${option.wire}'),
                      onPressed: sending || answered
                          ? null
                          : () => onRate(option),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: option == rating
                            ? AppColors.ink
                            : Colors.white70,
                        backgroundColor: option == rating
                            ? Colors.white
                            : Colors.transparent,
                        side: const BorderSide(color: Colors.white70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                      ),
                      child: Text(option.label),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            failed
                ? 'No pudimos enviar tu respuesta. Toca otra vez.'
                : answered
                ? 'Gracias. Tu respuesta ayuda a mejorar las rutas del colegio.'
                : 'Tu respuesta ayuda a mejorar las rutas del colegio.',
            key: const Key('texto-opinion'),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
