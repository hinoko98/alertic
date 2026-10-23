import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// La vibración fuerte de una alerta: tres golpes seguidos, para sentirla sin
/// oírla.
abstract final class AlertHaptics {
  static const int beats = 3;
  static const Duration gap = Duration(milliseconds: 350);

  static Future<void> play() async {
    for (int i = 0; i < beats; i++) {
      await HapticFeedback.heavyImpact();
      if (i < beats - 1) await Future<void>.delayed(gap);
    }
  }
}

/// Hace vibrar el celular una vez, cuando aparece, si [enabled].
///
/// No envuelve nada visible: solo dispara la vibración al entrar a la pantalla.
class HapticOnShow extends StatefulWidget {
  const HapticOnShow({required this.enabled, required this.child, super.key});

  final bool enabled;
  final Widget child;

  @override
  State<HapticOnShow> createState() => _HapticOnShowState();
}

class _HapticOnShowState extends State<HapticOnShow> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) AlertHaptics.play();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
