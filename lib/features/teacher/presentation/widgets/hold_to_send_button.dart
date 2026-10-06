import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Botón que hay que mantener presionado para disparar la acción.
///
/// Emitir una alerta le suena a 1.248 personas y puede sacar a un colegio
/// entero al patio. Un toque se da sin querer con el celular en el bolsillo o
/// al entregárselo a alguien; sostener un segundo y medio, no. Es la única
/// fricción deliberada de toda la app.
class HoldToSendButton extends StatefulWidget {
  const HoldToSendButton({
    required this.label,
    required this.onCompleted,
    required this.enabled,
    this.isSending = false,
    this.holdDuration = const Duration(milliseconds: 1500),
    this.background = AppColors.brand,
    this.foreground = AppColors.onBrand,
    super.key,
  });

  final String label;
  final VoidCallback onCompleted;
  final bool enabled;
  final bool isSending;
  final Duration holdDuration;
  final Color background;
  final Color foreground;

  @override
  State<HoldToSendButton> createState() => _HoldToSendButtonState();
}

class _HoldToSendButtonState extends State<HoldToSendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  )..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        widget.onCompleted();
        _controller.reset();
      }
    });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (widget.enabled) {
      _controller.forward();
    }
  }

  /// Soltar antes de tiempo cancela: la barra vuelve a cero y no pasa nada.
  void _cancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.enabled ? 1 : 0.35,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: Semantics(
          button: true,
          label: '${widget.label}. Mantén presionado para confirmar.',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            child: SizedBox(
            height: 64,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: ColoredBox(color: widget.background)),
                // La barra que avanza mientras se sostiene.
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      return FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _controller.value,
                        child: ColoredBox(
                          color: AppColors.ink.withValues(alpha: 0.35),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            widget.isSending ? 'ENVIANDO…' : widget.label,
                            style: AppTextStyles.button.copyWith(
                              fontSize: 15,
                              color: widget.foreground,
                            ),
                          ),
                        ),
                        if (widget.isSending)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.foreground,
                            ),
                          )
                        else
                          Icon(
                            Icons.touch_app_outlined,
                            size: 20,
                            color: widget.foreground,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
