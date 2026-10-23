import 'package:flutter/material.dart';

/// El icono de la amenaza dentro de su círculo, con un aro que late hacia afuera.
///
/// El latido llama la atención sin ser una sirena, pero **no es infinito**: se
/// repite unas cuantas veces y se queda quieto. Una animación que nunca termina
/// gasta batería durante toda la evacuación y no añade nada después de los
/// primeros segundos, cuando la persona ya miró la pantalla.
class PulsingIcon extends StatefulWidget {
  const PulsingIcon({
    required this.icon,
    required this.color,
    this.pulse = true,
    this.beats = 5,
    super.key,
  });

  final IconData icon;
  final Color color;

  /// Con `false` el aro no se dibuja (fondos claros, donde no se ve).
  final bool pulse;

  /// Cuántas veces late antes de quedarse quieto.
  final int beats;

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon> with SingleTickerProviderStateMixin {
  static const Duration _beat = Duration(milliseconds: 1600);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _beat * widget.beats);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Quien pidió menos movimiento en el sistema no ve latir nada.
    if (widget.pulse && !MediaQuery.disableAnimationsOf(context) && !_controller.isAnimating) {
      if (_controller.value == 0) _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (widget.pulse)
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) {
                if (_controller.isDismissed || _controller.isCompleted) {
                  return const SizedBox.shrink();
                }
                final double t = (_controller.value * widget.beats) % 1;
                return Opacity(
                  opacity: 0.7 * (1 - t),
                  child: Transform.scale(
                    scale: 0.8 + 0.9 * t,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.color, width: 3),
                      ),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: widget.pulse ? 0.18 : 0.1),
            ),
            child: Icon(widget.icon, size: 44, color: widget.color),
          ),
        ],
      ),
    );
  }
}
